# 06 — Keybinding requirements and proposed map

Satisfies `R-030` – `R-035`. The map below is a **proposal**; the constraints
above it are requirements.

## Constraints

### C1 · Terminal-typeable only, for anything that matters

Emacs runs in `screen-256color` inside tmux inside Ghostty. In the legacy
terminal input encoding, Control combined with punctuation and
Control-Shift-letter have **no representation**. Extended encodings exist (Kitty
keyboard protocol, xterm `modifyOtherKeys`), and Ghostty implements the former,
but Emacs 30 does not decode it without an add-on and tmux does not forward it
by default.

**Verify before finalising.** In the real terminal, for each key: `C-h k`, press
it, read the echo area. If it reports the plain character or nothing, the key is
unavailable.

Keys currently bound that must be checked: `C-.` `C-;` `C-:` `C-'` `C-=` `C->`
`C-<` `C-S-c C-S-c` `C-c C-<return>`.

Safe by construction: `C-c <letter>`, `C-c <letter> <letter>`, `C-x <letter>`,
`M-<letter>`, `M-g <letter>`, `M-s <letter>`, `C-<letter>` for letters (these
map to C0 control codes), function keys.

### C2 · One owner per prefix

`F-03` (`C-c t`) and `F-04` (`C-c p`) both stem from two packages claiming one
prefix. The table below is the authority; a package's own `:bind` may not add
global keys.

### C3 · Do not silently take standard bindings

Three are taken today without documentation: `M-y` (`yank-pop`), `M-l`
(`downcase-word`), `M-0` (`digit-argument`). Any rebinding of a default must be
listed here with a reason.

### C4 · `C-c <letter>` is reserved for the user by convention

Emacs reserves `C-c` followed by a plain letter for user bindings; modes use
`C-c C-<letter>`. The map respects this, which is why mode packages keep their
own `C-c C-…` keys (AUCTeX's `C-c C-c`, python's `C-c C-p`) without conflict.

---

## Proposed global map

### Prefix allocation

| Prefix | Owner | Rationale |
|---|---|---|
| `C-c a` | AI | new; `a` for AI |
| `C-c c` | Code / LSP | as today (`C-c c` hydra becomes a plain prefix) |
| `C-c p` | Project | `project.el` — **sole owner**, resolves `F-04` |
| `C-c s` | Search | consolidates the `M-s` set into a discoverable prefix |
| `C-c t` | Toggles | **sole owner**, resolves `F-03`; centaur-tabs is gone |
| `C-x g` | Magit | as today |
| `C-x t` | Treemacs | as today, on demand only |

### Files, buffers, windows — unchanged Emacs defaults

`C-x C-f`, `C-x C-s`, `C-x C-c`, `C-x k`, `C-x b`, `C-x 4 b`, `C-x 0/1/2/3`,
`C-x o`. No change; these are muscle memory and terminal-safe.

### Navigation and search

| Key | Command | Note |
|---|---|---|
| `C-s` / `C-r` | isearch forward/backward | default |
| `M-g g` | `consult-goto-line` | `goto-line` is in your history |
| `C-c s l` | `consult-line` | was `M-s l`; `M-s l` retained as alias |
| `C-c s r` | `consult-ripgrep` | was `M-s r`; `rg` is installed |
| `C-c s f` | `consult-find` | note: `fd` not installed; falls back to `find` |
| `C-c s i` | `consult-imenu` | **new** — structure navigation, matters for LaTeX |
| `C-x b` | `consult-buffer` | as today |
| `M-g j` | `avy-goto-char-timer` | **replaces** `C-:` / `C-'`, which fail C1 |

`avy-goto-char-timer` is a better fit than `avy-goto-char-2` anyway: type as
many characters as you need, then pick. One binding replaces two.

### Editing

| Key | Command | Note |
|---|---|---|
| `C-/` | `undo` | default; `C-/` is C0-safe (it is `C-_`) |
| `C-?` | `undo-redo` | replaces undo-tree redo (`R-023`) |
| `M-y` | `yank-pop` | **restored** (`R-063`); was minuet |
| `C-c y` | `consult-yank-pop` | replaces `C-M-y` |
| `C-c v` | `er/expand-region` | replaces `C-=`, which fails C1 |
| `C-c l` | `recenter-top-bottom` | as today |
| `M-l` | `downcase-word` | **restored**; recenter keeps `C-c l` |
| `C-c #` | `mc/mark-next-like-this` | only if multiple-cursors is kept; `C->` fails C1 |

Multiple cursors is a judgement call: its three primary keys all fail C1 and
there is no evidence of use. Recommendation is to drop it and use
`query-replace` plus keyboard macros, but it is your call.

### Toggles — `C-c t`

| Key | Toggles |
|---|---|
| `C-c t t` | theme light/dark (was `C-c T`) |
| `C-c t l` | `display-line-numbers-mode` |
| `C-c t w` | `visual-line-mode` |
| `C-c t s` | `flyspell-mode` / `jinx-mode` |
| `C-c t a` | minuet auto-suggestion (was `C-c m`) |
| `C-c t f` | `flymake-mode` |

### Code — `C-c c`

Active only where an LSP or xref backend is present.

| Key | Command |
|---|---|
| `C-c c d` | `xref-find-definitions` |
| `C-c c r` | `xref-find-references` |
| `C-c c n` | `eglot-rename` |
| `C-c c a` | `eglot-code-actions` |
| `C-c c f` | format buffer (mode-appropriate) |
| `C-c c h` | `eldoc-doc-buffer` |
| `M-.` / `M-,` | `xref-find-definitions` / `xref-go-back` |

`M-.` and `M-,` are Emacs 30 defaults and work with eglot without `smart-jump`,
which is removed (last release 2021).

The `hydra-code` menu is replaced by the plain prefix plus which-key. A hydra
buys a transient overlay; which-key already shows the same information and there
is one fewer package.

### Project — `C-c p`

`project-prefix-map`, sole owner. `C-c p f` find file, `C-c p p` switch project,
`C-c p g` ripgrep, `C-c p c` compile, `C-c p b` buffer. Cape's completion
commands move off this prefix entirely — `completion-at-point` is on `C-M-i`
(the Emacs default) and the individual cape backends are added to
`completion-at-point-functions` rather than bound to keys.

That last point matters: the nine cape bindings in `KEYBOARD.md` are dead today
(`F-04`), and binding each backend to a key was never the intended usage.
Adding them to the capf list gives them to you through normal completion.

### AI — `C-c a`

| Key | Command |
|---|---|
| `C-c a a` | `gptel` — new chat |
| `C-c a s` | `gptel-send` (was `C-c RET`) |
| `C-c a m` | `gptel-menu` (was `C-c C-<return>`, which fails C1) |
| `C-c a i` | `minuet-show-suggestion` (was `M-i`) |
| `C-c a c` | `minuet-complete-with-minibuffer` (was `M-y` — see `R-063`) |
| `C-c a t` | toggle minuet auto-suggestion (alias of `C-c t a`) |

When a minuet suggestion is showing, `minuet-active-mode-map` keeps its own
`M-a` / `M-A` / `M-n` / `M-p` / `M-e` — those are Meta-letter, C1-safe, and
active only transiently.

`C-c RET` is retained as an alias for `gptel-send` if you prefer it; `RET` after
`C-c` is terminal-safe.

### Version control

`C-x g` magit status. Unchanged.

### LaTeX (mode-local, `mjb-latex.el`)

Whichever backend is chosen, it keeps its native `C-c C-…` keys — AUCTeX's
`C-c C-c` (compile), `C-c C-v` (view), `C-c C-e` (environment), `C-c C-s`
(section), `C-c C-l` (output buffer), and RefTeX's `C-c =` (TOC), `C-c (`
(label), `C-c )` (ref), `C-c [` (cite). These are mode-local and cannot collide
with the global table.

Note `C-c =`, `C-c (`, `C-c )`, `C-c [` are `C-c` + punctuation, not Control +
punctuation — they are two separate keystrokes and are terminal-safe.

---

## Bindings removed, with reason

| Removed | Reason |
|---|---|
| `C-c t p/n/</>/s/g/k/o` | centaur-tabs removed (`R-040`) |
| `C-c T` | folded into `C-c t t` |
| `C-c d/D/r/i/t/n/a/f/h` | eglot map; folded into `C-c c` (also resolves `F-03`) |
| `C-c p d/f/k/s/l/w/a/h` | cape; were already dead (`F-04`) |
| `C-.` `C-;` `C-h B` | embark; fails C1. Consider re-adding if the C1 test passes |
| `C-:` `C-'` | avy; replaced by `M-g j` |
| `C-=` | replaced by `C-c v` |
| `C->` `C-<` `C-S-c C-S-c` | multiple-cursors; fails C1 |
| `C-M-y` | replaced by `C-c y` |
| `M-l` | restored to `downcase-word` |
| `M-0` | restored to `digit-argument`; treemacs keeps `C-x t` |
| `M-i` `M-y` | minuet; moved to `C-c a` |
| `C-c m` `C-c M` | minuet; moved to `C-c a` / `C-c t` |

## Open questions for you

1. **Is `emacs -nw` the only environment, or do you also use GUI Emacs?** If
   GUI is used, several C1-failing bindings can come back under a
   `display-graphic-p` guard.
2. **Do you use embark or multiple-cursors?** Neither appears in any history
   file, and both are heavily affected by C1. If you do use them, they need
   terminal-safe keys.
3. **Is `C-l` genuinely intercepted by Ghostty?** Commit `aca0e7e` says so, but
   Ghostty's config has no `keybind` entries. If `C-l` reaches Emacs, `C-c l`
   and `M-l` are both unnecessary and `M-l` returns to `downcase-word` for free.
