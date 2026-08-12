;;; count-packages.el --- R-008 provenance test -*- lexical-binding: t -*-
;;; Commentary:
;; Asserts the dependency budget: MELPA count under the cap, and nothing
;; installed that Emacs 30 already ships.
;;; Code:

(require 'mjb-package)

(defconst mjb-melpa-cap 20)

(defconst mjb-builtin-equivalents
  '(use-package which-key eglot project treesit-auto flycheck
    json-mode toml-mode yaml-mode undo-tree smartparens
    projectile no-littering hydra smart-jump dashboard
    all-the-icons nerd-icons kind-icon centaur-tabs doom-modeline
    doom-themes org-bullets python-black pyvenv reformatter
    markdown-preview-mode json-navigator eshell-syntax-highlighting)
  "Packages with a built-in or hand-written replacement in this config.
Installing any of them again is a regression.")

(defvar mjb-count--failures 0)
(defun mjb-count--fail (fmt &rest args)
  (setq mjb-count--failures (1+ mjb-count--failures))
  (princ (concat "  FAIL  " (apply #'format fmt args) "\n")))

(let* ((installed (mapcar #'car package-alist))
       (regressions (seq-intersection installed mjb-builtin-equivalents)))
  (princ (format "declared:  %d\n" (length mjb-packages)))
  (princ (format "installed: %d (declared + transitive dependencies)\n"
                 (length installed)))

  (when (> (length mjb-packages) mjb-melpa-cap)
    (mjb-count--fail "%d declared packages exceeds the cap of %d"
                     (length mjb-packages) mjb-melpa-cap))

  (dolist (p regressions)
    (mjb-count--fail "%s is installed but has a built-in replacement" p))

  ;; Every declared package must actually be installed.
  (dolist (p mjb-packages)
    (unless (package-installed-p p)
      (mjb-count--fail "%s is declared but not installed" p))))

(princ (format "\n%d failure(s)\n" mjb-count--failures))
(kill-emacs (if (> mjb-count--failures 0) 1 0))
;;; count-packages.el ends here
