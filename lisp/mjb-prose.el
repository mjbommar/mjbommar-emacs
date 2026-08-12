;;; mjb-prose.el --- Prose, Markdown, spelling -*- lexical-binding: t -*-

;;; Commentary:
;; Prose is the primary workload on this machine: .tex is the most-edited file
;; type and .md is second.  LaTeX has its own module (mjb-latex.el); this is
;; everything else that is writing rather than code.
;;
;; Spell checking is built in (`flyspell') and aspell with English dictionaries
;; is installed -- verified -- so this costs no package.
;;
;; Requirement refs: R-021 (visual-line-mode in prose), R-052 (Markdown without
;; missing binaries), R-053 (spell check).

;;; Code:

(require 'mjb-core)

(defvar markdown-command)
(defvar markdown-fontify-code-blocks-natively)
(defvar markdown-header-scaling)
(defvar markdown-enable-math)
(defvar markdown-asymmetric-header)
(defvar markdown-hide-urls)
(defvar markdown-list-indent-width)
(defvar ispell-program-name)
(defvar ispell-dictionary)
(defvar ispell-personal-dictionary)
(defvar ispell-extra-args)
(defvar ispell-silently-savep)
(defvar flyspell-issue-message-flag)
(defvar flyspell-issue-welcome-flag)
(defvar flyspell-use-meta-tab)

(defgroup mjb-prose nil "Prose editing." :group 'text)

;;;; Text mode ------------------------------------------------------------------

(defun mjb-prose-setup ()
  "Settings shared by every prose buffer."
  ;; R-021: `visual-line-mode' is the only command in your entire M-x history,
  ;; run twice.  It should never need typing again.
  (visual-line-mode 1)
  (setq-local truncate-lines nil)
  ;; Line numbers are noise in prose and cost redisplay on wrapped lines.
  (display-line-numbers-mode -1)
  ;; Sentences end with one space; this is what makes M-e / M-a behave in
  ;; modern prose rather than requiring double spacing.
  (setq-local sentence-end-double-space nil))

(add-hook 'text-mode-hook #'mjb-prose-setup)

;;;; Spelling (R-053) -----------------------------------------------------------
;; aspell is installed with en dictionaries (verified: aspell dicts -> en,
;; en-variant_0..2, en-w_accents).  hunspell is not installed.

(setq ispell-program-name (or (executable-find "aspell") "ispell")
      ispell-dictionary "en"
      ;; --sug-mode=ultra keeps suggestion time down on long documents.
      ispell-extra-args '("--sug-mode=ultra" "--run-together")
      ispell-personal-dictionary (mjb-var "aspell-personal-dict")
      ;; Save additions without prompting to write the dictionary file.
      ispell-silently-savep t)

(defun mjb-prose-enable-spelling ()
  "Turn on `flyspell' if a spell checker is actually installed."
  (when (executable-find ispell-program-name)
    (flyspell-mode 1)))

(add-hook 'text-mode-hook #'mjb-prose-enable-spelling)
;; In code, check comments and strings only.
(add-hook 'prog-mode-hook #'flyspell-prog-mode)

(with-eval-after-load 'flyspell
  (setq flyspell-issue-message-flag nil   ; do not echo on every word: slow
        flyspell-issue-welcome-flag nil
        ;; Do not steal C-. / C-, -- those are unreachable in a terminal
        ;; anyway (F-06), and mjb-keys.el owns the global map.
        flyspell-use-meta-tab nil))

;; LaTeX buffers get flyspell from mjb-latex.el's hook chain via text-mode;
;; `tex-mode-flyspell-verify' (built in) is what stops it flagging \textbf.

;;;; Markdown -------------------------------------------------------------------
;; markdown-mode is one of the four packages kept: Emacs has no built-in
;; Markdown mode, and writing one that handles GFM tables and links is real
;; work rather than a weekend.

(autoload 'gfm-mode "markdown-mode" nil t)
;; Order matters and is easy to get backwards: `auto-mode-alist' is searched
;; front to back and `add-to-list' PREPENDS, so the general patterns must be
;; added first for the specific ones to end up ahead of them.
(add-to-list 'auto-mode-alist '("\\.markdown\\'" . markdown-mode))
(add-to-list 'auto-mode-alist '("\\.md\\'" . markdown-mode))
(add-to-list 'auto-mode-alist '("AGENTS\\.md\\'" . gfm-mode))
(add-to-list 'auto-mode-alist '("CLAUDE\\.md\\'" . gfm-mode))
(add-to-list 'auto-mode-alist '("README\\.md\\'" . gfm-mode))

(with-eval-after-load 'markdown-mode
  ;; R-052: the previous config set `markdown-command' to "multimarkdown" with
  ;; a pandoc fallback.  NEITHER is installed, so preview and export were dead.
  ;; Point at whatever is actually present, and leave it nil otherwise so the
  ;; failure is an honest "no such command" rather than a silent no-op.
  (setq markdown-command (seq-find #'executable-find '("pandoc" "multimarkdown" "cmark"))
        markdown-fontify-code-blocks-natively t
        markdown-header-scaling nil     ; scaling needs a GUI font to mean much
        markdown-enable-math t
        markdown-asymmetric-header t
        markdown-hide-urls nil
        markdown-list-indent-width 2))

;; `markdown-preview-mode' is NOT installed: it starts a local web server and
;; a websocket, which is a lot of surface for a preview you can get from the
;; browser.  Removed deliberately (goal 2).

(provide 'mjb-prose)
;;; mjb-prose.el ends here
