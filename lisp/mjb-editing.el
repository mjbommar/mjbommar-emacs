;;; mjb-editing.el --- Region expansion, jumping, undo -*- lexical-binding: t -*-

;;; Commentary:
;; Two packages reimplemented here, both because their bindings were unreachable
;; in a terminal anyway (F-06) and both because they are small enough that the
;; package is not carrying its weight:
;;
;;   expand-region  1894 lines  ->  `mjb-expand-region'  (~35 lines)
;;   avy            1928 lines  ->  `mjb-jump'           (~55 lines)
;;
;; These are not full reimplementations.  `mjb-expand-region' covers the
;; progressive word/sexp/line/paragraph/defun ladder, which is what the command
;; is used for; expand-region additionally ships mode-specific expanders for a
;; dozen languages.  `mjb-jump' does timed-input jumping with hint characters --
;; avy also does line/word/region/copy/kill variants.  If you find yourself
;; wanting those, the packages are one line each to add back.
;;
;; Requirement refs: R-023 (built-in undo), R-033 (terminal-typeable keys).

;;; Code:

(require 'mjb-core)
(require 'thingatpt)

(defgroup mjb-editing nil "Editing commands." :group 'editing)

;;;; Progressive region expansion ----------------------------------------------

(defcustom mjb-expand-things '(word symbol sexp list sentence line paragraph defun)
  "Syntactic units tried by `mjb-expand-region', smallest first.
Each is passed to `bounds-of-thing-at-point'."
  :type '(repeat symbol) :group 'mjb-editing)

(defvar-local mjb--expand-history nil
  "Stack of (START . END) pairs, so expansion can be undone.")

(defvar-local mjb--expand-origin nil
  "Buffer position where the current expansion chain started.
Thing bounds are always measured from here.  Measuring at point instead is
the obvious bug: point sits at the region END after each expansion, so the
second call asks `bounds-of-thing-at-point' about the wrong place and the
region stops growing.")

(defun mjb--expand-bounds (thing pos)
  "Bounds of THING at POS, or nil.  Never signals."
  (ignore-errors
    (save-excursion (goto-char pos) (bounds-of-thing-at-point thing))))

(defun mjb--expand-enclosing-list (pos)
  "Bounds of the innermost list or string enclosing POS, or nil."
  (ignore-errors
    (let* ((ppss (syntax-ppss pos))
           (str-beg (nth 8 ppss))         ; inside a string or comment
           (list-beg (nth 1 ppss)))       ; inside a list
      (cond
       (str-beg (cons str-beg (scan-sexps str-beg 1)))
       (list-beg (cons list-beg (scan-sexps list-beg 1)))))))

(defvar-local mjb--expand-current nil
  "Bounds selected by the last `mjb-expand-region' in this chain.
Tracked explicitly rather than read back from the region, because whether
the mark is still active depends on `transient-mark-mode' and on what ran
in between -- which made the expansion silently stop growing.")

(defun mjb-expand-region ()
  "Enlarge the region to the next larger syntactic unit.
Repeat to keep growing; `mjb-contract-region' steps back."
  (interactive)
  (let* ((chain (and (eq last-command 'mjb-expand-region) mjb--expand-current))
         (start (cond (chain (car mjb--expand-current))
                      ((use-region-p) (region-beginning))
                      (t (point))))
         (end   (cond (chain (cdr mjb--expand-current))
                      ((use-region-p) (region-end))
                      (t (point))))
         candidates best)
    (unless chain
      (setq mjb--expand-history nil
            mjb--expand-origin (if (use-region-p) (region-beginning) (point))))
    (let ((origin (or mjb--expand-origin (point))))
      ;; Syntactic things, measured from the origin so repeated calls agree.
      (dolist (thing mjb-expand-things)
        (when-let ((b (mjb--expand-bounds thing origin)))
          (push b candidates)))
      ;; Enclosing list/string, measured from the current region edge so each
      ;; call climbs one level of nesting.
      (when-let ((b (mjb--expand-enclosing-list start)))
        (push b candidates))
      ;; Last resort: the whole buffer.
      (push (cons (point-min) (point-max)) candidates))
    ;; Smallest candidate that strictly contains the current region.
    (dolist (b candidates)
      (when (and (<= (car b) start) (>= (cdr b) end)
                 (or (< (car b) start) (> (cdr b) end))
                 (or (null best) (< (- (cdr b) (car b)) (- (cdr best) (car best)))))
        (setq best b)))
    (if (null best)
        (progn
          ;; Nothing larger: keep the selection we have rather than dropping it,
          ;; and stay in the chain so `mjb-contract-region' still works.
          (when (and start end (/= start end))
            (push-mark start t t)
            (goto-char end)
            (setq deactivate-mark nil))
          (setq this-command 'mjb-expand-region)
          (message "mjb: region cannot expand further"))
      (push (cons start end) mjb--expand-history)
      (setq mjb--expand-current best)
      (push-mark (car best) t t)
      (goto-char (cdr best))
      (setq deactivate-mark nil))))

(defun mjb-contract-region ()
  "Undo one step of `mjb-expand-region'."
  (interactive)
  (if-let ((prev (pop mjb--expand-history)))
      (progn (setq mjb--expand-current prev)
             (push-mark (car prev) t t)
             (goto-char (cdr prev))
             (setq deactivate-mark nil)
             ;; Keep the chain alive so a following expand still sees history.
             (setq this-command 'mjb-expand-region))
    (deactivate-mark)
    (message "mjb: no expansion to undo")))

;;;; Jump to visible text -------------------------------------------------------

(defcustom mjb-jump-keys "asdfghjklqwertyuiopzxcvbnm"
  "Characters used as jump hints, in order of preference.
Home row first: these are what your fingers reach without looking."
  :type 'string :group 'mjb-editing)

(defcustom mjb-jump-timeout 0.4
  "Seconds of idle input after which `mjb-jump' stops reading and shows hints."
  :type 'number :group 'mjb-editing)

(defface mjb-jump-hint
  '((t :inherit isearch :weight bold))
  "Face for jump hint characters." :group 'mjb-editing)

(defun mjb--jump-read-query ()
  "Read search characters until the user pauses.  Return the string."
  (let ((query "") ch)
    ;; First character blocks; later ones time out, so a pause ends input.
    (setq ch (read-char "jump to: " t))
    (while ch
      (if (memq ch '(?\C-? ?\C-h))      ; DEL / backspace
          (setq query (if (string-empty-p query) query (substring query 0 -1)))
        (setq query (concat query (char-to-string ch))))
      (setq ch (read-char (format "jump to: %s" query) t mjb-jump-timeout)))
    query))

(defun mjb--jump-matches (query)
  "Positions of QUERY visible in the selected window."
  (let ((case-fold-search t) matches)
    (save-excursion
      (goto-char (window-start))
      (while (and (re-search-forward (regexp-quote query) (window-end nil t) t)
                  (< (length matches) (length mjb-jump-keys)))
        (push (match-beginning 0) matches)
        ;; Overlapping matches are not useful targets.
        (goto-char (max (1+ (match-beginning 0)) (match-end 0)))))
    (nreverse matches)))

(defun mjb-jump ()
  "Jump to a visible occurrence of typed text.
Type characters; pause to stop.  One match jumps immediately; several are
labelled with a hint character to press.  Replaces avy's `goto-char-timer',
using only keys a terminal can transmit (F-06)."
  (interactive)
  (let* ((query (mjb--jump-read-query))
         (matches (and (not (string-empty-p query)) (mjb--jump-matches query))))
    (cond
     ((null matches) (message "mjb: no visible match for %S" query))
     ((null (cdr matches)) (push-mark) (goto-char (car matches)))
     (t
      (let (overlays)
        (unwind-protect
            (progn
              (seq-do-indexed
               (lambda (pos i)
                 (let ((ov (make-overlay pos (min (1+ pos) (point-max))))
                       (hint (char-to-string (aref mjb-jump-keys i))))
                   (overlay-put ov 'display (propertize hint 'face 'mjb-jump-hint))
                   (overlay-put ov 'priority 1000)
                   (push ov overlays)))
               matches)
              (let* ((ch (read-char (format "jump to [%d]: " (length matches)) t))
                     (idx (seq-position (append mjb-jump-keys nil) ch)))
                (if (and idx (< idx (length matches)))
                    (progn (push-mark) (goto-char (nth idx matches)))
                  (message "mjb: no such hint"))))
          (mapc #'delete-overlay overlays)))))))

;;;; Undo (R-023) ---------------------------------------------------------------
;; `undo-tree' (2815 lines) is removed: it persists history to disk and stalls
;; on large buffers, which a 3000-line main.tex is.  `undo-redo' is built in.

(defun mjb-undo-redo ()
  "Redo the last undone change."
  (interactive)
  (if (fboundp 'undo-redo) (undo-redo) (undo-only)))

;;;; Small built-ins worth having ----------------------------------------------

(defvar duplicate-line-final-position)
;; Emacs 29+: duplicate the region, or the line when there is none.
(when (fboundp 'duplicate-dwim)
  (setq duplicate-line-final-position -1))

;; Emacs 30: yanked code keeps sane indentation rather than stair-stepping.
(when (fboundp 'kill-ring-deindent-mode)
  (kill-ring-deindent-mode 1))

;; Kill the whole line including its newline when there is no region.
(setq kill-whole-line t
      ;; Do not clutter the kill ring with duplicates.
      kill-do-not-save-duplicates t)

;; Case commands operate on the region when one is active, else the word.
(setq case-replace t)

;; Comment/uncomment behaves sensibly with no region.
(setq comment-style 'indent)

(provide 'mjb-editing)
;;; mjb-editing.el ends here
