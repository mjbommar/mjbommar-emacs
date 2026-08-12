;;; mjb-python.el --- Python, matched to the installed toolchain -*- lexical-binding: t -*-

;;; Commentary:
;; Fixes F-09.  The previous config hooked `eglot-ensure' into python-mode with
;; pyright NOT installed (so every Python buffer opened a failing LSP
;; connection), enabled `python-black-on-save-mode' with black NOT installed
;; (so format-on-save silently did nothing), and defined a `ruff-format'
;; reformatter that was never bound or hooked -- while ruff IS installed.
;;
;; This module uses what is actually on the machine, and deliberately nothing
;; else.  The toolchain is Astral's, by explicit choice (2026-08-12):
;;
;;   uv    environments, dependencies, running things
;;   ty    type checking and the language server
;;   ruff  linting and formatting
;;
;; No pyright, basedpyright, pylsp, jedi, ruff-lsp, black, isort, flake8, mypy,
;; pyvenv or virtualenvwrapper.  None of them is installed here, and the older
;; server list this module used to carry named five of them.  `ruff-lsp' in
;; particular is upstream-deprecated in favour of `ruff server'.
;;
;; Requirement refs: R-051.

;;; Code:

(require 'mjb-core)
(require 'python)

;; eglot is loaded on demand; declare what we set.
(defvar eglot-autoshutdown)
(defvar eglot-sync-connect)
(defvar eglot-events-buffer-config)
(defvar eglot-extend-to-xref)
(declare-function eglot-ensure "eglot")
(defvar eglot-server-programs)

(defgroup mjb-python nil "Python editing." :group 'python)

;;;; Linting via ruff + built-in flymake ----------------------------------------
;; python.el has flymake support built in; it just defaults to pyflakes.
;; Pointing it at ruff needs no package and no custom backend.
;;
;; `ruff check --output-format=concise -' emits:  -:LINE:COL: CODE message

(when (executable-find "ruff")
  (setq python-flymake-command '("ruff" "check" "--output-format=concise" "-")
        python-flymake-command-output-pattern
        (list "^-:\\(?1:[0-9]+\\):\\(?2:[0-9]+\\): \\(?3:.*\\)$" 1 2 nil 3)
        ;; ruff prefixes every message with its rule code.  F-codes are real
        ;; errors (undefined name, syntax); style codes are warnings.
        python-flymake-msg-alist
        '(("\\`\\(?:E9\\|F6\\|F7\\|F82\\)" . :error)
          ("\\`[A-Z]" . :warning))))

(add-hook 'python-base-mode-hook #'flymake-mode)

;;;; Formatting via ruff --------------------------------------------------------

(defcustom mjb-python-format-on-save t
  "Whether to run `ruff format' when saving a Python buffer."
  :type 'boolean :group 'mjb-python)

(defun mjb-python-format-buffer ()
  "Format the current buffer with `ruff format'.
Uses `mjb-format-external', which captures the output and checks the exit
status before writing anything back, so a ruff failure leaves the buffer
untouched rather than emptying it."
  (interactive)
  (mjb-format-external "ruff" '("format" "--stdin-filename"
                                "stdin.py" "-")))

(defun mjb-python-maybe-format ()
  "Format on save when `mjb-python-format-on-save' is enabled."
  (when (and mjb-python-format-on-save (derived-mode-p 'python-base-mode))
    (mjb-python-format-buffer)))

(add-to-list 'mjb-format-functions '(python-base-mode . mjb-python-format-buffer))

(add-hook 'before-save-hook #'mjb-python-maybe-format)

;;;; Interpreter and environments -----------------------------------------------

(setq python-indent-offset 4
      python-indent-guess-indent-offset nil  ; do not guess; be consistent
      ;; Only the fallback: `mjb-python-activate-venv' overrides this per
      ;; buffer with the project's uv-created .venv/bin/python.
      python-shell-interpreter (or (executable-find "python3") "python3")
      ;; Do not warn about the readline/completion setup on every REPL start.
      python-shell-completion-native-enable nil)

(defun mjb-python-activate-venv ()
  "Point `exec-path' at the nearest .venv, if there is one.
`uv' is installed here and creates .venv in the project root, so a plain
upward search covers it.  Replaces the `pyvenv' package (~600 lines)."
  (when-let* ((root (locate-dominating-file default-directory ".venv"))
              (bin (expand-file-name ".venv/bin" root)))
    (when (file-directory-p bin)
      (setq-local exec-path (cons bin exec-path))
      (setq-local python-shell-interpreter (expand-file-name "python" bin))
      ;; process-environment is what subprocesses (ruff, flymake) actually read.
      (setq-local process-environment
                  (cons (concat "PATH=" bin path-separator (getenv "PATH"))
                        process-environment))
      (setq-local python-shell-virtualenv-root (expand-file-name ".venv" root)))))

(add-hook 'python-base-mode-hook #'mjb-python-activate-venv)

;;;; LSP: ty, and only ty (R-051) -----------------------------------------------
;; eglot ships a python entry that reaches for pylsp, pyright and friends.  It
;; is replaced rather than appended to: leaving it in place would mean that
;; installing one of those tools by accident silently changes which server
;; runs, which is exactly the drift this configuration exists to prevent.
;;
;; ty is a type checker first; ruff still does linting (flymake, above) and
;; formatting (below), so the two do not overlap.

(defcustom mjb-python-lsp-command '("ty" "server")
  "Language server command for Python.
Astral's `ty'.  Deliberately not a list of alternatives -- see R-051."
  :type '(repeat string) :group 'mjb-python)

(with-eval-after-load 'eglot
  (setq eglot-server-programs
        (cons (cons '(python-mode python-ts-mode) mjb-python-lsp-command)
              (seq-remove (lambda (e)
                            (let ((k (car e)))
                              (and (listp k) (memq 'python-ts-mode k))))
                          eglot-server-programs))))

(defun mjb-python-maybe-start-lsp ()
  "Start eglot when `mjb-python-lsp-command' names an installed program.
Attaching unconditionally is what the previous config did with pyright
absent, so every Python buffer opened a connection that could only fail."
  (when (executable-find (car mjb-python-lsp-command))
    (require 'eglot)
    (eglot-ensure)))

(add-hook 'python-base-mode-hook #'mjb-python-maybe-start-lsp)

(with-eval-after-load 'eglot
  (setq eglot-autoshutdown t
        eglot-sync-connect 0            ; never block the UI waiting to connect
        eglot-events-buffer-config '(:size 0 :format short)
        eglot-extend-to-xref t))


;;;; uv ------------------------------------------------------------------------
;; The only dependency/environment tool used here.  `uv' writes .venv into the
;; project root, which is what `mjb-python-activate-venv' above finds, so the
;; two halves already agree without any uv-specific plumbing.

(defun mjb-python--project-root ()
  "Directory of the nearest pyproject.toml, or nil."
  (when-let* ((dir (locate-dominating-file default-directory "pyproject.toml")))
    (expand-file-name dir)))

(defun mjb-python-uv (command &optional edit)
  "Run uv COMMAND at the project root, asynchronously via `compile'.
With EDIT non-nil (\\[universal-argument]), edit the command line first."
  (interactive (list (completing-read
                      "uv: " '("sync" "lock" "add" "remove" "run pytest"
                               "run python" "tree" "export")
                      nil nil "sync")
                     current-prefix-arg))
  (unless (executable-find "uv")
    (user-error "mjb-python: uv is not installed"))
  (let* ((root (or (mjb-python--project-root)
                   (user-error "mjb-python: no pyproject.toml above %s"
                               default-directory)))
         (cmd (format "uv %s" command))
         (default-directory root))
    (compile (if edit (read-shell-command "uv: " cmd) cmd))))

(defun mjb-python-check ()
  "Type-check the project with `ty check'."
  (interactive)
  (unless (executable-find "ty")
    (user-error "mjb-python: ty is not installed"))
  (let ((default-directory (or (mjb-python--project-root) default-directory)))
    (compile "ty check")))

(defun mjb-python-lint ()
  "Lint the project with `ruff check'."
  (interactive)
  (let ((default-directory (or (mjb-python--project-root) default-directory)))
    (compile "ruff check --output-format=concise")))

;; C-c C-<letter> is the major-mode range, so these cannot collide with
;; `mjb-key-table', which owns C-c <letter>.
(with-eval-after-load 'python
  (keymap-set python-mode-map "C-c C-u" #'mjb-python-uv)
  (keymap-set python-mode-map "C-c C-y" #'mjb-python-check)
  (keymap-set python-mode-map "C-c C-l" #'mjb-python-lint)
  (when (boundp 'python-ts-mode-map)
    (keymap-set python-ts-mode-map "C-c C-u" #'mjb-python-uv)
    (keymap-set python-ts-mode-map "C-c C-y" #'mjb-python-check)
    (keymap-set python-ts-mode-map "C-c C-l" #'mjb-python-lint)))

(provide 'mjb-python)
;;; mjb-python.el ends here
