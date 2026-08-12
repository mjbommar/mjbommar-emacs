;;; mjb-cheatsheet.el --- Generated key reference buffer -*- lexical-binding: t -*-

;;; Commentary:
;; The `C-c ?' buffer.  Rendered from `mjb-key-table' and the grouping data in
;; mjb-keys.el, which is the same source `scripts/gen-keyboard-doc.el' uses for
;; KEYBOARD.md -- so the on-screen sheet and the committed file cannot drift
;; apart, and neither can drift from the bindings themselves.
;;
;; Autoloaded, not required.  Loading it at startup cost a measured 6 ms
;; (117.6 ms -> 111.5 ms) for code that only runs when the key is pressed.

;;; Code:

(require 'mjb-keys)

(defvar-keymap mjb-cheatsheet-mode-map
  :doc "Keymap for `mjb-cheatsheet-mode'."
  "q" #'quit-window
  "g" #'mjb-cheatsheet)

(define-derived-mode mjb-cheatsheet-mode special-mode "Keys"
  "Read-only key reference generated from `mjb-key-table'."
  (setq-local truncate-lines t
              cursor-type nil))

(defun mjb-cheat--rows (title rows)
  "Return display lines for TITLE and ROWS as (STRING ...)."
  (when rows
    (let ((w (apply #'max (mapcar (lambda (r) (length (nth 0 r))) rows))))
      (cons (propertize title 'face 'mjb-cheat-heading)
            (mapcar (lambda (r)
                      (concat "  "
                              (propertize (string-pad (nth 0 r) w) 'face 'help-key-binding)
                              "  " (nth 2 r)))
                    rows)))))

(defface mjb-cheat-heading '((t :inherit font-lock-keyword-face :weight bold))
  "Face for cheat-sheet section headings." :group 'mjb-keys)

(defun mjb-cheat--columns (blocks width)
  "Lay BLOCKS (each a list of lines) into two columns when WIDTH allows.

The feasibility test has to come *after* the split, not before: measuring
the widest line over the whole sheet says nothing about whether the two
halves fit side by side, and a single long row in the last block was
enough to collapse the whole layout back to one column."
  (let* ((padded (mapcar (lambda (b) (append b '(""))) blocks))
         (all (apply #'append padded))
         (half (/ (1+ (length all)) 2))
         (n 0) left right)
    (dolist (b padded)
      (if (< n half) (setq left (append left b)) (setq right (append right b)))
      (setq n (+ n (length b))))
    (let* ((lw (apply #'max 0 (mapcar #'string-width left)))
           (rw (apply #'max 0 (mapcar #'string-width right)))
           (gap 3))
      (if (or (null right) (> (+ lw gap rw) width))
          all
        (let ((rows (max (length left) (length right))) out)
          (dotimes (i rows)
            (let ((l (or (nth i left) "")) (r (or (nth i right) "")))
              (push (string-trim-right
                     (concat l (make-string (max 1 (- (+ lw gap) (string-width l))) ?\s) r))
                    out)))
          (nreverse out))))))

;;;###autoload
(defun mjb-cheatsheet ()
  "Show every keybinding, generated from `mjb-key-table'.
Press \\`q' to close, \\`g' to refresh."
  (interactive)
  (let ((buf (get-buffer-create mjb-cheatsheet-buffer))
        (width (window-width (or (get-buffer-window mjb-cheatsheet-buffer)
                                 (selected-window)))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (mjb-cheatsheet-mode)
        (insert (propertize "Keybindings" 'face 'mjb-cheat-heading)
                (format "  --  %d global, generated from mjb-key-table.  q closes.\n\n"
                        (length mjb-key-table)))
        (let (blocks)
          (pcase-dolist (`(,title . ,rows) (mjb-keys-grouped))
            (when-let* ((b (mjb-cheat--rows title rows))) (push b blocks)))
          (push (cons (propertize "Mode-local" 'face 'mjb-cheat-heading)
                      (let ((w (apply #'max (mapcar (lambda (r) (length (nth 1 r)))
                                                    mjb-mode-local-keys))))
                        (mapcar (lambda (r)
                                  (concat "  " (propertize (string-pad (nth 1 r) w)
                                                           'face 'help-key-binding)
                                          "  " (nth 0 r) ": " (nth 2 r)))
                                mjb-mode-local-keys)))
                blocks)
          (insert (mapconcat #'identity
                             (mjb-cheat--columns (nreverse blocks) width) "\n")))
        (insert "\n\n" (propertize "Not bound, deliberately" 'face 'mjb-cheat-heading) "\n")
        (let ((kw (apply #'max (mapcar (lambda (r) (length (nth 0 r))) mjb-keys-unbound)))
              (cw (apply #'max (mapcar (lambda (r) (length (nth 1 r))) mjb-keys-unbound))))
          (dolist (r mjb-keys-unbound)
            (insert "  " (propertize (string-pad (nth 0 r) kw) 'face 'help-key-binding)
                    "  " (string-pad (nth 1 r) cw) "  " (nth 2 r) "\n")))
        (goto-char (point-min))))
    (pop-to-buffer buf '((display-buffer-same-window)))
    buf))

(provide 'mjb-cheatsheet)
;;; mjb-cheatsheet.el ends here
