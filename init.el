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
;; Requirement refs: R-001 (<=80 lines), R-004/R-008 (packages), R-007.

;;; Code:

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;; --- Package system (R-008) --------------------------------------------------
;; Built-in package.el deliberately: elpaca/straight are thousands of lines of
;; dependency whose job is managing dependencies, which does not pay here.
;;
;; NOTE package-user-dir, package-quickstart-file, package-quickstart and
;; package-native-compile live in early-init.el -- Emacs activates packages
;; BETWEEN early-init and this file, so setting them here would be too late.
;;
;; Archives, priorities and signature policy live in mjb-package.el: they take
;; effect at install time, not activation time, so they do not need to precede
;; `package-initialize'.
(require 'package)
(package-initialize)

(require 'mjb-package)                   ; archives, signatures, declared set

;; --- Modules -----------------------------------------------------------------
;; Order matters: core first, keys last (it binds the others' commands).
(require 'mjb-core)                     ; defaults, files, safety, clipboard
(require 'mjb-ui)                       ; theme, modeline, tabs, fonts
(require 'mjb-completion)               ; minibuffer + in-buffer completion
(require 'mjb-editing)                  ; pairing, undo, region, navigation
(require 'mjb-vc)                       ; magit, diff-hl
(require 'mjb-project)                  ; project.el, search, file sidebar
(require 'mjb-prose)                    ; text/markdown/spell
(require 'mjb-latex)                    ; tex-mode + reftex + latexmk
(require 'mjb-python)                   ; ruff, flymake, optional eglot
(require 'mjb-rust)                     ; rust-ts-mode, rustfmt, cargo, eglot
(require 'mjb-formats)                  ; json/yaml/toml/csv/org
(require 'mjb-shell)                    ; vterm, eshell
(require 'mjb-ai)                       ; multi-provider chat + completion
(require 'mjb-keys)                     ; THE keybinding table

;; --- custom.el ---------------------------------------------------------------
(setq custom-file (expand-file-name "etc/custom.el" user-emacs-directory))
(when (file-exists-p custom-file) (load custom-file nil t))

(provide 'init)
;;; init.el ends here
