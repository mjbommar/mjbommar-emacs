;;; mjb-shell.el --- Terminals inside Emacs -*- lexical-binding: t -*-

;;; Commentary:
;; vterm is the only good terminal emulator for Emacs, but it is a compiled C
;; module and BUILDING IT REQUIRES libtool, which is not installed on this
;; machine:
;;
;;   CMake Error at CMakeLists.txt:75 (message):
;;     libtool not found.  Please install libtool
;;
;; To enable it:  sudo apt install libtool libtool-bin
;; then:          M-x mjb-vterm-build
;;
;; Note vterm's own elisp reports "Compilation of `emacs-libvterm' module
;; succeeded" even when cmake failed, so the failure is quiet -- hence the
;; explicit check here rather than trusting it.
;;
;; Until then `mjb-terminal' falls back to `eshell', which is built in.  You
;; also already have tmux, which is where terminals actually live on this
;; machine, so this module is a convenience rather than load-bearing.

;;; Code:

(require 'mjb-core)

(defvar vterm-max-scrollback)
(defvar vterm-shell)
(defvar vterm-kill-buffer-on-exit)
(defvar vterm-copy-exclude-prompt)
(defvar vterm-timer-delay)
(defvar eshell-scroll-to-bottom-on-input)
(defvar eshell-hist-ignoredups)
(defvar eshell-save-history-on-exit)
(defvar eshell-history-size)
(defvar eshell-error-if-no-glob)
(defvar eshell-destroy-buffer-when-process-dies)
(declare-function vterm "vterm" (&optional arg))
(declare-function vterm-module-compile "vterm-module")

(defgroup mjb-shell nil "Terminals." :group 'processes)

;;;; vterm ----------------------------------------------------------------------

(defun mjb-vterm-available-p ()
  "Return non-nil if vterm's compiled module can actually be loaded."
  (and (locate-library "vterm")
       (or (featurep 'vterm-module)
           (locate-library "vterm-module"))))

(defun mjb-vterm-build ()
  "Build vterm's C module, reporting the real prerequisite if it fails."
  (interactive)
  (unless (executable-find "cmake")
    (user-error "mjb: cmake is required to build vterm"))
  (unless (executable-find "libtool")
    (user-error "mjb: libtool is required to build vterm.  \
Run: sudo apt install libtool libtool-bin"))
  (require 'vterm)
  (vterm-module-compile)
  (message "mjb: vterm module built; restart Emacs"))

(with-eval-after-load 'vterm
  (setq vterm-max-scrollback 10000
        vterm-shell (or (executable-find "bash") shell-file-name)
        vterm-kill-buffer-on-exit t
        vterm-copy-exclude-prompt t
        ;; Lower latency at a small CPU cost; this is a terminal, so latency
        ;; is the whole point.
        vterm-timer-delay 0.02))

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

;;;; One entry point ------------------------------------------------------------

(defun mjb-terminal (&optional arg)
  "Open a terminal: vterm when its module is built, otherwise eshell.
With prefix ARG, force eshell."
  (interactive "P")
  (if (and (not arg) (mjb-vterm-available-p))
      (vterm)
    (when (and (not arg) (locate-library "vterm"))
      (message "mjb: vterm module not built (needs libtool); using eshell"))
    (eshell)))

(provide 'mjb-shell)
;;; mjb-shell.el ends here
