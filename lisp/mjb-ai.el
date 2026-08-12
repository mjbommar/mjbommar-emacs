;;; mjb-ai.el --- Multi-provider LLM chat and completion -*- lexical-binding: t -*-

;;; Commentary:
;; Replaces gptel (13,366 lines) and minuet (5,090 + dash 3,347 + plz 1,161)
;; WITHOUT giving up multi-provider support, which those packages had and an
;; earlier version of this file wrongly dropped.
;;
;; Three wire formats cover essentially everything:
;;
;;   anthropic  /v1/messages           Claude
;;   openai     /v1/chat/completions   OpenAI, xAI, Lambda, vLLM, Ollama,
;;                                     llama.cpp, LM Studio, TGI, OpenRouter,
;;                                     and any other OpenAI-compatible server
;;   gemini     :streamGenerateContent Google
;;
;; vLLM and other local/remote GPU servers are first-class: they are just an
;; `openai' entry with your own :url.  See `mjb-ai-add-openai-compatible'.
;; That is also how to add Lambda, Together, Fireworks, OpenRouter, Bedrock's
;; OpenAI-compatible gateway, or a box on your LAN -- e.g.
;;
;;   (mjb-ai-add-openai-compatible 'lambda
;;     "https://<your-lambda-endpoint>/v1/chat/completions" "LAMBDA_API_KEY")
;;   (mjb-ai-add-openai-compatible 'gpu-box
;;     "http://gpu-box.local:8000/v1/chat/completions")
;;
;; No endpoint is shipped for Lambda deliberately: I guessed a hostname for it
;; once and the guess did not resolve.  Fill in the one you actually use.
;;
;; Model lists are fetched from each provider's /models endpoint rather than
;; hardcoded, so they never go stale.
;;
;; Credentials: auth-source (~/.authinfo.gpg) first, then the provider's
;; environment variable.  auth-source is preferred (R-013) but env is honoured
;; because that is how the rest of your tooling is set up.
;;
;; SECURITY: keys never appear on curl's command line, where `ps' would expose
;; them.  They go in a mode-0600 config file that curl reads and we delete.

;;; Code:

(require 'mjb-core)
(require 'json)

(defgroup mjb-ai nil "LLM chat and completion." :group 'tools)

;;;; Providers ------------------------------------------------------------------

(defcustom mjb-ai-providers
  '((anthropic
     :url       "https://api.anthropic.com/v1/messages"
     :models-url "https://api.anthropic.com/v1/models"
     :wire      anthropic
     :auth-host "api.anthropic.com"
     :auth-env  "ANTHROPIC_API_KEY")
    (openai
     :url       "https://api.openai.com/v1/chat/completions"
     :models-url "https://api.openai.com/v1/models"
     :wire      openai
     :auth-host "api.openai.com"
     :auth-env  "OPENAI_API_KEY")
    (xai
     :url       "https://api.x.ai/v1/chat/completions"
     :models-url "https://api.x.ai/v1/models"
     :wire      openai
     :auth-host "api.x.ai"
     :auth-env  "XAI_API_KEY")
    (gemini
     :url       "https://generativelanguage.googleapis.com/v1beta/models/%s:streamGenerateContent?alt=sse"
     :models-url "https://generativelanguage.googleapis.com/v1beta/models"
     :wire      gemini
     :auth-host "generativelanguage.googleapis.com"
     :auth-env  "GEMINI_API_KEY")
    (ollama
     :url       "http://localhost:11434/v1/chat/completions"
     :models-url "http://localhost:11434/v1/models"
     :wire      openai
     :auth-host nil
     :auth-env  nil))
  "Known inference providers.

Each entry is (NAME . PLIST):
  :url        request endpoint.  For the gemini wire it is a format string
              taking the model name.
  :models-url optional; queried by \\[mjb-ai-select-model] so model lists
              are never hardcoded and never go stale.
  :wire       `anthropic', `openai', or `gemini'.
  :auth-host  auth-source machine, or nil for no auth (local servers).
  :auth-env   environment variable to fall back on, or nil.
  :extra      alist of extra body fields.

Add a vLLM box with `mjb-ai-add-openai-compatible'."
  :type '(alist :key-type symbol :value-type plist) :group 'mjb-ai)

(defcustom mjb-ai-chat-provider 'anthropic
  "Provider used for conversation." :type 'symbol :group 'mjb-ai)

(defcustom mjb-ai-chat-model "claude-opus-5"
  "Model used for conversation." :type 'string :group 'mjb-ai)

(defcustom mjb-ai-completion-provider 'anthropic
  "Provider used for inline completion." :type 'symbol :group 'mjb-ai)

(defcustom mjb-ai-completion-model "claude-haiku-4-5"
  "Model used for inline completion.
Completion is latency-bound, so a fast model beats a smart one here."
  :type 'string :group 'mjb-ai)

(defcustom mjb-ai-max-tokens 16000
  "Output token ceiling for chat." :type 'integer :group 'mjb-ai)

;;;###autoload
(defun mjb-ai-add-openai-compatible (name url &optional auth-env)
  "Register an OpenAI-compatible server NAME at URL.
Covers vLLM, Ollama, llama.cpp, LM Studio, TGI and friends.  URL is the
full chat-completions endpoint.  AUTH-ENV names an environment variable
holding a token, or nil for an unauthenticated local server.

  (mjb-ai-add-openai-compatible \\='gpu-box
    \"http://gpu-box.local:8000/v1/chat/completions\")"
  (setf (alist-get name mjb-ai-providers)
        (list :url url
              :models-url (replace-regexp-in-string
                           "/chat/completions\\'" "/models" url)
              :wire 'openai
              :auth-host nil
              :auth-env auth-env))
  (message "mjb-ai: registered %s -> %s" name url))

(defun mjb-ai--provider (name)
  "Plist for provider NAME, or an error naming what is available."
  (or (alist-get name mjb-ai-providers)
      (user-error "mjb-ai: unknown provider %s (have: %s)" name
                  (mapconcat #'symbol-name (mapcar #'car mjb-ai-providers) " "))))

;;;; Credentials ----------------------------------------------------------------

(defun mjb-ai--key (provider)
  "Key for PROVIDER: auth-source first, then its environment variable."
  (let* ((p (mjb-ai--provider provider))
         (host (plist-get p :auth-host))
         (env  (plist-get p :auth-env)))
    (cond ((and (null host) (null env)) :none)      ; unauthenticated server
          ((and host (mjb-auth-token host)))
          ((and env (getenv env)))
          (t nil))))

(defun mjb-ai--key! (provider)
  "Key for PROVIDER, or an actionable error."
  (let ((k (mjb-ai--key provider))
        (p (mjb-ai--provider provider)))
    (or k (user-error
           "mjb-ai: no credential for %s.  Either add to ~/.authinfo.gpg:\n  machine %s login apikey password ...\nor export %s"
           provider (or (plist-get p :auth-host) "<host>")
           (or (plist-get p :auth-env) "<VAR>")))))

;;;; Wire adapters --------------------------------------------------------------

(defun mjb-ai--headers (provider key)
  "Header lines for PROVIDER, in curl-config syntax."
  (let ((wire (plist-get (mjb-ai--provider provider) :wire)))
    (append
     (list "header = \"content-type: application/json\"")
     (cond
      ((eq key :none) nil)
      ((eq wire 'anthropic)
       (list (format "header = \"x-api-key: %s\"" key)
             "header = \"anthropic-version: 2023-06-01\""))
      ((eq wire 'gemini)
       (list (format "header = \"x-goog-api-key: %s\"" key)))
      (t (list (format "header = \"authorization: Bearer %s\"" key)))))))

(defun mjb-ai--url (provider model)
  "Endpoint for PROVIDER, substituting MODEL where the wire needs it."
  (let* ((p (mjb-ai--provider provider))
         (url (plist-get p :url)))
    (if (eq (plist-get p :wire) 'gemini) (format url model) url)))

(defun mjb-ai--body (provider model messages max-tokens)
  "JSON request body for PROVIDER.
MESSAGES is a list of (ROLE . TEXT) with ROLE a string."
  (let* ((p (mjb-ai--provider provider))
         (wire (plist-get p :wire))
         (extra (plist-get p :extra)))
    (json-serialize
     (append
      (pcase wire
        ('anthropic
         `((model . ,model) (max_tokens . ,max-tokens) (stream . t)
           (messages . ,(vconcat
                         (mapcar (lambda (m) `((role . ,(car m)) (content . ,(cdr m))))
                                 messages)))))
        ('gemini
         ;; NOTE Gemini 2.5+ thinks by default and thinking tokens come OUT of
         ;; maxOutputTokens.  With a small budget the whole allowance is spent
         ;; on thoughts and you get an empty reply -- which looked exactly like
         ;; a parser bug until the raw response showed thoughtsTokenCount=16
         ;; of a 24-token budget.  Scale the budget and cap thinking.
         `((contents . ,(vconcat
                         (mapcar (lambda (m)
                                   `((role . ,(if (equal (car m) "assistant") "model" "user"))
                                     (parts . ,(vector `((text . ,(cdr m)))))))
                                 messages)))
           (generationConfig
            . ((maxOutputTokens . ,(max 1024 max-tokens))
               (thinkingConfig . ((thinkingBudget . 0)))))))
        (_
         `((model . ,model) (stream . t) (max_tokens . ,max-tokens)
           (messages . ,(vconcat
                         (mapcar (lambda (m) `((role . ,(car m)) (content . ,(cdr m))))
                                 messages))))))
      extra))))

(defun mjb-ai--delta (wire obj)
  "Extract streamed text from a parsed SSE OBJ for WIRE, or nil."
  (pcase wire
    ('anthropic
     (let ((d (alist-get 'delta obj)))
       (and (equal (alist-get 'type obj) "content_block_delta")
            (equal (alist-get 'type d) "text_delta")
            (alist-get 'text d))))
    ('gemini
     (let* ((c (aref (or (alist-get 'candidates obj) [])  0))
            (parts (alist-get 'parts (alist-get 'content c))))
       (and parts (> (length parts) 0) (alist-get 'text (aref parts 0)))))
    (_
     (let* ((ch (alist-get 'choices obj)))
       (and ch (> (length ch) 0)
            (alist-get 'content (alist-get 'delta (aref ch 0))))))))

(defun mjb-ai--obj-error (obj)
  "Error message inside a parsed OBJ, or nil.  Same shape across providers."
  (let ((e (alist-get 'error obj)))
    (cond ((stringp e) e)
          (e (or (alist-get 'message e) (format "%s" e)))
          ;; Anthropic: HTTP 200 with a refusal stop reason.
          ((equal (alist-get 'stop_reason (alist-get 'delta obj)) "refusal")
           "request declined by safety classifiers"))))

;;;; Transport ------------------------------------------------------------------

(defun mjb-ai--config-file (url headers payload)
  "Write a mode-0600 curl config.  Keys stay out of argv and therefore out of `ps'."
  (let ((file (make-temp-file "mjb-ai-" nil ".conf")))
    (with-temp-file file
      (insert (format "url = %s\n" url))
      (insert "request = POST\n")
      (dolist (h headers) (insert h "\n"))
      (insert "silent\nshow-error\nno-progress-meter\n")
      (insert (format "data = \"%s\"\n"
                      (replace-regexp-in-string
                       "\"" "\\\\\""
                       (replace-regexp-in-string "\\\\" "\\\\\\\\" payload)))))
    (set-file-modes file #o600)
    file))

(defun mjb-ai--parse-sse (chunk state wire on-text)
  "Feed CHUNK to the SSE parser for WIRE.  Return an error string or nil."
  (setcar state (concat (car state) chunk))
  (let (err)
    (while (string-match "\n" (car state))
      (let ((line (substring (car state) 0 (match-beginning 0))))
        (setcar state (substring (car state) (match-end 0)))
        (let ((body (cond ((string-prefix-p "data: " line) (substring line 6))
                          ;; Non-streaming error bodies arrive as bare JSON.
                          ((string-prefix-p "{" line) line))))
          (when (and body (not (string= body "[DONE]")))
            (condition-case nil
                (let ((o (json-parse-string body :object-type 'alist)))
                  (setq err (or (mjb-ai--obj-error o) err))
                  (when-let ((txt (mjb-ai--delta wire o))) (funcall on-text txt)))
              (error nil))))))
    err))

(defun mjb-ai--request (provider model messages max-tokens on-text on-done)
  "Stream a completion from PROVIDER/MODEL.  Returns the process."
  (let* ((key (mjb-ai--key! provider))
         (wire (plist-get (mjb-ai--provider provider) :wire))
         (conf (mjb-ai--config-file (mjb-ai--url provider model)
                                    (mjb-ai--headers provider key)
                                    (mjb-ai--body provider model messages max-tokens)))
         (state (list "")) (err nil))
    (make-process
     :name "mjb-ai" :buffer nil :noquery t :connection-type 'pipe
     :command (list "curl" "--config" conf)
     :filter (lambda (_p chunk)
               (setq err (or (mjb-ai--parse-sse chunk state wire on-text) err)))
     :sentinel (lambda (_p event)
                 (ignore-errors (delete-file conf))
                 (funcall on-done (cond (err err)
                                        ((string-match-p "finished" event) nil)
                                        (t (string-trim event))))))))

;;;; Model discovery ------------------------------------------------------------

(defun mjb-ai-list-models (provider)
  "Fetch PROVIDER's model list synchronously.  Nil if unavailable."
  (let* ((p (mjb-ai--provider provider))
         (url (plist-get p :models-url))
         (key (mjb-ai--key provider)))
    (when url
      (let* ((conf (mjb-ai--config-file url (mjb-ai--headers provider key) ""))
             (out (with-temp-buffer
                    ;; GET, not POST: strip the request/data lines.
                    (let ((c (with-temp-buffer (insert-file-contents conf)
                               (goto-char (point-min))
                               (flush-lines "^\\(request\\|data\\) =")
                               (buffer-string))))
                      (with-temp-file conf (insert c)))
                    (call-process "curl" nil t nil "--config" conf)
                    (buffer-string))))
        (ignore-errors (delete-file conf))
        (condition-case nil
            (let ((o (json-parse-string out :object-type 'alist)))
              (cond
               ((alist-get 'data o)                       ; openai / anthropic
                (mapcar (lambda (m) (or (alist-get 'id m) (alist-get 'name m)))
                        (append (alist-get 'data o) nil)))
               ((alist-get 'models o)                     ; gemini
                (mapcar (lambda (m)
                          (string-remove-prefix "models/" (alist-get 'name m)))
                        (append (alist-get 'models o) nil)))))
          (error nil))))))

;;;###autoload
(defun mjb-ai-select-model (&optional for-completion)
  "Choose provider and model for chat.
With prefix FOR-COMPLETION, set the inline-completion pair instead."
  (interactive "P")
  (let* ((provider (intern (completing-read
                            "Provider: "
                            (mapcar (lambda (c) (symbol-name (car c))) mjb-ai-providers)
                            nil t)))
         (models (mjb-ai-list-models provider))
         (model (completing-read
                 (format "Model (%s): " provider) (or models '()) nil nil
                 (car models))))
    (if for-completion
        (setq mjb-ai-completion-provider provider mjb-ai-completion-model model)
      (setq mjb-ai-chat-provider provider mjb-ai-chat-model model))
    (message "mjb-ai: %s = %s / %s"
             (if for-completion "completion" "chat") provider model)))

;;;; Chat -----------------------------------------------------------------------

(defvar-local mjb-ai--history nil)
(defvar-local mjb-ai--proc nil)

(defvar mjb-ai-chat-mode-map
  (let ((m (make-sparse-keymap)))
    (keymap-set m "C-c C-c" #'mjb-ai-send)
    (keymap-set m "C-c C-k" #'mjb-ai-cancel)
    (keymap-set m "C-c C-m" #'mjb-ai-select-model)
    m))

(define-derived-mode mjb-ai-chat-mode text-mode "LLM"
  "Conversation buffer.  \\<mjb-ai-chat-mode-map>\\[mjb-ai-send] sends."
  (visual-line-mode 1)
  (setq-local truncate-lines nil))

(defun mjb-ai--insert (text)
  (let ((at-end (= (point) (point-max))))
    (save-excursion (goto-char (point-max)) (insert text))
    (when at-end (goto-char (point-max)))))

;;;###autoload
(defun mjb-ai-chat ()
  "Open a chat buffer for the current provider/model."
  (interactive)
  (mjb-ai--key! mjb-ai-chat-provider)
  (let ((buf (get-buffer-create "*LLM*")))
    (with-current-buffer buf
      (unless (derived-mode-p 'mjb-ai-chat-mode)
        (mjb-ai-chat-mode)
        (insert (format "# %s / %s\n\nC-c C-c sends.  C-c C-m switches model.\n\n## You\n\n"
                        mjb-ai-chat-provider mjb-ai-chat-model)))
      (goto-char (point-max)))
    (pop-to-buffer buf)))

(defun mjb-ai--last-prompt ()
  (save-excursion
    (goto-char (point-max))
    (if (re-search-backward "^## You$" nil t)
        (string-trim (buffer-substring-no-properties (line-end-position) (point-max)))
      (string-trim (buffer-string)))))

(defun mjb-ai-send ()
  "Send the current prompt and stream the reply."
  (interactive)
  (unless (derived-mode-p 'mjb-ai-chat-mode) (user-error "Not a chat buffer"))
  (when (process-live-p mjb-ai--proc) (user-error "mjb-ai: already streaming"))
  (let ((prompt (mjb-ai--last-prompt)) (buf (current-buffer)) (reply ""))
    (when (string-empty-p prompt) (user-error "mjb-ai: nothing to send"))
    (setq mjb-ai--history (append mjb-ai--history (list (cons "user" prompt))))
    (mjb-ai--insert (format "\n\n## %s\n\n" mjb-ai-chat-model))
    (setq mjb-ai--proc
          (mjb-ai--request
           mjb-ai-chat-provider mjb-ai-chat-model mjb-ai--history mjb-ai-max-tokens
           (lambda (text)
             (setq reply (concat reply text))
             (when (buffer-live-p buf) (with-current-buffer buf (mjb-ai--insert text))))
           (lambda (err)
             (when (buffer-live-p buf)
               (with-current-buffer buf
                 (if err
                     (mjb-ai--insert (format "\n\n*[error: %s]*" err))
                   (setq mjb-ai--history
                         (append mjb-ai--history (list (cons "assistant" reply)))))
                 (mjb-ai--insert "\n\n## You\n\n")
                 (setq mjb-ai--proc nil))))))))

(defun mjb-ai-cancel ()
  "Stop the in-flight request."
  (interactive)
  (when (process-live-p mjb-ai--proc)
    (delete-process mjb-ai--proc) (setq mjb-ai--proc nil)
    (message "mjb-ai: cancelled")))

;;;; Inline completion ----------------------------------------------------------
;; On demand only: nothing fires until you press a key (the 54ea9ff decision).

(defcustom mjb-ai-context-chars 4000
  "Characters of surrounding buffer sent as completion context."
  :type 'integer :group 'mjb-ai)

(defface mjb-ai-suggestion '((t :inherit shadow :slant italic))
  "Face for inline suggestions." :group 'mjb-ai)

(defvar-local mjb-ai--overlay nil)

(defun mjb-ai-dismiss ()
  "Remove the current suggestion."
  (interactive)
  (when (overlayp mjb-ai--overlay)
    (delete-overlay mjb-ai--overlay) (setq mjb-ai--overlay nil)))

(defun mjb-ai-accept ()
  "Insert the current suggestion."
  (interactive)
  (if (not (overlayp mjb-ai--overlay)) (user-error "mjb-ai: no suggestion")
    (let ((text (overlay-get mjb-ai--overlay 'mjb-ai-text)))
      (mjb-ai-dismiss) (insert text))))

(defun mjb-ai--show-suggestion (text)
  (mjb-ai-dismiss)
  (when (and text (not (string-empty-p (string-trim text))))
    (let ((ov (make-overlay (point) (point) nil t t)))
      (overlay-put ov 'mjb-ai-text text)
      (overlay-put ov 'after-string
                   (propertize text 'face 'mjb-ai-suggestion 'cursor t))
      (setq mjb-ai--overlay ov)
      (message "mjb-ai: %s accepts, %s dismisses"
               (substitute-command-keys "\\[mjb-ai-accept]")
               (substitute-command-keys "\\[mjb-ai-dismiss]")))))

;;;###autoload
(defun mjb-ai-complete ()
  "Continue the text at point, shown as ghost text."
  (interactive)
  (mjb-ai--key! mjb-ai-completion-provider)
  (let* ((half (/ mjb-ai-context-chars 2))
         (prefix (buffer-substring-no-properties (max (point-min) (- (point) half)) (point)))
         (suffix (buffer-substring-no-properties (point) (min (point-max) (+ (point) half))))
         (buf (current-buffer)) (acc ""))
    (message "mjb-ai: %s..." mjb-ai-completion-model)
    (mjb-ai--request
     mjb-ai-completion-provider mjb-ai-completion-model
     (list (cons "user"
                 (format "Continue this %s file at <CURSOR>. Reply with ONLY the \
text that replaces <CURSOR> -- no explanation, no code fences, no repetition of \
surrounding text.\n\n<document>\n%s<CURSOR>%s\n</document>"
                         (string-remove-suffix "-mode" (symbol-name major-mode))
                         prefix suffix)))
     256
     (lambda (text) (setq acc (concat acc text)))
     (lambda (err)
       (when (buffer-live-p buf)
         (with-current-buffer buf
           (cond (err (message "mjb-ai: %s" err))
                 ((string-empty-p (string-trim acc)) (message "mjb-ai: no suggestion"))
                 (t (mjb-ai--show-suggestion acc)))))))))

;;;; Status ---------------------------------------------------------------------

(defun mjb-ai-status ()
  "Show providers, models, and which credentials resolve."
  (interactive)
  (with-output-to-temp-buffer "*mjb-ai status*"
    (princ (format "chat:       %s / %s\ncompletion: %s / %s\n\n"
                   mjb-ai-chat-provider mjb-ai-chat-model
                   mjb-ai-completion-provider mjb-ai-completion-model))
    (princ (format "%-14s %-8s %-10s %s\n" "provider" "wire" "credential" "endpoint"))
    (dolist (entry mjb-ai-providers)
      (let* ((name (car entry)) (p (cdr entry)) (k (mjb-ai--key name)))
        (princ (format "%-14s %-8s %-10s %s\n" name (plist-get p :wire)
                       (cond ((eq k :none) "none req.")
                             ((null k) "MISSING")
                             ((mjb-auth-token (or (plist-get p :auth-host) "")) "authinfo")
                             (t "env"))
                       (plist-get p :url)))))))

(provide 'mjb-ai)
;;; mjb-ai.el ends here
