;;; mjb-keys.el --- The keybinding table -*- lexical-binding: t -*-

;;; Commentary:
;; ONE table, and it is the authority.  Every global binding in this
;; configuration is listed in `mjb-key-table' below; no module uses
;; `global-set-key' or `use-package :bind'.
;;
;; That structure exists because of two defects in the previous config, both of
;; which were invisible precisely because the bindings were scattered 300 lines
;; apart across a 948-line file:
;;
;;   F-03  centaur-tabs claimed the `C-c t' prefix and eglot bound `C-c t' to a
;;         command, so tab keys worked or didn't depending on whether an LSP
;;         happened to be attached.
;;   F-04  project.el owned the `C-c p' prefix while nine cape commands were
;;         bound underneath it -- all nine shadowed, all nine dead, all nine
;;         documented in KEYBOARD.md as if they worked.
;;
;; scripts/check-keys.el asserts against this table, so a collision is a failing
;; test rather than a surprise months later.
;;
;; TERMINAL CONSTRAINT (F-06, R-033): Emacs runs in tmux inside Ghostty.
;; Control combined with punctuation (C-. C-; C-= C-> C-:) and
;; Control-Shift-letter have no legacy terminal encoding, so nothing important
;; is bound to them.  Bindings here use C-c <letter>, C-x <letter>, M-<letter>
;; and function keys, all of which a terminal can transmit.
;;
;; Requirement refs: R-030 through R-035, R-063.

;;; Code:

(require 'mjb-core)

(declare-function mjb-expand-region "mjb-editing")
(declare-function mjb-contract-region "mjb-editing")
(declare-function mjb-jump "mjb-editing")
(declare-function mjb-undo-redo "mjb-editing")
(declare-function mjb-toggle-theme "mjb-ui")
(declare-function mjb-tab-for-project "mjb-ui")
(declare-function mjb-sidebar-toggle "mjb-project")
(declare-function mjb-terminal "mjb-shell")
(declare-function mjb-ai-chat "mjb-ai")
(declare-function mjb-ai-complete "mjb-ai")
(declare-function mjb-ai-accept "mjb-ai")
(declare-function mjb-ai-dismiss "mjb-ai")
(declare-function mjb-ai-status "mjb-ai")
(declare-function mjb-ai-select-model "mjb-ai")
(declare-function mjb-ai-use-provider "mjb-ai")
(declare-function mjb-python-format-buffer "mjb-python")
(declare-function mjb-install-treesit-grammars "mjb-formats")

;; Mode maps and commands from packages loaded on demand.  Declared so this
;; file byte-compiles without eagerly loading eglot, corfu or vertico.
(defvar eglot-mode-map)
(defvar corfu-map)
(defvar vertico-map)
(declare-function eglot-rename "eglot")
(declare-function eglot-code-actions "eglot")
(declare-function eglot-find-implementation "eglot")
(declare-function eglot-find-typeDefinition "eglot")
(declare-function eglot-format-buffer "eglot")
(declare-function corfu-next "corfu")
(declare-function corfu-previous "corfu")
(declare-function corfu-insert "corfu")
(declare-function vertico-next "vertico")
(declare-function vertico-previous "vertico")
(declare-function which-key-add-key-based-replacements "which-key")

;;;; Prefix allocation ----------------------------------------------------------
;; Exactly one owner each.  `C-c <letter>' is the range Emacs reserves for the
;; user, which is why modes keep their own `C-c C-<letter>' keys without ever
;; colliding with this table (AUCTeX-style `C-c C-c' in mjb-latex.el, python's
;; `C-c C-p', magit's internal maps).
;;
;;   C-c a   AI                    C-c s   search
;;   C-c c   code / LSP            C-c t   toggles      <- sole owner (F-03)
;;   C-c p   project               C-c e   explorer (file sidebar)
;;   C-x g   magit                 C-x t   tab-bar      <- built-in tab-prefix-map
;;
;; NOTE `C-x t' is Emacs's own `tab-prefix-map'.  The file sidebar was going to
;; live there (it did in the old config, as treemacs); tab-bar owns that prefix
;; by convention, so the sidebar moved to `C-c e'.

(defconst mjb-key-prefixes
  '(("C-c a" . "ai")
    ("C-c c" . "code")
    ("C-c s" . "search")
    ("C-c t" . "toggle"))
  "Prefix keys owned by this configuration, and their which-key labels.")

;;;; The table ------------------------------------------------------------------
;; (KEY COMMAND DESCRIPTION).  DESCRIPTION is used by
;; scripts/gen-keyboard-doc.el to regenerate KEYBOARD.md, so it is
;; documentation that cannot drift from the code (R-080).

(defconst mjb-key-table
  '(;; --- AI ---------------------------------------------------------------
    ("C-c a a" mjb-ai-chat              "Claude chat")
    ("C-c a s" mjb-ai-complete          "Inline suggestion at point")
    ("C-c a RET" mjb-ai-accept          "Accept suggestion")
    ("C-c a d" mjb-ai-dismiss           "Dismiss suggestion")
    ("C-c a p" mjb-ai-use-provider      "Switch provider (its default models)")
    ("C-c a m" mjb-ai-select-model      "Switch provider / model")
    ("C-c a ?" mjb-ai-status            "Providers, models, credentials")

    ;; --- Code -------------------------------------------------------------
    ("C-c c d" xref-find-definitions    "Jump to definition")
    ("C-c c r" xref-find-references     "Find references")
    ("C-c c f" mjb-python-format-buffer "Format buffer")
    ("C-c c h" eldoc-doc-buffer         "Documentation at point")
    ("C-c c e" flymake-show-buffer-diagnostics "Diagnostics")
    ("C-c c n" flymake-goto-next-error  "Next diagnostic")
    ("C-c c p" flymake-goto-prev-error  "Previous diagnostic")

    ;; --- Explorer ---------------------------------------------------------
    ("C-c e"   mjb-sidebar-toggle       "Toggle file sidebar")

    ;; --- Search -----------------------------------------------------------
    ("C-c s s" consult-line             "Search this buffer")
    ("C-c s r" consult-ripgrep          "Ripgrep the project")
    ("C-c s i" consult-imenu            "Jump to a definition/section")
    ("C-c s o" consult-outline          "Jump by outline heading")
    ("C-c s f" consult-find             "Find a file by name")

    ;; --- Toggles ----------------------------------------------------------
    ("C-c t t" mjb-toggle-theme         "Light / dark theme")
    ("C-c t l" display-line-numbers-mode "Line numbers")
    ("C-c t w" visual-line-mode         "Visual line wrapping")
    ("C-c t s" flyspell-mode            "Spell checking")
    ("C-c t f" flymake-mode             "Syntax checking")

    ;; --- Top level --------------------------------------------------------
    ("C-c l"   recenter-top-bottom      "Recenter (C-l alternative)")
    ("C-c v"   mjb-expand-region        "Expand region")
    ("C-c V"   mjb-contract-region      "Contract region")
    ("C-c y"   consult-yank-pop         "Yank from kill ring")
    ("C-c g"   magit-status             "Magit status")
    ("C-c '"   mjb-terminal             "Terminal (eshell; C-u for ansi-term)")
    ("C-x g"   magit-status             "Magit status")
    ("C-x b"   consult-buffer           "Switch buffer")
    ("C-x 4 b" consult-buffer-other-window "Switch buffer, other window")
    ("C-x p t" mjb-tab-for-project      "Open project in its own tab")

    ;; --- Motion -----------------------------------------------------------
    ("M-g g"   consult-goto-line        "Go to line")
    ("M-g M-g" consult-goto-line        "Go to line")
    ("M-g j"   mjb-jump                 "Jump to visible text")
    ("M-s l"   consult-line             "Search this buffer")
    ("M-s r"   consult-ripgrep          "Ripgrep the project")

    ;; --- Editing ----------------------------------------------------------
    ("C-?"     mjb-undo-redo            "Redo")
    ("M-/"     hippie-expand            "Expand from context"))
  "Every global keybinding.  (KEY COMMAND DESCRIPTION).

Deliberately NOT bound, and why:
  M-y   stays `yank-pop'      -- the old config's minuet took it (R-063)
  M-l   stays `downcase-word' -- recenter is on C-c l instead
  M-0   stays `digit-argument'-- treemacs had it; tab-bar uses C-x t <n>
  C-.   C-;  C-=  C->  C-<  C-S-c  -- cannot be typed in this terminal (F-06)")

;;;; Application ----------------------------------------------------------------

(defun mjb-apply-key-table ()
  "Install every binding in `mjb-key-table' into the global map."
  (dolist (entry mjb-key-table)
    (let ((key (kbd (nth 0 entry)))
          (cmd (nth 1 entry)))
      (keymap-global-set (key-description key) cmd))))

(mjb-apply-key-table)

;; Label the prefixes so which-key shows "ai" rather than "+prefix".
(with-eval-after-load 'which-key
  (dolist (p mjb-key-prefixes)
    (when (fboundp 'which-key-add-key-based-replacements)
      (which-key-add-key-based-replacements (car p) (cdr p)))))

;;;; Prefix keymaps -------------------------------------------------------------
;; These are keymaps rather than commands, so they are not in the table above.

;; C-c p -> project.  SOLE owner (F-04): cape's backends are in
;; `completion-at-point-functions' (see mjb-completion.el), not on keys.
(keymap-global-set "C-c p" project-prefix-map)

;; C-x t is Emacs's built-in `tab-prefix-map'; nothing to do but leave it alone.

;;;; Mode-local bindings --------------------------------------------------------
;; Minor-mode maps shadow the global map, so anything bound here must not
;; duplicate a global key.  This is exactly how F-03 happened.

(with-eval-after-load 'eglot
  ;; Reuse the same C-c c prefix rather than inventing a second one.
  (keymap-set eglot-mode-map "C-c c n" #'eglot-rename)
  (keymap-set eglot-mode-map "C-c c a" #'eglot-code-actions)
  (keymap-set eglot-mode-map "C-c c i" #'eglot-find-implementation)
  (keymap-set eglot-mode-map "C-c c t" #'eglot-find-typeDefinition)
  (keymap-set eglot-mode-map "C-c c f" #'eglot-format-buffer))

(with-eval-after-load 'corfu
  (keymap-set corfu-map "TAB" #'corfu-next)
  (keymap-set corfu-map "S-TAB" #'corfu-previous)
  (keymap-set corfu-map "RET" #'corfu-insert))

(with-eval-after-load 'vertico
  (keymap-set vertico-map "C-j" #'vertico-next)
  (keymap-set vertico-map "C-k" #'vertico-previous))

(provide 'mjb-keys)
;;; mjb-keys.el ends here
