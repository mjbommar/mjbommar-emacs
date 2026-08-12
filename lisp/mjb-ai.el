;;; mjb-ai.el --- Claude chat and inline completion -*- lexical-binding: t -*-

;;; Commentary:
;; Fixes F-10.  Both AI integrations were pointing at model IDs that are past
;; their retirement dates and therefore returned 404:
;;
;;   gptel   claude-opus-4-1-20250805   retired 2026-08-05
;;   minuet  claude-sonnet-4-20250514   retired 2026-06-15
;;
;; Model IDs expire.  They are therefore declared once, at the top of this
;; file, with a note saying where to check -- rather than buried 700 lines into
;; a monolith where the README disagreed with the code about which one was in
;; use (it claimed Opus 4.1 for minuet; the code said Sonnet 4).
;;
;; Credentials come from ~/.authinfo.gpg via auth-source (R-013), NOT from the
;; process environment.  See README for rotating the keys currently exported in
;; ~/.bashrc.
;;
;; Requirement refs: R-060, R-061, R-062, R-063, R-064.

;;; Code:

(require 'mjb-core)

(defvar gptel-model)
(defvar gptel-backend)
(defvar gptel-api-key)
(defvar gptel-default-mode)
(defvar gptel-prompt-prefix-alist)
(defvar gptel-response-prefix-alist)
(defvar minuet-provider)
(defvar minuet-claude-options)
(defvar minuet-n-completions)
(defvar minuet-context-window)
(defvar minuet-request-timeout)
(defvar minuet-auto-suggestion-debounce-delay)
(defvar minuet-auto-suggestion-throttle-delay)
(defvar minuet-auto-suggestion-mode)
(declare-function gptel-make-anthropic "gptel-anthropic")
(declare-function minuet-auto-suggestion-mode "minuet")
(declare-function minuet-set-optional-options "minuet")

(defgroup mjb-ai nil "AI assistance." :group 'tools)

;;;; Models (R-060) -------------------------------------------------------------
;; Current as of 2026-08-11.  Anthropic retires model IDs on a published
;; schedule; when a request starts failing with a 404, check
;; https://platform.claude.com/docs/en/about-claude/models/overview
;; and change these two strings.  Nothing else in the config names a model.

(defcustom mjb-ai-chat-model "claude-opus-5"
  "Model for conversational use (gptel).
Opus 5 is the flagship: 1M context, best reasoning."
  :type 'string :group 'mjb-ai)

(defcustom mjb-ai-completion-model "claude-haiku-4-5"
  "Model for inline code completion (minuet).
Deliberately the fast tier.  `minuet-request-timeout' is 2.5 seconds and a
fill-in-the-middle completion is not a reasoning task; the flagship models
also think by default now, which is the wrong trade at this latency."
  :type 'string :group 'mjb-ai)

(defconst mjb-ai-anthropic-host "api.anthropic.com"
  "auth-source host entry holding the Anthropic key.
Add a line to ~/.authinfo.gpg:
  machine api.anthropic.com login apikey password sk-ant-...")

;;;; Credentials (R-013, R-064) -------------------------------------------------

(defun mjb-ai-key ()
  "Return the Anthropic API key from auth-source, or nil.
Returns nil rather than signalling so that a missing credential produces a
clear message at the point of use instead of a backtrace at startup."
  (mjb-auth-token mjb-ai-anthropic-host))

(defun mjb-ai-key-or-explain ()
  "Return the API key, or raise an actionable error explaining how to set it."
  (or (mjb-ai-key)
      (user-error
       "mjb-ai: no Anthropic key.  Add to ~/.authinfo.gpg:  machine %s login apikey password sk-ant-..."
       mjb-ai-anthropic-host)))

;;;; gptel -- chat (R-061) ------------------------------------------------------

(with-eval-after-load 'gptel
  (setq gptel-model (intern mjb-ai-chat-model)
        gptel-default-mode 'org-mode
        ;; A function, so the key is read lazily and a missing credential does
        ;; not break loading.
        gptel-api-key #'mjb-ai-key
        gptel-backend (gptel-make-anthropic "Claude"
                        :key #'mjb-ai-key
                        :stream t))
  (setq gptel-prompt-prefix-alist
        '((markdown-mode . "## ")
          (org-mode . "** ")
          (text-mode . "> "))))

(defun mjb-ai-chat ()
  "Start or switch to a Claude chat buffer."
  (interactive)
  (mjb-ai-key-or-explain)
  (require 'gptel)
  (call-interactively #'gptel))

;;;; minuet -- inline completion (R-062) ----------------------------------------
;; Auto-suggestion stays OFF by default.  That was a deliberate decision in
;; commit 54ea9ff ("Disable minuet auto-suggestions by default with toggle
;; command") and is the clearest recent statement of intent in the repository;
;; the rebuild must not quietly undo it.

(with-eval-after-load 'minuet
  (setq minuet-provider 'claude
        minuet-n-completions 2
        minuet-context-window 4000
        minuet-request-timeout 2.5
        minuet-auto-suggestion-debounce-delay 0.5
        minuet-auto-suggestion-throttle-delay 1.2)
  (plist-put minuet-claude-options :model mjb-ai-completion-model)
  ;; minuet accepts a function here, which keeps the key out of the config and
  ;; out of the environment.
  (plist-put minuet-claude-options :api-key #'mjb-ai-key)
  (when (fboundp 'minuet-set-optional-options)
    (minuet-set-optional-options minuet-claude-options :max_tokens 256)))

(defun mjb-ai-toggle-completion ()
  "Toggle minuet automatic inline suggestions in this buffer."
  (interactive)
  (mjb-ai-key-or-explain)
  (require 'minuet)
  (if (bound-and-true-p minuet-auto-suggestion-mode)
      (progn (minuet-auto-suggestion-mode -1)
             (message "mjb-ai: inline suggestions off"))
    (minuet-auto-suggestion-mode 1)
    (message "mjb-ai: inline suggestions on (%s)" mjb-ai-completion-model)))

(defun mjb-ai-suggest ()
  "Ask for one inline suggestion at point, without enabling auto mode."
  (interactive)
  (mjb-ai-key-or-explain)
  (require 'minuet)
  (call-interactively #'minuet-show-suggestion))

;;;; Status ---------------------------------------------------------------------

(defun mjb-ai-status ()
  "Report which models are configured and whether a key is present."
  (interactive)
  (message "mjb-ai: chat=%s completion=%s key=%s"
           mjb-ai-chat-model mjb-ai-completion-model
           (if (mjb-ai-key) "found in auth-source" "MISSING")))

(provide 'mjb-ai)
;;; mjb-ai.el ends here
