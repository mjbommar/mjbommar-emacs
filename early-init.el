;;; early-init.el --- Pre-GUI, pre-package startup -*- lexical-binding: t -*-

;;; Commentary:
;; Runs before the package system and before the first frame exists.
;; Only put things here that MUST happen that early: GC tuning, frame
;; parameters (to avoid a visible resize), and native-compilation policy.
;;
;; Requirement refs: R-002 (native comp), R-006 (startup budget).

;;; Code:

;; --- Startup GC -------------------------------------------------------------
;; Raise the GC threshold for the duration of startup, then hand off to
;; `mjb-core' which installs the steady-state values.  Without this, Emacs
;; garbage-collects several times while loading init, which is pure waste.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; `file-name-handler-alist' is consulted for every `load' and `require'.
;; Nothing during startup needs TRAMP or archive handlers, so switch it off
;; and restore it once we are up.
(defvar mjb--file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist mjb--file-name-handler-alist))
          ;; Depth 90: run late, after other startup hooks.
          90)

;; --- Native compilation (R-002) ---------------------------------------------
;; The previous config set `native-comp-deferred-compilation', which was
;; renamed in Emacs 29.1.  It is an obsolete *alias*, so assigning nil to it
;; silently disabled JIT native compilation entirely -- 0 .eln files were
;; produced for 85 installed packages.  Leave JIT enabled; just keep it quiet.
(setq native-comp-async-report-warnings-errors 'silent
      native-comp-jit-compilation t)

;; --- Editing this configuration ----------------------------------------------
;; If a lisp/mjb-*.elc is stale, prefer the .el you just edited.  Without this,
;; changing a module and restarting silently loads the OLD byte-compiled
;; version until you remember to recompile -- a nasty footgun for a config
;; whose whole point is that you keep editing it.
(setq load-prefer-newer t)

;; --- Package paths -----------------------------------------------------------
;; These MUST be here, not in init.el.  Emacs activates packages -- and loads
;; the quickstart file -- between early-init.el and init.el, so anything set
;; later is too late to be used for this startup.  Their defaults are also
;; computed at defcustom time, which silently pointed them at ~/.emacs.d.
(setq package-user-dir (expand-file-name "elpa" user-emacs-directory)
      package-quickstart-file
      (expand-file-name "var/package-quickstart.el" user-emacs-directory)
      package-quickstart t
      package-native-compile t)

;; --- Frame -------------------------------------------------------------------
;; Set these before the first frame is created so there is no flash-and-resize.
;; They are harmless on a tty build (emacs-nox ignores them).
(setq default-frame-alist
      '((menu-bar-lines . 0)
        (tool-bar-lines . 0)
        (vertical-scroll-bars)
        (horizontal-scroll-bars)
        (width . 120)
        (height . 40)))

(setq frame-inhibit-implied-resize t
      frame-resize-pixelwise t)

;; --- Startup screen ----------------------------------------------------------
;; Emacs is launched as `emacs <file>' here, which already suppresses the
;; splash; these make `emacs' with no argument behave the same way.
;; Note: `inhibit-startup-echo-area-message' only works when set to the literal
;; username string -- setting it to t (as the old config did) is a no-op.
(setq inhibit-startup-screen t
      inhibit-startup-message t
      inhibit-startup-echo-area-message (user-login-name)
      initial-scratch-message nil
      initial-major-mode 'fundamental-mode)

;; --- Redisplay ---------------------------------------------------------------
(setq fast-but-imprecise-scrolling t
      redisplay-skip-fontification-on-input t
      ;; Do not reorder bidirectional text we will never have.  Note we set
      ;; `bidi-paragraph-direction', NOT `bidi-display-reordering' -- the
      ;; latter is documented as "do not set this".
      bidi-inhibit-bpa t)
(setq-default bidi-paragraph-direction 'left-to-right)

(provide 'early-init)
;;; early-init.el ends here
