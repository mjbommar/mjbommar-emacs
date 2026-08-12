;;; init.el --- Loader -*- lexical-binding: t -*-

;;; Commentary:
;; A loader and nothing else.  Configuration lives in lisp/mjb-*.el, one topic
;; per file; the module list at the bottom is the map.
;;
;; Design rules (see docs/requirements/):
;;   - Built-in first.  Then hand-written elisp.  Then a package, justified.
;;   - Global keys live ONLY in mjb-keys.el, so collisions are a diff.
;;   - Nothing loads that cannot function in the current frame type.
;;
;; Requirement refs: R-001 (<=80 lines), R-004/R-008 (packages), R-007 (clean load).

;;; Code:

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;; --- Package system (R-008) --------------------------------------------------
;; Built-in package.el, deliberately: elpaca and straight are each thousands of
;; lines of external dependency whose job is managing dependencies, which does
;; not pay at this scale.
(require 'package)
(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/"))
      ;; Prefer signed GNU/NonGNU ELPA over MELPA when a package is on both.
      package-archive-priorities '(("gnu" . 3) ("nongnu" . 2) ("melpa" . 1))
      package-native-compile t
      package-quickstart t)

(defvar mjb-packages
  '(vertico orderless marginalia consult corfu cape ; completion: wrap built-in APIs
    magit diff-hl                                   ; git: essential complexity
    markdown-mode csv-mode                          ; no built-in equivalent
    vterm                                           ; compiled terminal emulator
    gptel minuet)                                   ; AI
  "Every package this configuration installs.
Anything not listed is a transitive dependency.  Adding an entry requires a
comment saying what it does that a built-in cannot.  Note there is no theme
package: the Modus themes ship with Emacs 30 and are built to a measured
contrast ratio, which is what terminal and GUI frames both need.")

(defun mjb-install-packages ()
  "Install any member of `mjb-packages' that is missing.  Idempotent (R-073)."
  (interactive)
  (let ((missing (seq-remove #'package-installed-p mjb-packages)))
    (when missing
      (unless package-archive-contents (package-refresh-contents))
      (mapc #'package-install missing))
    (message "mjb: %d packages, %d newly installed"
             (length mjb-packages) (length missing))))

(setq package-selected-packages mjb-packages)

;; --- Modules -----------------------------------------------------------------
;; Order matters: core before anything that depends on its paths, keys last so
;; it can bind commands the other modules have defined.
(require 'mjb-core)                     ; defaults, files, safety, clipboard
(require 'mjb-ui)                       ; theme, modeline, tabs, fonts
(require 'mjb-completion)               ; minibuffer + in-buffer completion
(require 'mjb-editing)                  ; pairing, undo, region, navigation
(require 'mjb-vc)                       ; magit, diff-hl
(require 'mjb-project)                  ; project.el, search, file sidebar
(require 'mjb-prose)                    ; text/markdown/spell
(require 'mjb-latex)                    ; tex-mode + reftex + latexmk
(require 'mjb-python)                   ; ruff, flymake, optional eglot
(require 'mjb-formats)                  ; json/yaml/toml/csv/org
(require 'mjb-shell)                    ; vterm, eshell
(require 'mjb-ai)                       ; gptel, minuet
(require 'mjb-keys)                     ; THE keybinding table

;; --- custom.el ---------------------------------------------------------------
;; Keep Customize's output out of this file.
(setq custom-file (expand-file-name "etc/custom.el" user-emacs-directory))
(when (file-exists-p custom-file) (load custom-file nil t))

(provide 'init)
;;; init.el ends here
