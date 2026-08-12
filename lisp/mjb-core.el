;;; mjb-core.el --- Defaults, files, safety, clipboard -*- lexical-binding: t -*-

;;; Commentary:
;; Editor defaults and everything that protects your work.  No keybindings
;; (those live in mjb-keys.el) and no packages -- this file is entirely
;; built-in Emacs.
;;
;; Requirement refs:
;;   R-008  no `no-littering' package -- the eight paths we use, written out
;;   R-010  versioned backups, outside the source tree
;;   R-011  auto-save on
;;   R-012  lock files on
;;   R-013  API keys from auth-source, not the environment
;;   R-015  OSC 52 clipboard (works through tmux, and over SSH)
;;   R-016  recentf / savehist / save-place preserved
;;   R-020  exactly one delimiter-pairing mechanism
;;   R-023  built-in undo-redo
;;   R-024  so-long stays
;;   R-046  24-bit colour asserted, not assumed

;;; Code:

;; Forward declarations for variables belonging to libraries we deliberately do
;; NOT load at startup.  `defvar' with no value marks the symbol special for
;; the byte-compiler without assigning anything or pulling the library in --
;; the settings themselves are inside `with-eval-after-load' below.
(defvar tramp-persistency-file-name)
(defvar project-list-file)
(defvar url-configuration-directory)
(defvar eshell-directory-name)
(defvar bookmark-default-file)
(defvar transient-history-file)
(defvar transient-levels-file)
(defvar transient-values-file)

;; These two are small and we enable them anyway.
(require 'autorevert)
(require 'mwheel)

;;;; State directories ---------------------------------------------------------
;; Replaces the `no-littering' package (356 lines) with the eight paths this
;; configuration actually uses.  Everything Emacs writes goes under var/ or
;; etc/, so the repository stays clean and `git status' stays meaningful.

(defconst mjb-var-dir (expand-file-name "var/" user-emacs-directory)
  "Directory for state Emacs generates and may regenerate (caches, history).")

(defconst mjb-etc-dir (expand-file-name "etc/" user-emacs-directory)
  "Directory for configuration Emacs writes (custom.el, snippets).")

(defun mjb-var (path)
  "Return PATH under `mjb-var-dir', creating parent directories."
  (let ((full (expand-file-name path mjb-var-dir)))
    (make-directory (file-name-directory full) t)
    full))

(defun mjb-etc (path)
  "Return PATH under `mjb-etc-dir', creating parent directories."
  (let ((full (expand-file-name path mjb-etc-dir)))
    (make-directory (file-name-directory full) t)
    full))

;;;; Backups, auto-save, locks (R-010, R-011, R-012) ---------------------------
;; The previous configuration disabled all three.  On a machine used to write
;; book-length LaTeX across multi-hour sessions that is the single highest
;; consequence defect in the whole config, so these are deliberately verbose.

(setq backup-directory-alist `((".*" . ,(mjb-var "backup/")))
      make-backup-files t
      ;; Copy rather than rename, so hard links and file modes survive.
      backup-by-copying t
      ;; Keep a numbered history rather than a single ~ file.
      version-control t
      delete-old-versions t
      kept-new-versions 10
      kept-old-versions 5
      ;; Back up files under version control too -- git only helps once you
      ;; have committed, and the risky window is before that.
      vc-make-backup-files t)

(setq auto-save-default t
      auto-save-timeout 20              ; seconds of idle
      auto-save-interval 200            ; keystrokes
      auto-save-list-file-prefix (mjb-var "auto-save/session-")
      auto-save-file-name-transforms `((".*" ,(mjb-var "auto-save/") t)))

;; Also flush to disk when focus leaves Emacs or it goes idle, so a crash or a
;; closed terminal costs seconds rather than an editing session.
;; (`focus-out-hook' was obsoleted in 27.1; this is the replacement.)
(defun mjb-save-on-focus-change ()
  "Save all file buffers when Emacs loses focus."
  (unless (frame-focus-state) (save-some-buffers t)))
(add-function :after after-focus-change-function #'mjb-save-on-focus-change)
(run-with-idle-timer 30 t (lambda () (save-some-buffers t)))

;; Emacs is launched per-file from tmux panes here, so two instances editing
;; one file is a real possibility.  Lock files are what catch that.
(setq create-lockfiles t
      lock-file-name-transforms `((".*" ,(mjb-var "lock/") t)))

;;;; History and place (R-016) -------------------------------------------------
;; The existing var/ state is real: 78 saved positions across four book
;; projects.  Migration must preserve these files, not recreate them.

;; These three are enabled unconditionally, so requiring them here costs
;; nothing we were not already paying and lets the byte-compiler check us.
(require 'recentf)
(require 'savehist)
(require 'saveplace)

(setq recentf-save-file (mjb-var "recentf.el")
      recentf-max-saved-items 200
      recentf-max-menu-items 25
      ;; Do not stat remote files on every save -- that hangs on a dead mount,
      ;; and several entries here live on /nas4.
      recentf-auto-cleanup 'never
      recentf-exclude (list "\\.gpg\\'"
                           (regexp-quote mjb-var-dir)
                           (regexp-quote mjb-etc-dir)))
(recentf-mode 1)

(setq savehist-file (mjb-var "savehist.el")
      savehist-save-minibuffer-history t
      savehist-additional-variables '(kill-ring search-ring regexp-search-ring
                                      compile-history extended-command-history))
(savehist-mode 1)

(setq save-place-file (mjb-var "save-place.el"))
(save-place-mode 1)

;; Everything else is set after its library loads, so nothing is pulled into
;; startup just to relocate a state file.
(with-eval-after-load 'tramp
  (setq tramp-persistency-file-name (mjb-var "tramp/persistency.el")))
(with-eval-after-load 'project
  (setq project-list-file (mjb-var "projects.el")))
(with-eval-after-load 'url
  (setq url-configuration-directory (mjb-var "url/")))
(with-eval-after-load 'eshell
  (setq eshell-directory-name (mjb-var "eshell/")))
(with-eval-after-load 'bookmark
  (setq bookmark-default-file (mjb-var "bookmarks.el")))
(with-eval-after-load 'transient
  (setq transient-history-file (mjb-var "transient/history.el")
        transient-levels-file  (mjb-etc "transient/levels.el")
        transient-values-file  (mjb-etc "transient/values.el")))

;;;; Credentials (R-013) -------------------------------------------------------
;; Emacs reads API keys from an encrypted store, never from the process
;; environment.  This removes Emacs's dependence on the plaintext exports in
;; ~/.bashrc; rotating those keys is a separate action, documented in README.
(eval-when-compile (require 'auth-source))
(declare-function auth-source-search "auth-source")
(setq auth-sources (list (expand-file-name "~/.authinfo.gpg"))
      auth-source-cache-expiry 3600
      ;; Never silently fall back to an unencrypted file.
      auth-source-do-cache t)

(defun mjb-auth-token (host)
  "Return the secret stored in auth-source for HOST, or nil.
Used by mjb-ai.el.  Returns nil rather than erroring so a missing
credential degrades to a clear message instead of a backtrace (R-064)."
  (require 'auth-source)
  (when-let* ((match (car (auth-source-search :host host :max 1)))
              (secret (plist-get match :secret)))
    (if (functionp secret) (funcall secret) secret)))

;;;; Clipboard (R-015) ---------------------------------------------------------
;; The previous config shelled out to xclip, which is not installed on this
;; machine -- so terminal Emacs has had no clipboard at all.  OSC 52 is an
;; escape sequence the terminal itself interprets: it needs no helper binary,
;; works through tmux (which is configured `set-clipboard external' here), and
;; works over SSH, which xclip cannot.

(defcustom mjb-osc52-max-length 100000
  "Longest base64 payload to send via OSC 52.
Terminals cap the length of an OSC 52 sequence; past the cap the paste is
silently truncated, which is worse than not sending it.  100 KB is well
inside every terminal I know of."
  :type 'integer :group 'mjb)

(defun mjb-osc52-copy (text)
  "Place TEXT on the system clipboard using an OSC 52 escape sequence."
  (let ((b64 (base64-encode-string (encode-coding-string text 'utf-8) t)))
    (if (> (length b64) mjb-osc52-max-length)
        (message "mjb: selection too large for OSC 52 (%d bytes); not copied"
                 (length b64))
      (send-string-to-terminal (format "\e]52;c;%s\a" b64)))))

(defvar mjb--gui-cut-function interprogram-cut-function
  "Whatever Emacs installed for us, captured before we take over.
On a GUI build this is `gui-select-text'; on emacs-nox it is nil.")

(defun mjb-interprogram-cut (text)
  "Copy TEXT to the system clipboard, by whichever route this frame supports."
  (if (display-graphic-p)
      (when mjb--gui-cut-function (funcall mjb--gui-cut-function text))
    (mjb-osc52-copy text)))

(setq interprogram-cut-function #'mjb-interprogram-cut)

;; Note: OSC 52 is write-only in practice -- terminals do not let applications
;; read the clipboard.  Pasting INTO terminal Emacs stays the terminal's job
;; (Ctrl-Shift-V, or middle click).  This asymmetry is inherent, not a bug.
(setq select-enable-clipboard t
      select-enable-primary t
      save-interprogram-paste-before-kill t
      mouse-drag-copy-region t)

;;;; Colour depth (R-046) -----------------------------------------------------
;; Measured: COLORTERM=truecolor gives Emacs 16.7M colours on this stack;
;; without it, 256 -- on the same TERM=screen-256color.  Truecolor works today
;; but depends on a variable that is not propagated over SSH or into detached
;; tmux sessions, so make the failure loud rather than a mysteriously flat theme.
(defun mjb-check-color-depth ()
  "Warn if a terminal frame did not negotiate 24-bit colour."
  ;; `noninteractive' guard: in batch there is no terminal and
  ;; `display-color-cells' reports 0, which is not a problem to report.
  (unless (or noninteractive (display-graphic-p))
    (when (< (display-color-cells) 16777216)
      (message "mjb: terminal has %d colours, not 24-bit. \
Export COLORTERM=truecolor (theme will look flat until you do)."
               (display-color-cells)))))
(add-hook 'emacs-startup-hook #'mjb-check-color-depth)
;; Help future tty frames (emacsclient -t) negotiate correctly.
(unless (getenv "COLORTERM") (setenv "COLORTERM" "truecolor"))

;;;; Editing defaults ----------------------------------------------------------

(setq-default indent-tabs-mode nil
              tab-width 4
              fill-column 80)

(setq sentence-end-double-space nil     ; matters for M-e / fill in prose
      require-final-newline t
      ;; Scrolling that does not jump.
      scroll-margin 3
      scroll-conservatively 101
      scroll-preserve-screen-position t
      auto-window-vscroll nil
      mouse-wheel-progressive-speed nil
      ;; Answer y/n rather than yes/no.
      use-short-answers t
      ;; Do not ring the bell, and do not flash either.
      ring-bell-function #'ignore
      visible-bell nil
      ;; Follow symlinks into version control without asking.
      vc-follow-symlinks t
      ;; Keep *Messages* useful.
      message-log-max 5000)

;; UTF-8 everywhere.
(set-language-environment "UTF-8")
(setq default-input-method nil)         ; set-language-environment sets this

;; Reload files changed on disk (you edit these from other tools too).
(setq global-auto-revert-non-file-buffers t
      auto-revert-verbose nil)
(global-auto-revert-mode 1)

;; Exactly one delimiter-pairing mechanism (R-020).  `smartparens' is removed;
;; electric-pair is built in and does not fight anyone.
(electric-pair-mode 1)
(show-paren-mode 1)
(setq show-paren-delay 0
      show-paren-context-when-offscreen 'overlay)

;; Built-in undo/redo (R-023).  `undo-tree' wrote history files and stalls on
;; large buffers, which a 3000-line main.tex is.
(setq undo-limit (* 16 1024 1024)
      undo-strong-limit (* 24 1024 1024)
      undo-outer-limit (* 128 1024 1024))

;; Long lines must not hang the editor (R-024).
(global-so-long-mode 1)

;; Useful built-ins that cost nothing.
(delete-selection-mode 1)               ; typing replaces the region
(column-number-mode 1)
(repeat-mode 1)                         ; replaces `hydra' for repeat maps
(winner-mode 1)                         ; undo window layout changes
(minibuffer-depth-indicate-mode 1)
(setq enable-recursive-minibuffers t
      echo-keystrokes 0.02
      ;; Do not let the minibuffer prompt be clobbered by point.
      minibuffer-prompt-properties
      '(read-only t cursor-intangible t face minibuffer-prompt))
(add-hook 'minibuffer-setup-hook #'cursor-intangible-mode)

;; Treat a narrowed buffer as normal; disabled by default for historical reasons.
(put 'narrow-to-region 'disabled nil)
(put 'upcase-region    'disabled nil)
(put 'downcase-region  'disabled nil)

;;;; Steady-state GC -----------------------------------------------------------
;; early-init.el raised the threshold to effectively infinite for startup.
;; Hand back to a value that is large enough to avoid collecting mid-keystroke
;; but small enough that a collection is not perceptible.
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 32 1024 1024)
                  gc-cons-percentage 0.1))
          80)

(defun mjb-recompile (&optional force)
  "Byte- and native-compile every module in lisp/.
With FORCE, recompile even files whose .elc is current.  `load-prefer-newer'
means you do not strictly need this after an edit -- Emacs will load your .el
-- but compiling keeps startup at its measured cost."
  (interactive "P")
  (byte-recompile-directory (expand-file-name "lisp" user-emacs-directory)
                            0 force)
  (message "mjb: modules recompiled"))

(provide 'mjb-core)
;;; mjb-core.el ends here
