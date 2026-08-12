;;; mjb-shell.el --- Terminals inside Emacs -*- lexical-binding: t -*-

;;; Commentary:
;; vterm is the only good terminal emulator for Emacs.  It is a compiled C
;; module, and building it needs cmake AND libtool.  Both are installed here
;; now and the module is built and verified working (a shell in the vterm
;; buffer evaluated `echo $((21*2))' and returned 42).
;;
;; If it ever needs rebuilding -- a vterm upgrade, or a new machine:
;;
;;   sudo apt install cmake libtool libtool-bin
;;   M-x mjb-vterm-build
;;
;; `mjb-vterm-build' checks for the prerequisites itself, and
;; `mjb-vterm-available-p' checks for the built artifact rather than trusting
;; vterm's own report.  That is deliberate: when libtool was missing, vterm's
;; elisp still printed "Compilation of `emacs-libvterm' module succeeded" while
;; cmake had actually failed, and `require' then died on a missing file.
;;
;; `mjb-terminal' falls back to `eshell' if the module is ever unavailable, so
;; the config never hard-fails on a machine that cannot build it.

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
