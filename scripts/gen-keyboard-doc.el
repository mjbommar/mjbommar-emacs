;;; gen-keyboard-doc.el --- Generate KEYBOARD.md from the key table -*- lexical-binding: t -*-
;;; Commentary:
;; Implements R-080.  KEYBOARD.md is GENERATED from `mjb-key-table', so the
;; documentation cannot drift from the code.  The previous hand-written
;; KEYBOARD.md documented five bindings that did not work, including nine cape
;; commands that were shadowed and dead (F-04).
;;
;; Section layout, mode-local keys and the deliberately-unbound list all come
;; from mjb-keys.el (`mjb-keys-grouped', `mjb-mode-local-keys',
;; `mjb-keys-unbound').  They used to be duplicated here, which meant the
;; in-Emacs cheat sheet (\\[mjb-cheatsheet]) and this file could disagree.
;;
;; Usage:  emacs --batch ... -l scripts/gen-keyboard-doc.el
;;; Code:

(require 'mjb-keys)

(defun mjb-gen--section (title rows)
  (when rows
    (insert (format "\n### %s\n\n| Key | Command | Does |\n|---|---|---|\n" title))
    (dolist (r rows)
      (insert (format "| `%s` | `%s` | %s |\n" (nth 0 r) (nth 1 r) (nth 2 r))))))

(with-temp-file (expand-file-name "KEYBOARD.md" user-emacs-directory)
  (insert "# Keyboard reference\n\n")
  (insert "**This file is generated — do not edit it by hand.**\n")
  (insert "It is produced from `mjb-key-table` in `lisp/mjb-keys.el` by\n")
  (insert "`scripts/gen-keyboard-doc.el`, so it cannot drift from the code.\n")
  (insert "The same data renders the in-Emacs cheat sheet on `C-c ?`.\n")
  (insert "Regenerate after changing a binding:\n\n")
  (insert "```sh\nemacs --batch --eval \"(setq user-emacs-directory \\\"$PWD/\\\")\" \\\n")
  (insert "  -l early-init.el -l init.el -l scripts/gen-keyboard-doc.el\n```\n\n")

  (insert "## Terminal constraint\n\n")
  (insert "Emacs runs in tmux inside Ghostty. Control combined with punctuation\n")
  (insert "(`C-.` `C-;` `C-=` `C->` `C-:`) and Control-Shift-letter have **no legacy\n")
  (insert "terminal encoding** and cannot be transmitted. Nothing important is bound\n")
  (insert "to them. Every key below uses `C-c <letter>`, `C-x <letter>`, `M-<letter>`\n")
  (insert "or a function key, all of which a terminal can send.\n")

  (insert "\n## Prefixes\n\n| Prefix | Owns |\n|---|---|\n")
  (dolist (p mjb-key-prefixes)
    (insert (format "| `%s` | %s |\n" (car p) (cdr p))))
  (insert "| `C-c p` | project (`project-prefix-map`) |\n")
  (insert "| `C-x t` | tabs (Emacs's built-in `tab-prefix-map`) |\n")
  (insert "| `C-x g` | magit |\n")

  ;; Sections, from the shared grouping.
  (pcase-dolist (`(,title . ,rows) (mjb-keys-grouped))
    (mjb-gen--section title rows))

  (insert "\n## Deliberately NOT bound\n\n")
  (insert "| Key | Stays | Why |\n|---|---|---|\n")
  (dolist (r mjb-keys-unbound)
    (insert (format "| `%s` | `%s` | %s |\n" (nth 0 r) (nth 1 r) (nth 2 r))))

  (insert "\n## Mode-local keys\n\n")
  (insert "These live in their own mode maps and cannot collide with the table above.\n\n")
  (insert "| Mode | Key | Does |\n|---|---|---|\n")
  (dolist (r mjb-mode-local-keys)
    (insert (format "| %s | `%s` | %s |\n" (nth 0 r) (nth 1 r) (nth 2 r))))

  (insert (format "\n---\n\n%d global bindings, verified by `scripts/check-keys.el`.\n"
                  (length mjb-key-table))))

(princ (format "wrote KEYBOARD.md (%d bindings)\n" (length mjb-key-table)))
;;; gen-keyboard-doc.el ends here
