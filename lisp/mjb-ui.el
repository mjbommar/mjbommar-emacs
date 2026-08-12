;;; mjb-ui.el --- Theme, modeline, tabs, fonts -*- lexical-binding: t -*-

;;; Commentary:
;; Everything you look at.  Zero packages: the theme, the tab bar, and the
;; modeline are all built into Emacs 30.
;;
;;   theme     modus-operandi / modus-vivendi   built-in, WCAG-AAA contrast
;;   tabs      tab-bar-mode                     built-in (D-2: workspaces)
;;   modeline  hand-written mode-line-format    ~40 lines vs doom-modeline's 4761
;;   fonts     Berkeley Mono, GUI-guarded       R-047
;;
;; Requirement refs: R-022, R-040, R-042, R-043, R-045, R-047.

;;; Code:

(require 'mjb-core)
(require 'display-line-numbers)
(require 'which-key)

;; `project' and `flymake' are loaded lazily; declare what we touch so the
;; byte-compiler can check us without dragging them into startup.
(defvar flymake-mode-line-counters)
(defvar project-prompter)
(declare-function project-current "project" (&optional maybe-prompt directory))
(declare-function project-root "project" (project))
(declare-function project-switch-project "project" (dir))

(defgroup mjb-ui nil "Appearance." :group 'faces)

;;;; Theme (R-043) --------------------------------------------------------------
;; The Modus themes ship with Emacs.  They are built to a measured contrast
;; ratio rather than to a mood, which is what makes them hold up in a 24-bit
;; terminal AND on a GUI frame from one configuration -- the actual requirement.
;; No package needed; `ef-themes' was on the shortlist and is not required.

(defcustom mjb-dark-theme 'modus-vivendi
  "Theme used for dark mode." :type 'symbol :group 'mjb-ui)

(defcustom mjb-light-theme 'modus-operandi
  "Theme used for light mode." :type 'symbol :group 'mjb-ui)

(defun mjb-load-theme (theme)
  "Load THEME, first disabling any theme already active.
Stacking themes is the usual cause of unreadable half-applied colours."
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme theme t))

(defun mjb-toggle-theme ()
  "Switch between the light and dark themes."
  (interactive)
  (mjb-load-theme (if (memq mjb-dark-theme custom-enabled-themes)
                      mjb-light-theme
                    mjb-dark-theme)))

;; Ghostty is configured `light:Catppuccin Latte,dark:Catppuccin Mocha', i.e. it
;; follows the system appearance.  Emacs has no portable way to read that, so we
;; default to dark and leave the toggle on a key (R-043 keeps auto-following P2).
(mjb-load-theme mjb-dark-theme)

;;;; Fonts (R-047) --------------------------------------------------------------
;; Only meaningful on a graphical frame.  In the terminal the font is Ghostty's
;; (Berkeley Mono 11) and Emacs cannot influence it -- the previous config set
;; "JetBrains Mono", which is not installed on this machine, inside a build that
;; could not render fonts at all.

(defcustom mjb-font-family "Berkeley Mono"
  "Monospace family for graphical frames.
Berkeley Mono is what Ghostty uses, so GUI and terminal Emacs match."
  :type 'string :group 'mjb-ui)

(defcustom mjb-variable-font-family "Noto Sans"
  "Proportional family, used by `variable-pitch-mode' in prose buffers."
  :type 'string :group 'mjb-ui)

(defcustom mjb-font-height 120
  "Font height in 1/10 pt for graphical frames." :type 'integer :group 'mjb-ui)

(defun mjb-setup-fonts (&optional frame)
  "Apply fonts to FRAME if it is graphical and the families exist."
  (when (display-graphic-p frame)
    (let ((families (font-family-list frame)))
      (when (member mjb-font-family families)
        (set-face-attribute 'default frame
                            :family mjb-font-family :height mjb-font-height)
        (set-face-attribute 'fixed-pitch frame
                            :family mjb-font-family :height mjb-font-height))
      (when (member mjb-variable-font-family families)
        (set-face-attribute 'variable-pitch frame
                            :family mjb-variable-font-family
                            :height mjb-font-height)))))

;; Run for the initial frame and for every frame created later (emacsclient).
(add-hook 'after-make-frame-functions #'mjb-setup-fonts)
(add-hook 'emacs-startup-hook #'mjb-setup-fonts)

;;;; Line numbers (R-022) -------------------------------------------------------
;; Absolute, not relative: relative numbering pays off with counted vi-style
;; motions, which this configuration does not have.  `goto-line' -- which is in
;; your command history -- wants absolute numbers.

(setq display-line-numbers-type t
      display-line-numbers-width-start t
      display-line-numbers-grow-only t)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'conf-mode-hook #'display-line-numbers-mode)
;; Deliberately NOT in text-mode: line numbers are noise in prose and cost
;; redisplay on wrapped lines, which every .tex buffer here has.

;;;; Tab bar -- workspaces (R-045, D-2) ----------------------------------------
;; One tab per project, each holding its own window configuration.  Built in,
;; so this replaces centaur-tabs (2569 lines, graphical styling, and the cause
;; of the C-c t collision F-03) at zero cost.

(setq tab-bar-show 1                    ; hide the bar until there are 2+ tabs
      tab-bar-close-button-show nil     ; nothing to click in a terminal
      tab-bar-tab-hints t               ; number the tabs, so C-x t 2 is aimable
      tab-bar-new-tab-choice "*scratch*"
      tab-bar-select-tab-modifiers nil  ; do NOT steal M-1..M-9 (see R-034)
      tab-bar-format '(tab-bar-format-tabs tab-bar-separator))

(defun mjb-tab-name-from-project ()
  "Name the current tab after its project, falling back to the buffer name.
Called when a tab is created or renamed, not on redisplay, so the
filesystem walk here is fine."
  (or (ignore-errors
        (require 'project)
        (when-let ((proj (project-current nil)))
          (file-name-nondirectory (directory-file-name (project-root proj)))))
      (buffer-name)))

(setq tab-bar-tab-name-function #'mjb-tab-name-from-project)

(tab-bar-mode 1)
(tab-bar-history-mode 1)                ; window-layout back/forward per tab

(defun mjb-tab-for-project ()
  "Switch to a project in its own tab, reusing the tab if it exists (R-045f)."
  (interactive)
  (require 'project)
  (let* ((dir (funcall project-prompter))
         (name (file-name-nondirectory (directory-file-name dir))))
    (if (member name (mapcar (lambda (tab) (alist-get 'name tab))
                             (tab-bar-tabs)))
        (tab-bar-switch-to-tab name)
      (tab-bar-new-tab)
      (tab-bar-rename-tab name)
      (project-switch-project dir))))

;;;; Modeline (R-042) -----------------------------------------------------------
;; Replaces doom-modeline: 4761 lines and 64 ms of startup, configured with 35
;; variables of which six referred to packages that were not installed.
;;
;; Emacs 30 provides `mode-line-format-right-align', so the right-hand segments
;; need no width arithmetic.

(defface mjb-modeline-modified '((t :inherit error :weight bold))
  "Face for the modified indicator." :group 'mjb-ui)

(defface mjb-modeline-project '((t :inherit font-lock-keyword-face))
  "Face for the project name." :group 'mjb-ui)

(defun mjb-modeline-buffer-state ()
  "Compact buffer state: modified, read-only, or clean."
  (cond (buffer-read-only  (propertize " RO " 'face 'mjb-modeline-project))
        ((buffer-modified-p) (propertize " ● " 'face 'mjb-modeline-modified))
        (t "   ")))

(defvar-local mjb--modeline-project 'unset
  "Cached project segment for this buffer.
`project-current' walks the filesystem, so calling it on every redisplay --
which is what a naive modeline segment does -- is a real cost on a machine
with projects on /nas4.  Compute once per buffer instead.")

(defun mjb-modeline-project ()
  "Project name, or empty when the buffer is not in a project.
Cached per buffer; call `mjb-modeline-refresh-project' if it goes stale."
  (when (eq mjb--modeline-project 'unset)
    (setq mjb--modeline-project
          (or (ignore-errors
                (require 'project)
                (when-let ((proj (project-current nil)))
                  (propertize
                   (concat (file-name-nondirectory
                            (directory-file-name (project-root proj))) "/")
                   'face 'mjb-modeline-project)))
              "")))
  mjb--modeline-project)

(defun mjb-modeline-refresh-project ()
  "Forget this buffer's cached project name."
  (interactive)
  (setq mjb--modeline-project 'unset))

(defun mjb-modeline-vc ()
  "Branch name, without the backend prefix Emacs puts in `vc-mode'."
  (if (and vc-mode buffer-file-name)
      ;; vc-mode looks like " Git-main"; keep the branch only.
      (concat " " (replace-regexp-in-string "\\` *[A-Za-z]+[:-]" "" vc-mode))
    ""))

(defun mjb-modeline-flymake ()
  "Diagnostic counts, only when flymake is actually running."
  (if (bound-and-true-p flymake-mode)
      (concat " " (format-mode-line flymake-mode-line-counters))
    ""))

(setq-default
 mode-line-format
 '("%e"
   (:eval (mjb-modeline-buffer-state))
   (:eval (mjb-modeline-project))
   mode-line-buffer-identification
   "  "
   (:eval (propertize "%l:%C" 'face 'shadow))
   mode-line-format-right-align
   (:eval (mjb-modeline-flymake))
   (:eval (mjb-modeline-vc))
   "  "
   mode-line-modes
   " "))

;; `mode-line-modes' includes the minor-mode list, which is noise once you have
;; ten of them on.  Keep the major mode, drop the rest -- this is what the
;; `diminish' package (and 30 `:diminish' keywords) existed to achieve.
(setq mode-line-modes
      '((:eval (propertize (format-mode-line mode-name) 'face 'bold))))

;;;; Miscellaneous chrome -------------------------------------------------------

(setq-default cursor-in-non-selected-windows nil)
(setq highlight-nonselected-windows nil
      x-stretch-cursor nil
      ;; Do not resize the minibuffer for one long line.
      resize-mini-windows 'grow-only
      ;; Frame title: useful in a GUI, harmless in a terminal.
      frame-title-format '("%b — Emacs"))

;; Built-in which-key (Emacs 30) -- the MELPA package is redundant now.
(setq which-key-idle-delay 0.5
      which-key-idle-secondary-delay 0.05
      which-key-add-column-padding 1)
(which-key-mode 1)

;; Highlight the current line in code, but not in prose where it fights reading.
(add-hook 'prog-mode-hook #'hl-line-mode)

;; Show trailing whitespace where it matters and nowhere else.
(add-hook 'prog-mode-hook
          (lambda () (setq-local show-trailing-whitespace t)))

(provide 'mjb-ui)
;;; mjb-ui.el ends here
