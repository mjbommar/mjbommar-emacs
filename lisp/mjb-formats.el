;;; mjb-formats.el --- Data and markup formats -*- lexical-binding: t -*-

;;; Commentary:
;; Three of the four format packages the previous config installed are
;; unnecessary on Emacs 30: `js-json-mode', `conf-toml-mode' and `yaml-ts-mode'
;; are built in.  That removes json-mode, toml-mode and yaml-mode (plus
;; json-snatcher and json-navigator) for no loss of function.
;;
;; csv-mode is kept -- there is no built-in equivalent, and it is one of the
;; few GPG-signed GNU ELPA packages in the tree.
;;
;; Requirement refs: R-041 (tree-sitter grammars), R-055.

;;; Code:

(require 'mjb-core)

;; `treesit-available-p' is a C primitive, but `treesit-ready-p' and
;; `treesit-language-available-p' live in treesit.el.  Without this require the
;; `(fboundp 'treesit-ready-p)' guards below are simply nil and every
;; tree-sitter mode is silently skipped -- which is exactly what happened on
;; the first run, with all seven grammars installed and working.
(when (and (fboundp 'treesit-available-p) (treesit-available-p))
  (require 'treesit))

(defvar treesit-language-source-alist)  ; special only once treesit.el loads
(defvar csv-separators)
(defvar csv-align-style)
(defvar org-startup-indented)
(defvar org-pretty-entities)
(defvar org-hide-emphasis-markers)
(defvar org-startup-with-inline-images)
(defvar org-image-actual-width)
(defvar org-src-fontify-natively)
(defvar org-edit-src-content-indentation)
(defvar org-directory)

;;;; JSON, TOML, YAML -- all built in -------------------------------------------

;; JSON: `js-json-mode' ships with Emacs and is what .json should open in.
(add-to-list 'auto-mode-alist '("\\.json\\'" . js-json-mode))
(add-to-list 'auto-mode-alist '("\\.jsonl\\'" . js-json-mode))
(add-hook 'js-json-mode-hook (lambda () (setq-local js-indent-level 2)))

;; TOML: `conf-toml-mode' ships with Emacs.
(add-to-list 'auto-mode-alist '("\\.toml\\'" . conf-toml-mode))
(add-to-list 'auto-mode-alist '("\\`Cargo\\.lock\\'" . conf-toml-mode))

;; YAML: only `yaml-ts-mode' exists in core, and it needs a grammar (R-041).
;; Fall back to conf-mode when the grammar is missing so .yaml files still open
;; sensibly rather than in fundamental-mode.
(add-to-list 'auto-mode-alist
             (cons "\\.ya?ml\\'"
                   (if (and (fboundp 'treesit-ready-p)
                            (treesit-ready-p 'yaml t))
                       'yaml-ts-mode
                     'conf-mode)))

;;;; Tree-sitter (R-041) ---------------------------------------------------------
;; Grammars are NOT installed by default -- the previous config had treesit-auto
;; with zero grammars, so no *-ts-mode could ever activate.  `treesit-auto' is
;; removed; Emacs 30 does the remapping natively via `major-mode-remap-alist'.
;;
;; Run `M-x mjb-install-treesit-grammars' once to fetch them.

(defcustom mjb-treesit-grammars
  '((python     . ("https://github.com/tree-sitter/tree-sitter-python"))
    (json       . ("https://github.com/tree-sitter/tree-sitter-json"))
    (yaml       . ("https://github.com/ikatyang/tree-sitter-yaml"))
    (toml       . ("https://github.com/tree-sitter/tree-sitter-toml"))
    (c          . ("https://github.com/tree-sitter/tree-sitter-c"))
    (rust       . ("https://github.com/tree-sitter/tree-sitter-rust"))
    (bash       . ("https://github.com/tree-sitter/tree-sitter-bash"))
    (markdown   . ("https://github.com/tree-sitter-grammars/tree-sitter-markdown"
                   "split_parser" "tree-sitter-markdown/src")))
  "Grammars to fetch, in `treesit-language-source-alist' form.
Note LaTeX has no tree-sitter mode in Emacs 30, so the largest workload
here is served by font-lock and mjb-latex.el regardless."
  :type '(alist :key-type symbol) :group 'mjb-core)

(defun mjb-install-treesit-grammars (&optional force)
  "Install any missing grammar in `mjb-treesit-grammars'.
With FORCE, reinstall everything.  Requires git and a C compiler."
  (interactive "P")
  ;; `require' must come FIRST: `treesit-language-source-alist' is only a
  ;; special variable once treesit.el has been loaded.  Binding it in a `let'
  ;; before that creates a lexical binding, which
  ;; `treesit-install-language-grammar' would never see -- it reads the global.
  (require 'treesit)
  (unless (treesit-available-p)
    (user-error "mjb: this Emacs was built without tree-sitter"))
  (let ((treesit-language-source-alist mjb-treesit-grammars)
        (installed 0))
    (dolist (entry mjb-treesit-grammars)
      (let ((lang (car entry)))
        (when (or force (not (treesit-language-available-p lang)))
          (message "mjb: installing tree-sitter grammar for %s..." lang)
          (condition-case err
              (progn (treesit-install-language-grammar lang)
                     (setq installed (1+ installed)))
            (error (message "mjb: grammar %s failed: %s" lang
                            (error-message-string err)))))))
    (message "mjb: %d grammar(s) installed; restart to pick them up" installed)))

;; Route to the tree-sitter mode only for grammars that are actually present,
;; so a missing grammar never leaves you in a broken mode.
(dolist (pair '((python-mode . python-ts-mode)
                (c-mode      . c-ts-mode)
                (sh-mode     . bash-ts-mode)))
  (when (and (fboundp 'treesit-ready-p)
             (treesit-ready-p (intern (string-remove-suffix
                                       "-ts-mode" (symbol-name (cdr pair))))
                              t))
    (add-to-list 'major-mode-remap-alist pair)))

;;;; CSV ------------------------------------------------------------------------

(autoload 'csv-mode "csv-mode" nil t)
(add-to-list 'auto-mode-alist '("\\.[ct]sv\\'" . csv-mode))

(with-eval-after-load 'csv-mode
  (setq csv-separators '("," ";" "\t")
        csv-align-style 'auto))

;;;; Org ------------------------------------------------------------------------
;; Built in.  Kept minimal: there is no evidence of org use on this machine
;; (var/org/ is empty), but gptel writes its chat buffers in org-mode.

(setq org-directory (expand-file-name "~/org/"))

(with-eval-after-load 'org
  (setq org-startup-indented t
        org-pretty-entities t
        org-hide-emphasis-markers t
        org-startup-with-inline-images nil   ; no images in a terminal
        org-image-actual-width '(600)
        org-src-fontify-natively t
        org-edit-src-content-indentation 0))

;; `org-bullets' is removed: it is a font-lock tweak that needs a GUI font to
;; look like anything, and Emacs 30's org-indent already handles the structure.

(provide 'mjb-formats)
;;; mjb-formats.el ends here
