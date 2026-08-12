# Keyboard reference

**This file is generated — do not edit it by hand.**
It is produced from `mjb-key-table` in `lisp/mjb-keys.el` by
`scripts/gen-keyboard-doc.el`, so it cannot drift from the code.
Regenerate after changing a binding:

```sh
emacs --batch --eval "(setq user-emacs-directory \"$PWD/\")" \
  -l early-init.el -l init.el -l scripts/gen-keyboard-doc.el
```

## Terminal constraint

Emacs runs in tmux inside Ghostty. Control combined with punctuation
(`C-.` `C-;` `C-=` `C->` `C-:`) and Control-Shift-letter have **no legacy
terminal encoding** and cannot be transmitted. Nothing important is bound
to them. Every key below uses `C-c <letter>`, `C-x <letter>`, `M-<letter>`
or a function key, all of which a terminal can send.

## Prefixes

| Prefix | Owns |
|---|---|
| `C-c a` | ai |
| `C-c c` | code |
| `C-c s` | search |
| `C-c t` | toggle |
| `C-c p` | project (`project-prefix-map`) |
| `C-x t` | tabs (Emacs's built-in `tab-prefix-map`) |
| `C-x g` | magit |

### AI

| Key | Command | Does |
|---|---|---|
| `C-c a a` | `mjb-ai-chat` | Claude chat |
| `C-c a s` | `mjb-ai-complete` | Inline suggestion at point |
| `C-c a RET` | `mjb-ai-accept` | Accept suggestion |
| `C-c a m` | `mjb-ai-select-model` | Switch provider / model |
| `C-c a ?` | `mjb-ai-status` | Providers, models, credentials |
| `C-c a d` | `mjb-ai-dismiss` | Dismiss suggestion |

### Code

| Key | Command | Does |
|---|---|---|
| `C-c c d` | `xref-find-definitions` | Jump to definition |
| `C-c c r` | `xref-find-references` | Find references |
| `C-c c f` | `mjb-python-format-buffer` | Format buffer |
| `C-c c h` | `eldoc-doc-buffer` | Documentation at point |
| `C-c c e` | `flymake-show-buffer-diagnostics` | Diagnostics |
| `C-c c n` | `flymake-goto-next-error` | Next diagnostic |
| `C-c c p` | `flymake-goto-prev-error` | Previous diagnostic |

### Search

| Key | Command | Does |
|---|---|---|
| `C-c s s` | `consult-line` | Search this buffer |
| `C-c s r` | `consult-ripgrep` | Ripgrep the project |
| `C-c s i` | `consult-imenu` | Jump to a definition/section |
| `C-c s o` | `consult-outline` | Jump by outline heading |
| `C-c s f` | `consult-find` | Find a file by name |

### Toggles

| Key | Command | Does |
|---|---|---|
| `C-c t t` | `mjb-toggle-theme` | Light / dark theme |
| `C-c t l` | `display-line-numbers-mode` | Line numbers |
| `C-c t w` | `visual-line-mode` | Visual line wrapping |
| `C-c t s` | `flyspell-mode` | Spell checking |
| `C-c t f` | `flymake-mode` | Syntax checking |

### Motion

| Key | Command | Does |
|---|---|---|
| `M-g g` | `consult-goto-line` | Go to line |
| `M-g M-g` | `consult-goto-line` | Go to line |
| `M-g j` | `mjb-jump` | Jump to visible text |
| `M-s l` | `consult-line` | Search this buffer |
| `M-s r` | `consult-ripgrep` | Ripgrep the project |
| `M-/` | `hippie-expand` | Expand from context |

### Everything else

| Key | Command | Does |
|---|---|---|
| `C-c e` | `mjb-sidebar-toggle` | Toggle file sidebar |
| `C-c l` | `recenter-top-bottom` | Recenter (C-l alternative) |
| `C-c v` | `mjb-expand-region` | Expand region |
| `C-c V` | `mjb-contract-region` | Contract region |
| `C-c y` | `consult-yank-pop` | Yank from kill ring |
| `C-c g` | `magit-status` | Magit status |
| `C-c '` | `mjb-terminal` | Terminal (vterm or eshell) |
| `C-x g` | `magit-status` | Magit status |
| `C-x b` | `consult-buffer` | Switch buffer |
| `C-x 4 b` | `consult-buffer-other-window` | Switch buffer, other window |
| `C-x p t` | `mjb-tab-for-project` | Open project in its own tab |
| `C-?` | `mjb-undo-redo` | Redo |

## Deliberately NOT bound

| Key | Stays | Why |
|---|---|---|
| `M-y` | `yank-pop` | the old config's minuet took it; core muscle memory (R-063) |
| `M-l` | `downcase-word` | recenter lives on `C-c l` instead |
| `M-0` | `digit-argument` | treemacs had taken it; tabs use `C-x t <n>` |
| `C-.` `C-;` `C-=` `C->` `C-<` `C-S-c` | unbound | cannot be typed in this terminal (F-06) |

## Mode-local keys

These live in their own mode maps and cannot collide with the table above.

| Mode | Key | Does |
|---|---|---|
| LaTeX | `C-c C-c` | build with latexmk |
| LaTeX | `C-c C-v` | open the PDF |
| LaTeX | `C-c C-k` | clean aux files |
| LaTeX | `C-c C-t` | RefTeX table of contents |
| LaTeX | `C-c (` `C-c )` `C-c [` | RefTeX label / ref / cite |
| Claude chat buffer | `C-c C-c` `C-c C-k` | send / cancel |
| corfu | `TAB` `S-TAB` `RET` | next / previous / insert |
| vertico | `C-j` `C-k` | next / previous candidate |

---

41 global bindings, verified by `scripts/check-keys.el`.
