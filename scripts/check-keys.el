;;; check-keys.el --- Assert the keybinding table is real -*- lexical-binding: t -*-
;;; Commentary:
;; Implements the R-030 acceptance test.  Loads the full configuration, then
;; checks every entry in `mjb-key-table':
;;   - the key resolves to a command (not `unbound', not a keymap)
;;   - it resolves to the command the table CLAIMS
;;   - no two entries silently shadow each other via a prefix
;; Also checks that keys we deliberately left alone still have their defaults.
;;
;; Usage:  emacs --batch -l scripts/check-keys.el
;;; Code:

(require 'mjb-keys)

(defvar mjb-check--failures 0)

(defun mjb-check--fail (fmt &rest args)
  (setq mjb-check--failures (1+ mjb-check--failures))
  (princ (concat "  FAIL  " (apply #'format fmt args) "\n")))

(princ "Checking keybinding table...\n")

;; 1. Every declared binding resolves to its declared command.
(dolist (entry mjb-key-table)
  (let* ((keystr (nth 0 entry))
         (want   (nth 1 entry))
         (got    (key-binding (kbd keystr))))
    (cond
     ((null got)      (mjb-check--fail "%-10s unbound (want %s)" keystr want))
     ((keymapp got)   (mjb-check--fail "%-10s is a PREFIX, want command %s" keystr want))
     ((not (eq got want))
      (mjb-check--fail "%-10s -> %s, table says %s" keystr got want)))))

;; 2. No entry is a strict prefix of another (that shadowing is what F-03 was).
(let ((keys (mapcar #'car mjb-key-table)))
  (dolist (a keys)
    (dolist (b keys)
      (unless (equal a b)
        (when (string-prefix-p (concat a " ") b)
          (mjb-check--fail "%s is a prefix of %s -- one of them cannot fire" a b))))))

;; 3. Keys we deliberately did NOT take must still have their defaults (R-034).
(dolist (pair '(("M-y" yank-pop)
                ("M-l" downcase-word)
                ("M-0" digit-argument)
                ("C-x C-w" write-file)
                ("C-y" yank)
                ("C-/" undo)))
  (let ((got (key-binding (kbd (car pair)))))
    (unless (eq got (cadr pair))
      (mjb-check--fail "%-8s -> %s, should still be %s" (car pair) got (cadr pair)))))

;; 4. Prefixes we claim to own must actually be prefixes.
(dolist (p mjb-key-prefixes)
  (let ((got (key-binding (kbd (car p)))))
    (unless (keymapp got)
      (mjb-check--fail "prefix %s -> %s, expected a keymap" (car p) got))))

;; 5. C-c p must be the project map, with nothing shadowing it (F-04).
(let ((got (key-binding (kbd "C-c p"))))
  (unless (keymapp got)
    (mjb-check--fail "C-c p -> %s, expected project-prefix-map" got)))


;; 6. Minor-mode maps must not shadow the global table (F-03 / F-04 again).
;;    A minor-mode map takes precedence over the global map, so a duplicate key
;;    here does not collide loudly -- it silently changes what the key does, and
;;    only while that mode is active.  Both instances found this way were in
;;    eglot-mode-map, so they misfired only with a language server attached:
;;    C-c c n became eglot-rename instead of flymake-goto-next-error, and
;;    C-c c f became eglot-format-buffer, bypassing ruff and rustfmt.
;;
;;    `keymap-lookup' returns an integer when the sequence merely runs past a
;;    prefix, so only real commands count.
(dolist (spec '((eglot   . eglot-mode-map)
                (corfu   . corfu-map)
                (vertico . vertico-map)))
  (when (require (car spec) nil t)
    (let ((map (symbol-value (cdr spec))))
      (dolist (e mjb-key-table)
        (let ((hit (ignore-errors (keymap-lookup map (car e)))))
          (when (and hit (not (numberp hit)) (commandp hit))
            (mjb-check--fail
             "%s shadows the global table: %s is %s globally but %s in %s"
             (cdr spec) (car e) (nth 1 e) hit (cdr spec))))))))

(princ (format "\n%d binding(s) checked, %d failure(s)\n"
               (+ (length mjb-key-table) 6 (length mjb-key-prefixes))
               mjb-check--failures))
(kill-emacs (if (> mjb-check--failures 0) 1 0))
;;; check-keys.el ends here
