;;; mjb-python.el --- Python, matched to the installed toolchain -*- lexical-binding: t -*-

;;; Commentary:
;; Fixes F-09.  The previous config hooked `eglot-ensure' into python-mode with
;; pyright NOT installed (so every Python buffer opened a failing LSP
;; connection), enabled `python-black-on-save-mode' with black NOT installed
;; (so format-on-save silently did nothing), and defined a `ruff-format'
;; reformatter that was never bound or hooked -- while ruff IS installed.
;;
;; This module uses what is actually on the machine: ruff for both formatting
;; and linting, built-in flymake rather than flycheck, and eglot only if a
;; server is present.
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
Output is captured and validated before replacing the buffer, so a ruff
failure leaves your file untouched rather than emptying it.
`replace-buffer-contents' is used so point, markers and the undo history
survive the round trip."
  (interactive)
  (unless (executable-find "ruff")
    (user-error "mjb-python: ruff is not installed"))
  (let ((out (generate-new-buffer " *mjb-ruff-format*"))
        (errfile (make-temp-file "mjb-ruff-err"))
        (origin (point)))
    (unwind-protect
        (let ((status (call-process-region (point-min) (point-max) "ruff"
                                           nil (list out errfile) nil
                                           "format" "-")))
          (if (and (integerp status) (zerop status) (> (buffer-size out) 0))
              (progn
                (replace-buffer-contents out)
                (goto-char (min origin (point-max))))
            (message "mjb-python: ruff format failed (%s): %s"
                     status
                     (with-temp-buffer
                       (insert-file-contents errfile)
                       (string-trim (buffer-string))))))
      (kill-buffer out)
      (delete-file errfile))))

(defun mjb-python-maybe-format ()
  "Format on save when `mjb-python-format-on-save' is enabled."
  (when (and mjb-python-format-on-save (derived-mode-p 'python-base-mode))
    (mjb-python-format-buffer)))

(add-hook 'before-save-hook #'mjb-python-maybe-format)

;;;; Interpreter and environments -----------------------------------------------

(setq python-indent-offset 4
      python-indent-guess-indent-offset nil  ; do not guess; be consistent
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

;;;; LSP, only if a server exists (R-051) ---------------------------------------
;; pyright is NOT installed on this machine.  Rather than opening a failing
;; connection in every Python buffer -- which is what the previous config did --
;; attach eglot only when a server binary is actually present.

(defcustom mjb-python-lsp-servers '("basedpyright-langserver" "pyright-langserver"
                                    "pylsp" "jedi-language-server" "ruff-lsp")
  "Language servers to look for, in order of preference."
  :type '(repeat string) :group 'mjb-python)

(defun mjb-python-maybe-start-lsp ()
  "Start eglot only if one of `mjb-python-lsp-servers' is installed."
  (when (seq-some #'executable-find mjb-python-lsp-servers)
    (require 'eglot)
    (eglot-ensure)))

(add-hook 'python-base-mode-hook #'mjb-python-maybe-start-lsp)

(with-eval-after-load 'eglot
  (setq eglot-autoshutdown t
        eglot-sync-connect 0            ; never block the UI waiting to connect
        eglot-events-buffer-config '(:size 0 :format short)
        eglot-extend-to-xref t))

(provide 'mjb-python)
;;; mjb-python.el ends here
