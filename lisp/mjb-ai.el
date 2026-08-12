;;; mjb-ai.el --- Claude chat and inline completion, no packages -*- lexical-binding: t -*-

;;; Commentary:
;; Replaces gptel (13,366 lines) and minuet (5,090 + dash 3,347 + plz 1,161).
;; This file is the whole thing.
;;
;; What was given up, honestly: gptel supports OpenAI/Gemini/Ollama backends,
;; tool use, context management and a transient menu; minuet supports several
;; providers and completion strategies.  None of that is used here -- both were
;; configured for Claude only.  What is kept is what you actually had: a
;; streaming chat buffer, and on-demand inline completion that stays OFF until
;; asked (the decision from commit 54ea9ff).
;;
;; Transport is curl driven by `make-process'.  Emacs's built-in url.el buffers
;; the whole response, which would lose streaming.
;;
;; SECURITY: the API key is never placed on curl's command line -- that would
;; expose it to every user on the machine via `ps'.  It goes into a mode-0600
;; config file that curl reads and we delete.  gptel passes headers as argv.
;;
;; Requirement refs: R-013 (auth-source), R-060 (model ids in one place),
;; R-061/R-062 (chat + on-demand completion), R-064 (degrade cleanly).

;;; Code:

(require 'mjb-core)
(require 'json)

(defgroup mjb-ai nil "Claude integration." :group 'tools)

;;;; Models (R-060) -------------------------------------------------------------
;; Anthropic retires model ids on a schedule.  When a request starts failing
;; with a 404, change these two strings -- nothing else names a model.
;; https://platform.claude.com/docs/en/about-claude/models/overview

(defcustom mjb-ai-chat-model "claude-opus-5"
  "Model for conversation.  Flagship: 1M context, strongest reasoning."
  :type 'string :group 'mjb-ai)

(defcustom mjb-ai-completion-model "claude-haiku-4-5"
  "Model for inline completion.
Deliberately the fast tier: completion is latency-bound, and the flagship
models think by default, which is the wrong trade at a 2-second budget."
  :type 'string :group 'mjb-ai)

(defcustom mjb-ai-host "api.anthropic.com"
  "auth-source host holding the API key.
  machine api.anthropic.com login apikey password sk-ant-..."
  :type 'string :group 'mjb-ai)

(defconst mjb-ai--endpoint "https://api.anthropic.com/v1/messages")
(defconst mjb-ai--version "2023-06-01")

;;;; Credentials (R-013, R-064) -------------------------------------------------

(defun mjb-ai-key ()
  "API key from auth-source, or nil."
  (mjb-auth-token mjb-ai-host))

(defun mjb-ai--key! ()
  "API key, or an actionable error."
  (or (mjb-ai-key)
      (user-error "mjb-ai: no key.  Add to ~/.authinfo.gpg:  machine %s login apikey password sk-ant-..."
                  mjb-ai-host)))

;;;; Transport ------------------------------------------------------------------

(defun mjb-ai--config-file (key payload)
  "Write a mode-0600 curl config carrying KEY and PAYLOAD.  Return its path.
Headers go in a file rather than argv so the key never appears in `ps'."
  (let ((file (make-temp-file "mjb-ai-" nil ".conf"))
        ;; Create with restrictive permissions from the start, not after.
        (create-lockfiles nil))
    (with-temp-file file
      (set-file-modes file #o600)
      (insert (format "url = %s\n" mjb-ai--endpoint))
      (insert "request = POST\n")
      (insert (format "header = \"x-api-key: %s\"\n" key))
      (insert (format "header = \"anthropic-version: %s\"\n" mjb-ai--version))
      (insert "header = \"content-type: application/json\"\n")
      (insert "no-progress-meter\n")
      (insert "silent\n")
      (insert "show-error\n")
      ;; Escape backslashes and quotes for curl's config syntax.
      (insert (format "data = \"%s\"\n"
                      (replace-regexp-in-string
                       "\"" "\\\\\""
                       (replace-regexp-in-string "\\\\" "\\\\\\\\" payload)))))
    (set-file-modes file #o600)
    file))

(defun mjb-ai--parse-sse (chunk state on-text)
  "Feed CHUNK through the SSE parser.
STATE is a cons cell holding the partial line buffer.  ON-TEXT is called
with each text delta.  Returns nil, or a string describing an API error."
  (setcar state (concat (car state) chunk))
  (let (err)
    (while (string-match "\n" (car state))
      (let ((line (substring (car state) 0 (match-beginning 0))))
        (setcar state (substring (car state) (match-end 0)))
        (when (string-prefix-p "data: " line)
          (let ((body (substring line 6)))
            (unless (string= body "[DONE]")
              (condition-case nil
                  (let* ((o (json-parse-string body :object-type 'alist))
                         (type (alist-get 'type o)))
                    (cond
                     ((equal type "content_block_delta")
                      (let ((d (alist-get 'delta o)))
                        (when (equal (alist-get 'type d) "text_delta")
                          (funcall on-text (alist-get 'text d)))))
                     ((equal type "error")
                      (setq err (or (alist-get 'message (alist-get 'error o))
                                    "unknown API error")))
                     ;; Opus 5 can decline a request: HTTP 200, stop_reason
                     ;; "refusal".  Surface it rather than showing nothing.
                     ((equal type "message_delta")
                      (when (equal (alist-get 'stop_reason (alist-get 'delta o))
                                   "refusal")
                        (setq err "request declined by safety classifiers")))))
                (error nil)))))
        ;; A non-streaming error body arrives as bare JSON, not SSE.
        (when (string-prefix-p "{\"type\":\"error\"" line)
          (condition-case nil
              (setq err (alist-get 'message
                                   (alist-get 'error (json-parse-string line :object-type 'alist))))
            (error (setq err line))))))
    err))

(defun mjb-ai--request (payload on-text on-done)
  "POST PAYLOAD (a JSON string) and stream deltas to ON-TEXT.
ON-DONE is called with nil on success or an error string.  Returns the process."
  (let* ((key (mjb-ai--key!))
         (conf (mjb-ai--config-file key payload))
         (state (list ""))
         (err nil)
         (proc (make-process
                :name "mjb-ai"
                :buffer nil
                :noquery t
                :connection-type 'pipe
                :command (list "curl" "--config" conf)
                :filter (lambda (_p chunk)
                          (setq err (or (mjb-ai--parse-sse chunk state on-text) err)))
                :sentinel (lambda (_p event)
                            (ignore-errors (delete-file conf))
                            (funcall on-done
                                     (cond (err err)
                                           ((string-match-p "finished" event) nil)
                                           (t (string-trim event))))))))
    proc))

(defun mjb-ai--payload (model messages &rest extra)
  "Build a request body for MODEL with MESSAGES, merging EXTRA."
  (json-serialize
   (append `((model . ,model)
             (max_tokens . 16000)
             (stream . t)
             (messages . ,(vconcat messages)))
           extra)))

;;;; Chat (R-061) ---------------------------------------------------------------

(defvar-local mjb-ai--history nil "Alist messages for this chat buffer.")
(defvar-local mjb-ai--proc nil)

(defvar mjb-ai-chat-mode-map
  (let ((m (make-sparse-keymap)))
    (keymap-set m "C-c C-c" #'mjb-ai-send)
    (keymap-set m "C-c C-k" #'mjb-ai-cancel)
    m)
  "Keymap for `mjb-ai-chat-mode'.")

(define-derived-mode mjb-ai-chat-mode text-mode "Claude"
  "Conversation with Claude.  \\<mjb-ai-chat-mode-map>\\[mjb-ai-send] sends."
  (visual-line-mode 1)
  (setq-local truncate-lines nil))

(defun mjb-ai--insert (text)
  "Insert TEXT at the end of the chat buffer, following point if at the end."
  (let ((at-end (= (point) (point-max))))
    (save-excursion (goto-char (point-max)) (insert text))
    (when at-end (goto-char (point-max)))))

;;;###autoload
(defun mjb-ai-chat ()
  "Open (or switch to) a Claude chat buffer."
  (interactive)
  (mjb-ai--key!)
  (let ((buf (get-buffer-create "*Claude*")))
    (with-current-buffer buf
      (unless (derived-mode-p 'mjb-ai-chat-mode)
        (mjb-ai-chat-mode)
        (insert (format "# Claude (%s)\n\nType, then C-c C-c to send.\n\n## You\n\n"
                        mjb-ai-chat-model))
        (goto-char (point-max))))
    (pop-to-buffer buf)))

(defun mjb-ai--last-prompt ()
  "Text typed after the final \"## You\" heading."
  (save-excursion
    (goto-char (point-max))
    (if (re-search-backward "^## You$" nil t)
        (string-trim (buffer-substring-no-properties
                      (line-end-position) (point-max)))
      (string-trim (buffer-substring-no-properties (point-min) (point-max))))))

(defun mjb-ai-send ()
  "Send the current prompt and stream the reply into the buffer."
  (interactive)
  (unless (derived-mode-p 'mjb-ai-chat-mode) (user-error "Not a Claude buffer"))
  (when (process-live-p mjb-ai--proc) (user-error "mjb-ai: already streaming"))
  (let ((prompt (mjb-ai--last-prompt))
        (buf (current-buffer)))
    (when (string-empty-p prompt) (user-error "mjb-ai: nothing to send"))
    (setq mjb-ai--history
          (append mjb-ai--history (list `((role . "user") (content . ,prompt)))))
    (mjb-ai--insert "\n\n## Claude\n\n")
    (let ((reply ""))
      (setq mjb-ai--proc
            (mjb-ai--request
             (mjb-ai--payload mjb-ai-chat-model mjb-ai--history)
             (lambda (text)
               (setq reply (concat reply text))
               (when (buffer-live-p buf)
                 (with-current-buffer buf (mjb-ai--insert text))))
             (lambda (err)
               (when (buffer-live-p buf)
                 (with-current-buffer buf
                   (if err
                       (mjb-ai--insert (format "\n\n*[error: %s]*" err))
                     (setq mjb-ai--history
                           (append mjb-ai--history
                                   (list `((role . "assistant") (content . ,reply))))))
                   (mjb-ai--insert "\n\n## You\n\n")
                   (setq mjb-ai--proc nil)))))))))

(defun mjb-ai-cancel ()
  "Stop the in-flight request."
  (interactive)
  (when (process-live-p mjb-ai--proc)
    (delete-process mjb-ai--proc)
    (setq mjb-ai--proc nil)
    (message "mjb-ai: cancelled")))

;;;; Inline completion (R-062) --------------------------------------------------
;; On demand only.  Nothing runs until you press the key -- preserving the
;; decision made in 54ea9ff, where auto-suggestion was turned off deliberately.

(defcustom mjb-ai-context-chars 4000
  "Characters of surrounding buffer sent as completion context."
  :type 'integer :group 'mjb-ai)

(defface mjb-ai-suggestion '((t :inherit shadow :slant italic))
  "Face for the inline suggestion." :group 'mjb-ai)

(defvar-local mjb-ai--overlay nil)

(defun mjb-ai-dismiss ()
  "Remove the current suggestion."
  (interactive)
  (when (overlayp mjb-ai--overlay)
    (delete-overlay mjb-ai--overlay)
    (setq mjb-ai--overlay nil)))

(defun mjb-ai-accept ()
  "Insert the current suggestion."
  (interactive)
  (if (not (overlayp mjb-ai--overlay))
      (user-error "mjb-ai: no suggestion")
    (let ((text (overlay-get mjb-ai--overlay 'mjb-ai-text)))
      (mjb-ai-dismiss)
      (insert text))))

(defun mjb-ai--show-suggestion (text)
  "Display TEXT as ghost text after point."
  (mjb-ai-dismiss)
  (when (and text (not (string-empty-p text)))
    (let ((ov (make-overlay (point) (point) nil t t)))
      (overlay-put ov 'mjb-ai-text text)
      (overlay-put ov 'after-string
                   (propertize text 'face 'mjb-ai-suggestion 'cursor t))
      (setq mjb-ai--overlay ov)
      (message "mjb-ai: %s to accept, %s to dismiss"
               (substitute-command-keys "\\[mjb-ai-accept]")
               (substitute-command-keys "\\[mjb-ai-dismiss]")))))

;;;###autoload
(defun mjb-ai-complete ()
  "Ask Claude to continue the text at point, shown as ghost text."
  (interactive)
  (mjb-ai--key!)
  (let* ((half (/ mjb-ai-context-chars 2))
         (prefix (buffer-substring-no-properties
                  (max (point-min) (- (point) half)) (point)))
         (suffix (buffer-substring-no-properties
                  (point) (min (point-max) (+ (point) half))))
         (buf (current-buffer))
         (acc ""))
    (message "mjb-ai: thinking...")
    (mjb-ai--request
     (mjb-ai--payload
      mjb-ai-completion-model
      (list `((role . "user")
              (content . ,(format "Continue this %s file at <CURSOR>. \
Reply with ONLY the text that replaces <CURSOR> -- no explanation, no code \
fences, no repetition of surrounding text.\n\n<document>\n%s<CURSOR>%s\n</document>"
                                  (or (and (boundp 'major-mode)
                                           (string-remove-suffix "-mode" (symbol-name major-mode)))
                                      "text")
                                  prefix suffix))))
      '(max_tokens . 256))
     (lambda (text) (setq acc (concat acc text)))
     (lambda (err)
       (when (buffer-live-p buf)
         (with-current-buffer buf
           (cond (err (message "mjb-ai: %s" err))
                 ((string-empty-p (string-trim acc)) (message "mjb-ai: no suggestion"))
                 (t (mjb-ai--show-suggestion acc)))))))))

;;;; Status ---------------------------------------------------------------------

(defun mjb-ai-status ()
  "Report configured models and whether a key is present."
  (interactive)
  (message "mjb-ai: chat=%s completion=%s key=%s"
           mjb-ai-chat-model mjb-ai-completion-model
           (if (mjb-ai-key) "found" "MISSING (see ~/.authinfo.gpg)")))

(provide 'mjb-ai)
;;; mjb-ai.el ends here
