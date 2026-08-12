;;; mjb-rust.el --- Rust editing -*- lexical-binding: t -*-

;;; Commentary:
;; Rust was entirely unconfigured until 2026-08-12: `.rs' files opened in
;; `fundamental-mode' -- no highlighting, no indentation, no LSP -- despite
;; rust-analyzer, rustfmt and clippy all being installed and eight Cargo
;; projects on disk.
;;
;; The cause is a chicken-and-egg in Emacs itself.  rust-ts-mode.el ends with:
;;
;;     (if (treesit-ready-p 'rust)
;;         (add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-ts-mode)))
;;
;; That runs when the file is *loaded*, and nothing loads it, because the only
;; thing that would is the auto-mode-alist entry it is trying to add.  So the
;; mapping has to be made here.  It is guarded on the grammar so a machine
;; without it degrades to prog-mode rather than to a broken major mode.
;;
;; Everything else is built in: rust-ts-mode, eglot, compile, flymake.  No
;; packages.

;;; Code:

(require 'mjb-core)
(require 'compile)

(defvar rust-ts-mode-map)
(declare-function rust-ts-mode "rust-ts-mode")

(defgroup mjb-rust nil "Rust editing." :group 'rust)

;;;; Mode association -----------------------------------------------------------

(if (and (fboundp 'treesit-ready-p) (treesit-ready-p 'rust t))
    (add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-ts-mode))
  ;; No grammar: prog-mode still gives comments, parens and a sane TAB, and
  ;; the message names the fix instead of leaving you guessing.
  (add-to-list 'auto-mode-alist '("\\.rs\\'" . prog-mode))
  (with-eval-after-load 'prog-mode
    (message "mjb: no rust tree-sitter grammar; M-x mjb-install-treesit-grammars")))

;;;; Formatting -----------------------------------------------------------------

(defcustom mjb-rust-format-on-save t
  "Reformat with rustfmt before saving a Rust buffer."
  :type 'boolean :group 'mjb-rust)

(defun mjb-rust-format-buffer ()
  "Format the current buffer with `rustfmt'.
Uses `mjb-format-external', so a rustfmt failure leaves the buffer
untouched rather than emptying it."
  (interactive)
  (mjb-format-external "rustfmt" '("--emit" "stdout" "--quiet")))

(add-to-list 'mjb-format-functions '(rust-ts-mode . mjb-rust-format-buffer))

(defun mjb-rust-maybe-format ()
  "Format before save when `mjb-rust-format-on-save' is set."
  (when (and mjb-rust-format-on-save
             (derived-mode-p 'rust-ts-mode)
             (executable-find "rustfmt"))
    (mjb-rust-format-buffer)))

(add-hook 'before-save-hook #'mjb-rust-maybe-format)

;;;; Cargo, via built-in compile ------------------------------------------------
;; `compilation-error-regexp-alist' already understands rustc's
;; "  --> src/main.rs:12:5" through the `rustc' rule that ships with Emacs, so
;; errors are navigable with no extra configuration.

(defun mjb-rust--root ()
  "Directory of the nearest Cargo.toml, or nil."
  (when-let* ((dir (locate-dominating-file default-directory "Cargo.toml")))
    (expand-file-name dir)))

(defun mjb-rust-cargo (command &optional edit)
  "Run cargo COMMAND at the crate root, asynchronously.
With EDIT non-nil, offer the command line for editing first."
  (interactive (list (completing-read "cargo: " '("check" "clippy" "test" "build" "run")
                                      nil nil "check")
                     current-prefix-arg))
  (let* ((root (or (mjb-rust--root)
                   (user-error "mjb-rust: no Cargo.toml above %s" default-directory)))
         (cmd (format "cargo %s --color never" command))
         (default-directory root))
    (compile (if edit (read-shell-command "Build: " cmd) cmd))))

(defun mjb-rust-check ()  "Run `cargo check'."  (interactive) (mjb-rust-cargo "check"))
(defun mjb-rust-clippy () "Run `cargo clippy'." (interactive) (mjb-rust-cargo "clippy"))
(defun mjb-rust-test ()   "Run `cargo test'."   (interactive) (mjb-rust-cargo "test"))

;;;; LSP, only if the server exists (R-051) --------------------------------------

(defun mjb-rust-maybe-start-lsp ()
  "Start eglot when rust-analyzer is installed."
  (when (executable-find "rust-analyzer")
    (require 'eglot)
    (eglot-ensure)))

(add-hook 'rust-ts-mode-hook #'mjb-rust-maybe-start-lsp)

;; No explicit flymake-mode hook: eglot turns flymake on itself when it
;; attaches, and rust has no flymake backend without a server -- enabling it
;; unconditionally would just leave a backend-less flymake on a machine with no
;; rust-analyzer.  `cargo check' via C-c C-c covers that case.

;;;; Mode-local keys ------------------------------------------------------------
;; C-c C-<letter> is the range reserved for major modes, so these cannot
;; collide with `mjb-key-table' (which owns C-c <letter>).

(with-eval-after-load 'rust-ts-mode
  (keymap-set rust-ts-mode-map "C-c C-c" #'mjb-rust-check)
  (keymap-set rust-ts-mode-map "C-c C-l" #'mjb-rust-clippy)
  (keymap-set rust-ts-mode-map "C-c C-t" #'mjb-rust-test)
  (keymap-set rust-ts-mode-map "C-c C-k" #'mjb-rust-cargo))

(provide 'mjb-rust)
;;; mjb-rust.el ends here
