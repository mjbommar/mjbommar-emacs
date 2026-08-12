;;; mjb-shell.el --- Terminals inside Emacs -*- lexical-binding: t -*-

;;; Commentary:
;; Two built-in terminals, no packages.
;;
;; vterm was removed (2026-08-12).  What it bought was measured rather than
;; assumed: consuming 300,000 lines of output took vterm 1.69 s against
;; term.el's 3.88 s, a 2.3x edge and the whole of the difference -- term.el in
;; Emacs 30 handles 24-bit colour too (`term--color-as-hex').  What it cost was
;; the configuration's only unsigned package, its only C module, its only
;; alpha-status dependency, and the cmake/libtool prerequisites; on top of that
;; its CMakeLists downloaded libvterm's 5,778 lines of C from a personal GitHub
;; mirror at install time because no system libvterm was present.  Emacs here
;; runs inside tmux, where a real terminal is already one keystroke away, so
;; 2.3 s on a 300k-line dump did not justify any of that.  See README.
;;
;; A correction to what this file used to claim: eshell is NOT a terminal
;; emulator and was never the fallback it was described as.  It is an elisp
;; shell that hands curses programs off to `term-mode' via
;; `eshell-visual-commands' -- vi, vim, nvim, screen, tmux, top, htop, less,
;; more, lynx, links, ncftp, ncmpcpp, mutt, pine, tin, trn, elm by default.  So
;; the real terminal emulator in both paths below is the built-in term.el.

;;; Code:

(require 'mjb-core)

(defvar eshell-scroll-to-bottom-on-input)
(defvar eshell-hist-ignoredups)
(defvar eshell-save-history-on-exit)
(defvar eshell-history-size)
(defvar eshell-error-if-no-glob)
(defvar eshell-destroy-buffer-when-process-dies)
(defvar eshell-visual-commands)
(defvar term-buffer-maximum-size)
(defvar term-scroll-to-bottom-on-output)
(declare-function ansi-term "term" (program &optional new-buffer-name))

(defgroup mjb-shell nil "Terminals." :group 'processes)

;;;; eshell ---------------------------------------------------------------------

(with-eval-after-load 'eshell
  (setq eshell-scroll-to-bottom-on-input 'all
        eshell-hist-ignoredups t
        eshell-save-history-on-exit t
        eshell-history-size 5000
        eshell-error-if-no-glob t
        eshell-destroy-buffer-when-process-dies t))

;; `eshell-syntax-highlighting' is removed: no evidence of eshell use at all
;; (the history file was empty), and it is 400 lines to colourise a prompt.

;;;; term -----------------------------------------------------------------------

(with-eval-after-load 'term
  (setq term-buffer-maximum-size 10000     ; matches the old vterm scrollback
        term-scroll-to-bottom-on-output t))

;; Programs that need a real tty, added to eshell's hand-off list.  Each one
;; takes over the screen, which eshell cannot do and term.el can.
(with-eval-after-load 'em-term
  (dolist (cmd '("ssh" "htop" "btop" "ncdu" "fzf" "lazygit" "nvtop"))
    (add-to-list 'eshell-visual-commands cmd)))

;;;; One entry point ------------------------------------------------------------

(defun mjb-terminal (&optional arg)
  "Open `eshell'.  With prefix ARG, open a real tty via `ansi-term'.

eshell is the better default here: it is an elisp shell, so it reaches
Emacs functions, dired buffers and remote TRAMP paths directly, and it
delegates full-screen programs to term.el on its own.  Reach for the
prefix when you want a genuine tty for the whole session -- an
interactive remote shell, or a program not in `eshell-visual-commands'."
  (interactive "P")
  (if arg
      (ansi-term (or (executable-find "bash") shell-file-name))
    (eshell)))

(provide 'mjb-shell)
;;; mjb-shell.el ends here
