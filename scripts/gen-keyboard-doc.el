;;; gen-keyboard-doc.el --- Generate KEYBOARD.md from the key table -*- lexical-binding: t -*-
;;; Commentary:
;; Implements R-080.  KEYBOARD.md is GENERATED from `mjb-key-table', so the
;; documentation cannot drift from the code.  The previous hand-written
;; KEYBOARD.md documented five bindings that did not work, including nine cape
;; commands that were shadowed and dead (F-04).
;;
;; Usage:  emacs --batch ... -l scripts/gen-keyboard-doc.el
;;; Code:

(require 'mjb-keys)

(defun mjb-gen--section (title rows)
  (when rows
    (insert (format "\n### %s\n\n| Key | Command | Does |\n|---|---|---|\n" title))
    (dolist (r rows)
      (insert (format "| `%s` | `%s` | %s |\n" (nth 0 r) (nth 1 r) (nth 2 r))))))

(defun mjb-gen--match (prefix)
  (seq-filter (lambda (e) (string-prefix-p prefix (car e))) mjb-key-table))

(with-temp-file (expand-file-name "KEYBOARD.md" user-emacs-directory)
  (insert "# Keyboard reference\n\n")
  (insert "**This file is generated — do not edit it by hand.**\n")
  (insert "It is produced from `mjb-key-table` in `lisp/mjb-keys.el` by\n")
  (insert "`scripts/gen-keyboard-doc.el`, so it cannot drift from the code.\n")
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

  (mjb-gen--section "AI" (mjb-gen--match "C-c a"))
  (mjb-gen--section "Code" (mjb-gen--match "C-c c"))
  (mjb-gen--section "Search" (mjb-gen--match "C-c s"))
  (mjb-gen--section "Toggles" (mjb-gen--match "C-c t"))
  (mjb-gen--section "Motion"
                    (seq-filter (lambda (e) (string-prefix-p "M-" (car e))) mjb-key-table))
  (mjb-gen--section
   "Everything else"
   (seq-remove (lambda (e)
                 (or (string-prefix-p "M-" (car e))
                     (seq-some (lambda (p) (string-prefix-p p (car e)))
                               '("C-c a" "C-c c" "C-c s" "C-c t"))))
               mjb-key-table))

  (insert "\n## Deliberately NOT bound\n\n")
  (insert "| Key | Stays | Why |\n|---|---|---|\n")
  (insert "| `M-y` | `yank-pop` | minuet had taken it; core muscle memory (R-063) |\n")
  (insert "| `M-l` | `downcase-word` | recenter lives on `C-c l` instead |\n")
  (insert "| `M-0` | `digit-argument` | treemacs had taken it; tabs use `C-x t <n>` |\n")
  (insert "| `C-.` `C-;` `C-=` `C->` `C-<` `C-S-c` | unbound | cannot be typed in this terminal (F-06) |\n")

  (insert "\n## Mode-local keys\n\n")
  (insert "These live in their own mode maps and cannot collide with the table above.\n\n")
  (insert "| Mode | Key | Does |\n|---|---|---|\n")
  (insert "| LaTeX | `C-c C-c` | build with latexmk |\n")
  (insert "| LaTeX | `C-c C-v` | open the PDF |\n")
  (insert "| LaTeX | `C-c C-k` | clean aux files |\n")
  (insert "| LaTeX | `C-c C-t` | RefTeX table of contents |\n")
  (insert "| LaTeX | `C-c (` `C-c )` `C-c [` | RefTeX label / ref / cite |\n")
  (insert "| minuet (while a suggestion shows) | `M-a` `M-A` `M-n` `M-p` `M-e` | accept line / all / next / prev / dismiss |\n")
  (insert "| corfu | `TAB` `S-TAB` `RET` | next / previous / insert |\n")
  (insert "| vertico | `C-j` `C-k` | next / previous candidate |\n")

  (insert (format "\n---\n\n%d global bindings, verified by `scripts/check-keys.el`.\n"
                  (length mjb-key-table))))

(princ (format "wrote KEYBOARD.md (%d bindings)\n" (length mjb-key-table)))
;;; gen-keyboard-doc.el ends here
