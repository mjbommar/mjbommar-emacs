;;; init.el --- Minimal Emacs configuration -*- lexical-binding: t -*-

;;; Commentary:
;; A minimal, aesthetic Emacs configuration focused on Python, Rust, and AI integration

;;; Code:

;; Performance optimization
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 2 1024 1024)
                  gc-cons-percentage 0.1)))

;; Package management setup
(require 'package)
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("elpa" . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")))

(package-initialize)

;; Bootstrap use-package
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t
      use-package-always-defer t
      use-package-enable-imenu-support t)

;; Keep directories clean
(use-package no-littering
  :demand t
  :config
  (setq custom-file (no-littering-expand-etc-file-name "custom.el"))
  (when (file-exists-p custom-file)
    (load custom-file)))

;; Basic settings
(setq-default
 indent-tabs-mode nil
 tab-width 4
 fill-column 80
 truncate-lines t
 create-lockfiles nil
 make-backup-files nil
 auto-save-default nil
 ring-bell-function 'ignore
 visible-bell nil
 scroll-margin 3
 scroll-conservatively 101
 select-enable-clipboard t
 mouse-wheel-progressive-speed nil
 display-line-numbers-type 'relative )

;; Enable useful modes
(global-display-line-numbers-mode 1)
(column-number-mode 1)
(global-auto-revert-mode 1)
(electric-pair-mode 1)
(show-paren-mode 1)
(save-place-mode 1)
(recentf-mode 1)

;; Disable line numbers in specific modes
(dolist (mode '(term-mode-hook
                vterm-mode-hook
                eshell-mode-hook
                help-mode-hook
                treemacs-mode-hook))
  (add-hook mode (lambda () (display-line-numbers-mode 0))))

;;; UI and Aesthetics

;; Font configuration
(defvar my/default-font "JetBrains Mono")
(defvar my/variable-font "Noto Sans")
(defvar my/font-size 120)

(set-face-attribute 'default nil
                    :family my/default-font
                    :height my/font-size
                    :weight 'regular)
(set-face-attribute 'fixed-pitch nil
                    :family my/default-font
                    :height my/font-size)
(set-face-attribute 'variable-pitch nil
                    :family my/variable-font
                    :height my/font-size)

;; Theme - Doom One (dark/light)
(use-package doom-themes
  :demand t
  :config
  ;; Global settings
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t)
  
  ;; Load doom-one dark theme by default
  (load-theme 'doom-one t)
  
  ;; Enable flashing mode-line on errors
  (doom-themes-visual-bell-config)
  ;; Better org-mode fontification
  (doom-themes-org-config))

;; Optional: Theme toggle function
(defun my/toggle-theme ()
  "Toggle between doom-one and doom-one-light."
  (interactive)
  (if (eq (car custom-enabled-themes) 'doom-one)
      (load-theme 'doom-one-light t)
    (load-theme 'doom-one t)))

(global-set-key (kbd "C-c T") 'my/toggle-theme)  ; Changed to uppercase T to avoid conflict

;; Clean modeline helpers
(use-package diminish
  :ensure t
  :demand t)

;; Doom Modeline - Beautiful, rich modeline
(use-package doom-modeline
  :ensure t
  :demand t
  :hook (after-init . doom-modeline-mode)
  :config
  (setq doom-modeline-height 25                      ; Modeline height
        doom-modeline-bar-width 4                    ; Left bar width
        doom-modeline-icon t                          ; Display icons
        doom-modeline-major-mode-icon t              ; Display major mode icon
        doom-modeline-major-mode-color-icon t        ; Colorize the icon
        doom-modeline-buffer-file-name-style 'truncate-upto-project
        doom-modeline-buffer-state-icon t            ; Display buffer state icon
        doom-modeline-buffer-modification-icon t     ; Display modification icon
        doom-modeline-unicode-fallback t             ; Use unicode as fallback
        doom-modeline-minor-modes nil                ; Hide minor modes
        doom-modeline-enable-word-count nil          ; Don't count words
        doom-modeline-continuous-word-count-modes '(markdown-mode gfm-mode org-mode)
        doom-modeline-buffer-encoding nil            ; Hide encoding unless non-standard
        doom-modeline-indent-info nil                ; Don't show indent info
        doom-modeline-checker-simple-format t        ; Simple format for checkers
        doom-modeline-number-limit 99                ; Max number display
        doom-modeline-vcs-max-length 12              ; Branch name length
        doom-modeline-workspace-name t               ; Display workspace name
        doom-modeline-persp-name t                   ; Display perspective name
        doom-modeline-display-default-persp-name nil ; Hide default perspective
        doom-modeline-persp-icon t                   ; Display perspective icon
        doom-modeline-lsp t                          ; Display LSP status
        doom-modeline-github nil                     ; Don't show github notifications
        doom-modeline-env-version t                  ; Display environment version
        doom-modeline-env-python-executable "python" ; Python executable
        doom-modeline-env-rust-executable "rustc"    ; Rust executable
        doom-modeline-modal t                        ; Display modal state
        doom-modeline-modal-icon t                   ; Display modal icon
        doom-modeline-mu4e nil                       ; Hide mu4e status
        doom-modeline-gnus nil                       ; Hide gnus status
        doom-modeline-irc nil                        ; Hide IRC status
        doom-modeline-time nil                       ; Don't show time
        doom-modeline-env-enable-python t            ; Show Python version
        doom-modeline-env-enable-rust t))            ; Show Rust version

;; Support packages for doom-modeline
(use-package all-the-icons
  :if (display-graphic-p))

;; Nerd icons (alternative/additional icon set)
(use-package nerd-icons
  :ensure t
  :if (display-graphic-p))

;; Dashboard - startup screen
(use-package dashboard
  :demand t
  :config
  (setq dashboard-banner-logo-title "Welcome to Emacs!"
        dashboard-startup-banner 'logo
        dashboard-center-content t
        dashboard-show-shortcuts t
        dashboard-items '((recents  . 10)
                          (projects . 5)
                          (bookmarks . 5))
        dashboard-set-heading-icons t
        dashboard-set-file-icons t
        dashboard-projects-backend 'project-el
        dashboard-week-agenda nil)
  (dashboard-setup-startup-hook))

;; Centaur Tabs - Modern tab bar for Emacs
(use-package centaur-tabs
  :ensure t
  :demand t
  :init
  (setq centaur-tabs-enable-key-bindings nil)  ; Prevent key conflicts early
  :hook
  (after-init . centaur-tabs-mode)
  :bind
  ;; Terminal-friendly keybindings (removed M-[ and M-] as they break escape sequences)
  ("C-c t p" . centaur-tabs-backward)       ; Previous tab
  ("C-c t n" . centaur-tabs-forward)        ; Next tab
  ("C-c t <" . centaur-tabs-move-current-tab-to-left)
  ("C-c t >" . centaur-tabs-move-current-tab-to-right)
  ("C-c t s" . centaur-tabs-switch-group)   ; Switch group
  ("C-c t g" . centaur-tabs-counsel-switch-group) ; Go to group
  ("C-c t k" . centaur-tabs-kill-current-buffer) ; Kill current tab
  ("C-c t o" . centaur-tabs-kill-other-buffers-in-current-group) ; Kill other tabs
  ("C-c t t" . (lambda () (interactive) (switch-to-buffer (generate-new-buffer "*new*")))) ; New empty tab
  :config
  (setq centaur-tabs-style "rounded"          ; Tab style: alternate, bar, box, chamfer, rounded, slant, wave, zigzag
        centaur-tabs-height 32                ; Tab height
        centaur-tabs-set-icons t               ; Use icons in tabs
        centaur-tabs-icon-type 'nerd-icons    ; Icon type: all-the-icons or nerd-icons
        centaur-tabs-set-bar 'under           ; Tab bar location: under, over, left, or nil
        centaur-tabs-set-close-button nil     ; Don't show close button
        centaur-tabs-set-modified-marker t    ; Show modified marker
        centaur-tabs-modified-marker "●"      ; Modified marker symbol
        centaur-tabs-show-navigation-buttons t ; Show < > navigation buttons
        centaur-tabs-down-tab-text " ☰ "      ; Text for down tab
        centaur-tabs-backward-tab-text " < "  ; Navigation button text
        centaur-tabs-forward-tab-text " > "   ; Navigation button text
        centaur-tabs-buffer-show-groups t     ; Show buffer groups
        centaur-tabs-show-count nil           ; Don't show buffer count
        centaur-tabs-label-fixed-length 0     ; Dynamic tab width
        centaur-tabs-gray-out-icons 'buffer   ; Gray out icons for unselected buffers
        centaur-tabs-plain-icons nil          ; Use colored icons
        centaur-tabs-cycle-scope 'tabs)       ; Cycle through tabs only
  
  ;; Group buffers by project
  (centaur-tabs-group-by-projectile-project)
  
  ;; Enable new tabs for new buffers
  (setq centaur-tabs-show-new-tab-button t)
  
  ;; Simple tab hiding - only hide truly internal buffers
  (defun centaur-tabs-hide-tab (x)
    "Return t if buffer X should be hidden from tabs."
    (let ((name (format "%s" x)))
      (or
       ;; Current window is dedicated
       (window-dedicated-p (selected-window))
       ;; Buffer name starts with space
       (string-prefix-p " " name))))
  
  ;; Enable centaur-tabs in terminal
  (centaur-tabs-headline-match)
  
  ;; Keep tabs sorted
  (setq centaur-tabs-adjust-buffer-order t)
  
  ;; After centaur-tabs loads, unbind problematic keys
  (with-eval-after-load 'centaur-tabs
    (when (boundp 'centaur-tabs-mode-map)
      (define-key centaur-tabs-mode-map (kbd "<prior>") nil)
      (define-key centaur-tabs-mode-map (kbd "<next>") nil)
      (define-key centaur-tabs-mode-map (kbd "C-<prior>") nil)
      (define-key centaur-tabs-mode-map (kbd "C-<next>") nil)))
  
  ;; Ensure centaur-tabs is enabled
  (centaur-tabs-mode 1))

;; Better help
(use-package helpful
  :ensure t
  :bind
  ([remap describe-function] . helpful-callable)
  ([remap describe-variable] . helpful-variable)
  ([remap describe-key] . helpful-key)
  ([remap describe-command] . helpful-command))

;;; Completion System

;; Vertical completion UI
(use-package vertico
  :demand t
  :config
  (vertico-mode 1)
  (setq vertico-cycle t
        vertico-resize nil))

;; Orderless completion style
(use-package orderless
  :demand t
  :config
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles basic partial-completion)))))

;; Rich annotations in minibuffer
(use-package marginalia
  :demand t
  :config
  (marginalia-mode 1))

;; Consult for enhanced commands
(use-package consult
  :ensure t
  :bind (("C-x b" . consult-buffer)
         ("C-x 4 b" . consult-buffer-other-window)
         ("C-M-y" . consult-yank-pop)  ; Changed to C-M-y to avoid conflict with Minuet
         ("M-g g" . consult-goto-line)
         ("M-g M-g" . consult-goto-line)
         ("M-s l" . consult-line)
         ("M-s L" . consult-line-multi)
         ("M-s r" . consult-ripgrep)
         ("M-s f" . consult-find)))

;; Corfu - In-buffer completion popup
(use-package corfu
  :ensure t
  :custom
  ;; Enable auto completion
  (corfu-auto t)
  (corfu-auto-delay 0.2)
  (corfu-auto-prefix 2)
  
  ;; Configure behavior
  (corfu-cycle t)                  ; Enable cycling for `corfu-next/previous'
  (corfu-quit-no-match 'separator) ; Quit at boundary if no match
  (corfu-quit-at-boundary t)       ; Quit at completion boundary
  (corfu-preview-current 'insert)  ; Preview current candidate
  (corfu-preselect 'prompt)        ; Preselect the prompt
  (corfu-on-exact-match nil)       ; Configure handling of exact matches
  (corfu-scroll-margin 5)          ; Use scroll margin
  
  ;; Enable Corfu in the minibuffer
  :hook ((minibuffer-setup . corfu-enable-in-minibuffer))
  
  :bind
  ;; Configure bindings in corfu-map
  (:map corfu-map
        ("TAB" . corfu-next)
        ([tab] . corfu-next)
        ("S-TAB" . corfu-previous)
        ([backtab] . corfu-previous)
        ("RET" . corfu-insert)
        ("C-j" . corfu-next)
        ("C-k" . corfu-previous))
  
  :init
  (global-corfu-mode)
  
  :config
  ;; Enable Corfu in minibuffer
  (defun corfu-enable-in-minibuffer ()
    "Enable Corfu in the minibuffer if vertico is not active."
    (when (not (bound-and-true-p vertico--input))
      (setq-local corfu-auto nil) ; No auto completion in minibuffer
      (corfu-mode 1))))

;; Corfu extensions (included in main package)
(use-package corfu-popupinfo
  :ensure nil
  :after corfu
  :hook (corfu-mode . corfu-popupinfo-mode)
  :custom
  (corfu-popupinfo-delay '(0.5 . 0.0))
  (corfu-popupinfo-max-height 10))

(use-package corfu-history
  :ensure nil
  :after corfu
  :hook (corfu-mode . corfu-history-mode))

(use-package corfu-quick
  :ensure nil
  :after corfu
  :bind (:map corfu-map
              ("M-q" . corfu-quick-complete)
              ("C-q" . corfu-quick-insert)))

;; Kind-icon - Beautiful icons in Corfu
(use-package kind-icon
  :ensure t
  :after corfu
  :custom
  (kind-icon-default-face 'corfu-default)
  (kind-icon-blend-background nil)
  (kind-icon-blend-frac 0.08)
  :config
  (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))

;; Cape - Completion At Point Extensions
(use-package cape
  :ensure t
  :bind (("C-c p p" . completion-at-point) ; capf
         ("C-c p d" . cape-dabbrev)        ; dabbrev
         ("C-c p h" . cape-history)        ; history
         ("C-c p f" . cape-file)           ; file path
         ("C-c p k" . cape-keyword)        ; keyword
         ("C-c p s" . cape-elisp-symbol)   ; elisp symbol
         ("C-c p a" . cape-abbrev)         ; abbreviation
         ("C-c p l" . cape-line)           ; entire line
         ("C-c p w" . cape-dict))          ; dictionary word
  :init
  ;; Add useful cape backends
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-keyword)
  ;; For Elisp
  (add-hook 'emacs-lisp-mode-hook
            (lambda ()
              (add-to-list 'completion-at-point-functions #'cape-elisp-symbol))))

;;; Version Control

(use-package magit
  :ensure t
  :bind ("C-x g" . magit-status)
  :config
  (setq magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

;; Show git changes in fringe
(use-package diff-hl
  :hook ((prog-mode . diff-hl-mode)
         (magit-pre-refresh . diff-hl-magit-pre-refresh)
         (magit-post-refresh . diff-hl-magit-post-refresh))
  :config
  (diff-hl-flydiff-mode))

;;; Programming - General

;; LSP support via Eglot (built-in for Emacs 29+)
(use-package eglot
  :ensure nil
  :hook ((python-mode . eglot-ensure)
         (rust-mode . eglot-ensure)
         (js-mode . eglot-ensure)
         (typescript-mode . eglot-ensure)
         (json-mode . eglot-ensure)
         (yaml-mode . eglot-ensure))
  :bind (:map eglot-mode-map
              ("C-c d" . xref-find-definitions)        ; Jump to definition
              ("C-c D" . xref-find-definitions-other-window)
              ("C-c r" . xref-find-references)         ; Find references
              ("C-c i" . eglot-find-implementation)    ; Find implementation
              ("C-c t" . eglot-find-typeDefinition)    ; Find type definition
              ("C-c n" . eglot-rename)                 ; Rename symbol
              ("C-c a" . eglot-code-actions)           ; Code actions
              ("C-c f" . eglot-format)                 ; Format buffer
              ("C-c h" . eldoc-doc-buffer))            ; Show documentation
  :config
  (setq eglot-autoshutdown t
        eglot-sync-connect 0
        eglot-events-buffer-size 0)
  ;; Add LSP servers for various modes
  (add-to-list 'eglot-server-programs
               '(markdown-mode . ("marksman"))))

;; Tree-sitter for better syntax highlighting (Emacs 29+)
(when (fboundp 'treesit-available-p)
  (use-package treesit-auto
    :config
    (setq treesit-auto-install 'prompt)
    (global-treesit-auto-mode)))

;; Project management
(use-package project
  :ensure nil
  :bind-keymap ("C-c p" . project-prefix-map))

;; Smart jump - jump to definition intelligently
(use-package smart-jump
  :config
  (smart-jump-setup-default-registers)
  :bind (("M-." . smart-jump-go)
         ("M-," . smart-jump-back)
         ("M-?" . smart-jump-references)))

;;; Python Development

(use-package python
  :ensure nil
  :config
  (setq python-indent-offset 4
        python-shell-interpreter "python3"))

;; Python environment management
(use-package pyvenv
  :hook (python-mode . pyvenv-mode)
  :config
  (setq pyvenv-mode-line-indicator '(pyvenv-virtual-env-name ("[venv:" pyvenv-virtual-env-name "] "))))

;; Python formatting
(use-package python-black
  :after python
  :hook (python-mode . python-black-on-save-mode-enable-dwim))

;; Alternative: Ruff for Python (faster than black)
(use-package reformatter
  :config
  (reformatter-define ruff-format
    :program "ruff"
    :args '("format" "-")
    :lighter " RuffFmt"))

;;; Rust Development

(use-package rust-mode
  :mode "\\.rs\\'"
  :config
  (setq rust-format-on-save t
        rust-indent-offset 4))

(use-package cargo
  :hook (rust-mode . cargo-minor-mode))

;; Rust error checking
(use-package flycheck-rust
  :after (rust-mode flycheck)
  :hook (flycheck-mode . flycheck-rust-setup))

;;; AI Integration - GPTel

;; GPTel - Interact with ChatGPT and other LLMs
(use-package gptel
  :config
  ;; Default to Claude Opus 4.1
  (setq gptel-model 'claude-opus-4-1-20250805
        gptel-default-mode 'org-mode  ; Use org-mode for chat buffers
        
        ;; API key configuration for Claude
        gptel-api-key (or (getenv "ANTHROPIC_API_KEY")
                          #'gptel-api-key-from-auth-source)
        
        ;; Set Claude as default backend
        gptel-backend (gptel-make-anthropic "Claude"
                        :key 'gptel-api-key
                        :stream t))
  
  ;; Optional: Configure additional backends
  ;; For OpenAI (set OPENAI_API_KEY in ~/.bashrc):
  ;; (gptel-make-openai "OpenAI"
  ;;   :key (or (getenv "OPENAI_API_KEY")
  ;;            #'gptel-api-key-from-auth-source)
  ;;   :stream t)
  
  ;; For local models via Ollama (no API key needed):
  ;; (gptel-make-ollama "Ollama"
  ;;   :host "localhost:11434"
  ;;   :models '("mistral" "llama2" "codellama")
  ;;   :stream t)
  
  :bind (("C-c RET" . gptel-send)
         ("C-c C-<return>" . gptel-menu)
         ("C-c g" . gptel))  ; Start a new chat
  
  :hook
  ;; Automatically set up gptel in programming modes
  ((prog-mode . (lambda () 
                  (setq-local gptel-prompt-prefix-alist
                              '((markdown-mode . "## ")
                                (org-mode . "** ")
                                (text-mode . "")))))))

;; AI Code Completion with Minuet (Copilot-style inline completion)
(use-package minuet
  :ensure t  ; Ensure it's installed from MELPA
  :demand t  ; Load immediately, don't defer
  :bind
  (("M-y" . minuet-complete-with-minibuffer) ; minibuffer completion
   ("M-i" . minuet-show-suggestion)          ; overlay ghost text
   ("C-c M" . minuet-configure-provider)     ; configure provider
   :map minuet-active-mode-map
   ;; Active when suggestion is shown
   ("M-p" . minuet-previous-suggestion)
   ("M-n" . minuet-next-suggestion)
   ("M-A" . minuet-accept-suggestion)
   ("M-a" . minuet-accept-suggestion-line)
   ("M-e" . minuet-dismiss-suggestion))
  
  :config
  ;; Set provider to Claude
  (setq minuet-provider 'claude)
  
  ;; Update the model to Opus 4.1
  (plist-put minuet-claude-options :model "claude-sonnet-4-20250514")
  
  ;; The API key should already be set to "ANTHROPIC_API_KEY" by default
  ;; But let's make sure:
  (plist-put minuet-claude-options :api-key "ANTHROPIC_API_KEY")
  
  ;; Enable auto-suggestion in programming modes
  (add-hook 'prog-mode-hook #'minuet-auto-suggestion-mode)
  
  ;; Method 2: Direct key (less secure - don't commit this!)
  ;; (plist-put minuet-claude-options :api-key (lambda () "sk-ant-YOUR-KEY-HERE"))
  
  ;; Method 3: Set environment variable in Emacs (add your key)
  ;; (setenv "ANTHROPIC_API_KEY" "sk-ant-YOUR-KEY-HERE")
  
  ;; Alternative provider configurations (uncomment to use):
  
  ;; OpenAI GPT models
  ;; (setq minuet-provider 'openai)
  (plist-put minuet-openai-options :model "gpt-4.1-mini")
  (plist-put minuet-openai-options :api-key "OPENAI_API_KEY")
  
  ;; Gemini (Google) - Fast and has free tier
  ;; (setq minuet-provider 'gemini)
  ;; (plist-put minuet-gemini-options :api-key "GEMINI_API_KEY")
  
  ;; DeepSeek - Excellent for code, very affordable
  ;; (setq minuet-provider 'openai-fim-compatible)
  ;; Already configured as default for openai-fim-compatible
  
  ;; Ollama (Local) - Privacy-focused, no API key needed
  ;; (setq minuet-provider 'openai-fim-compatible)
  ;; (plist-put minuet-openai-fim-compatible-options 
  ;;            :end-point "http://localhost:11434/v1/completions")
  ;; (plist-put minuet-openai-fim-compatible-options :api-key "TERM")
  ;; (plist-put minuet-openai-fim-compatible-options :model "qwen2.5-coder:3b")
  
  ;; Set completion parameters
  (setq minuet-n-completions 2)  ; Number of suggestions
  (setq minuet-context-window 4000)  ; Context size (roughly 1000 tokens)
  (setq minuet-request-timeout 2.5)  ; Timeout in seconds
  
  ;; Auto-suggestion delays
  (setq minuet-auto-suggestion-debounce-delay 0.5)
  (setq minuet-auto-suggestion-throttle-delay 1.2)
  
  ;; Optional: Configure token limits
  (minuet-set-optional-options minuet-openai-options :max_tokens 128)
  (minuet-set-optional-options minuet-openai-options :top_p 0.95))

;;; Shell and Terminal

;; Enhanced terminal emulator
(use-package vterm
  :ensure t
  :commands vterm
  :config
  (setq vterm-max-scrollback 10000
        vterm-shell (executable-find "bash")))

;; Better eshell
(use-package eshell
  :ensure nil
  :config
  (setq eshell-scroll-to-bottom-on-input 'all
        eshell-error-if-no-glob t
        eshell-hist-ignoredups t
        eshell-save-history-on-exit t))

;; Eshell enhancements
(use-package eshell-syntax-highlighting
  :after eshell
  :config
  (eshell-syntax-highlighting-global-mode 1))

;;; File Management

(use-package dired
  :ensure nil
  :config
  (setq dired-listing-switches "-alh --group-directories-first"
        dired-dwim-target t
        dired-kill-when-opening-new-dired-buffer t))

;; Additional dired functionality
(use-package dired-x
  :ensure nil
  :after dired)

;; Treemacs - file tree sidebar
(use-package treemacs
  :ensure t
  :defer t
  :bind
  (:map global-map
        ("M-0"       . treemacs-select-window)
        ("C-x t 1"   . treemacs-delete-other-windows)
        ("C-x t t"   . treemacs)
        ("C-x t d"   . treemacs-select-directory)
        ("C-x t B"   . treemacs-bookmark)
        ("C-x t C-t" . treemacs-find-file)
        ("C-x t M-t" . treemacs-find-tag))
  :config
  (setq treemacs-width 30
        treemacs-is-never-other-window t))

(use-package treemacs-projectile
  :ensure t
  :after (treemacs projectile))

;;; Quality of Life

;; Which-key for discovering keybindings
(use-package which-key
  :ensure t
  :demand t
  :diminish
  :config
  (which-key-mode 1)
  (setq which-key-idle-delay 0.5))

;; Hydra for better key sequences
(use-package hydra)

;; Code navigation hydra (like Doom's SPC c)
(defhydra hydra-code (:color blue :hint nil)
  "
  Code Navigation & Actions
  ──────────────────────────────────────────
  _d_: Definition     _r_: References     _i_: Implementation
  _D_: Def (other)    _t_: Type def       _h_: Documentation
  _n_: Rename         _a_: Actions        _f_: Format
  _s_: Search symbol  _S_: Search project _q_: Quit
  "
  ("d" xref-find-definitions)
  ("D" xref-find-definitions-other-window)
  ("r" xref-find-references)
  ("i" eglot-find-implementation)
  ("t" eglot-find-typeDefinition)
  ("h" eldoc-doc-buffer)
  ("n" eglot-rename)
  ("a" eglot-code-actions)
  ("f" eglot-format)
  ("s" consult-line)
  ("S" consult-ripgrep)
  ("q" nil))

(global-set-key (kbd "C-c c") 'hydra-code/body)

;; Avy - jump to visible text
(use-package avy
  :ensure t
  :bind (("C-:" . avy-goto-char)
         ("C-'" . avy-goto-char-2)
         ("M-g f" . avy-goto-line)
         ("M-g w" . avy-goto-word-1)
         ("M-g e" . avy-goto-word-0))
  :config
  (setq avy-background t
        avy-style 'at-full))

;; Expand region
(use-package expand-region
  :ensure t
  :bind ("C-=" . er/expand-region))

;; Multiple cursors
(use-package multiple-cursors
  :ensure t
  :bind (("C-S-c C-S-c" . mc/edit-lines)
         ("C->" . mc/mark-next-like-this)
         ("C-<" . mc/mark-previous-like-this)
         ("C-c C-<" . mc/mark-all-like-this)))

;; Better undo
(use-package undo-tree
  :diminish
  :config
  (global-undo-tree-mode 1)
  (setq undo-tree-visualizer-timestamps t
        undo-tree-visualizer-diff t))

;; Save command history
(use-package savehist
  :ensure nil
  :init
  (savehist-mode 1)
  :config
  (setq savehist-save-minibuffer-history t
        savehist-additional-variables '(kill-ring search-ring regexp-search-ring)))

;; Automatic delimiter pairing
(use-package smartparens
  :hook (prog-mode . smartparens-mode)
  :config
  (require 'smartparens-config))

;; Rainbow delimiters
(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

;; Highlight TODO keywords
(use-package hl-todo
  :hook (prog-mode . hl-todo-mode)
  :config
  (setq hl-todo-highlight-punctuation ":"
        hl-todo-keyword-faces
        '(("TODO" warning bold)
          ("FIXME" error bold)
          ("NOTE" success bold))))

;; YASnippet - template system
(use-package yasnippet
  :ensure t
  :diminish yas-minor-mode
  :hook ((prog-mode . yas-minor-mode)
         (text-mode . yas-minor-mode))
  :config
  (yas-global-mode 1))

(use-package yasnippet-snippets
  :ensure t
  :after yasnippet)

;; Embark - contextual actions
(use-package embark
  :ensure t
  :bind
  (("C-." . embark-act)
   ("C-;" . embark-dwim)
   ("C-h B" . embark-bindings))
  :init
  (setq prefix-help-command #'embark-prefix-help-command))

;; Embark-Consult integration
(use-package embark-consult
  :ensure t
  :after (embark consult)
  :demand t
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

;;; File Format Support

;; Markdown Mode - Enhanced markdown editing
(use-package markdown-mode
  :mode (("README\\.md\\'" . gfm-mode)
         ("\\.md\\'" . markdown-mode)
         ("\\.markdown\\'" . markdown-mode))
  :init
  (setq markdown-command "multimarkdown"
        markdown-asymmetric-header t
        markdown-header-scaling t
        markdown-enable-math t
        markdown-fontify-code-blocks-natively t)
  :config
  ;; Use pandoc if available
  (when (executable-find "pandoc")
    (setq markdown-command "pandoc")))

;; Markdown preview
(use-package markdown-preview-mode
  :after markdown-mode
  :commands markdown-preview-mode)

;; JSON Mode - Better JSON editing
(use-package json-mode
  :mode "\\.json\\'"
  :hook (json-mode . (lambda ()
                       (make-local-variable 'js-indent-level)
                       (setq js-indent-level 2))))

;; JSON Navigator
(use-package json-navigator
  :after json-mode)

;; YAML Mode
(use-package yaml-mode
  :mode "\\.ya?ml\\'")

;; TOML Mode
(use-package toml-mode
  :mode "\\.toml\\'")

;; CSV Mode
(use-package csv-mode
  :mode "\\.csv\\'")

;;; Org Mode (optional but useful)

(use-package org
  :ensure nil
  :config
  (setq org-startup-indented t
        org-pretty-entities t
        org-hide-emphasis-markers t
        org-startup-with-inline-images t
        org-image-actual-width '(300)))

;; Modern org bullets
(use-package org-bullets
  :after org
  :hook (org-mode . org-bullets-mode))

;;; Final optimizations

;; Enable narrow-to-region
(put 'narrow-to-region 'disabled nil)

;; Better performance for long lines
(global-so-long-mode 1)

;; Startup message
(add-hook 'emacs-startup-hook
          (lambda ()
            (message "Emacs loaded in %s with %d garbage collections."
                     (format "%.2f seconds"
                             (float-time
                              (time-subtract after-init-time before-init-time)))
                     gcs-done)))

(provide 'init)
;;; init.el ends here
