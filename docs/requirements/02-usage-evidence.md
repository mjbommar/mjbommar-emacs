# 02 — What is actually being used

This is the document the requirements rest on. Every claim here comes from state
Emacs wrote to disk on its own, not from the README and not from inference.

## Sources

| Source | What it records |
|---|---|
| `var/recentf-save.el` | 20 most recently opened files |
| `var/save-place.el` | 78 files with a saved point position — a longer history than recentf |
| `var/savehist.el` | minibuffer histories: `extended-command-history` (M-x), `file-name-history`, `buffer-name-history`, `search-ring`, `consult--buffer-history`, `goto-line-history` |
| `var/projectile/` | empty |
| `etc/yasnippet/snippets/` | empty |
| `etc/eshell/` | empty |
| live process table | what Emacs is running as, right now |

## 1. The primary workload is long-form writing in LaTeX

`recentf` extension histogram (all 20 entries):

```
8  .tex
3  .md
2  .sh
2  .astro
1  .txt   1 .py   1 .c   1 .bashrc
```

`save-place` (78 entries) is dominated by the same shape: chapter files under
`latex/chapters/`, `paper/sections/`, `book/latex/frontmatter/`, plus `main.tex`
in four different projects.

The projects appearing across both files:

- four long-form **book** projects (LaTeX), each `main.tex` plus a
  `chapters/` or `latex/` subdirectory
- one **paper** project (LaTeX: `main.tex` with `sections/00_abstract.tex`,
  `sections/01_introduction.tex`)
- one book with generated content (`generated/metadata.tex`) and one with
  CSV-driven build outputs
- one static site (Astro)
- one **C** project: a kernel-patch reproduction directory
- two **Python** codebases, one of them with Markdown documentation alongside

Project names are omitted throughout this document: several are unpublished
work and one is client work. The shapes are what the analysis depends on, and
the shapes are all here.

**At the moment of writing this document, the running Emacs process is `emacs
main.tex`.** That is the single strongest signal in the whole review.

The configuration contains **zero** LaTeX support. `.tex` files open in the
built-in `latex-mode` from `tex-mode.el` with no completion source, no build
command, no error navigation, no `reftex`, no PDF viewing, and no
`outline`-style structure navigation — despite 33 texlive packages,
`pdflatex`, and `latexmk` being installed on the machine.

## 2. Python is real but secondary; Rust is absent

Python appears in `save-place`: six files across three projects, in the usual
`src/`, `tasks/` and top-level-module shapes. `uv` is installed and
`pyproject.toml` exists in a dozen personal projects.

**No `.rs` file appears in recentf, save-place, or file-name-history.** The
config carries `rust-mode`, `cargo`, `flycheck-rust` (and `flycheck` itself,
solely as their dependency) plus a `rust-mode` eglot hook and
`doom-modeline-env-enable-rust`.

C appears once, in a kernel-patch reproduction directory — enough to justify
keeping `c-mode` sane, not enough to justify an LSP stack.

## 3. The editing style is plain and light

`extended-command-history` — every `M-x` command ever run under this config:

```
"visual-line-mode" "goto-line" "visual-line-mode"
```

Three entries. Two distinct commands. Both are prose-editing commands.

`search-ring` holds seven entries, all plain content searches inside prose and
code — a mix of English phrases and C identifiers, no regexps. The terms
themselves are not reproduced here; what matters is that every one is a
*content* search rather than a structural or symbol lookup.

`consult--buffer-history` has two entries, both from the C work.
`buffer-name-history` has one. `goto-line-history` has one.

The reading is: this Emacs is used as a careful, fast text editor. It is not
being driven as an IDE, and the elaborate discovery machinery (hydra menu,
Embark, multiple cursors, treemacs, tabs) shows no trace of use in any history
file. That is not proof it is unused — those commands are bound to keys and
would not appear in `M-x` history — but combined with §4 below it is
suggestive.

## 4. Much of the UI cannot function in this environment

Emacs runs in a terminal. These are configured and loaded but are either
degraded or inert:

| Component | What happens in `emacs -nw` |
|---|---|
| `all-the-icons`, `nerd-icons` | Guarded by `:if (display-graphic-p)` — **never loaded**. |
| `doom-modeline` | Loads, but with `doom-modeline-icon t` and no icon package present. Falls back to unicode. |
| `centaur-tabs` | `centaur-tabs-style "rounded"`, `-set-icons t`, `-icon-type 'nerd-icons`, `-height 32` — the style and height are graphical concepts; icons resolve to nothing. |
| `kind-icon` | SVG icon margin formatter for corfu. No SVG in a terminal. |
| `dashboard` | `dashboard-startup-banner 'logo`, `-set-file-icons t`. Also never seen: Emacs is launched as `emacs <file>`, which bypasses the startup screen entirely. |
| `treemacs` | Functional but cramped; `treemacs-width 30` on an 80–120 column terminal. |
| Font settings | `JetBrains Mono` at height 120 has no effect. The terminal renders in Berkeley Mono 11 per Ghostty config. |
| Theme | Hard-coded `doom-one` (dark). Ghostty is configured `light:Catppuccin Latte,dark:Catppuccin Mocha` — i.e. it follows the system light/dark preference. Emacs does not. |

## 5. Clipboard integration is dead code

Lines 62–77 install `interprogram-cut-function` / `interprogram-paste-function`
wrappers around `xclip`, guarded by `(executable-find "xclip")`.

**`xclip` is not installed.** The guard fails, the block does nothing, and
terminal Emacs has no route to the system clipboard. This is the *most recently
added* feature (`ace6b06`, "better copy/paste integration") and it has never
worked on this machine.

What is available instead: tmux is configured `set-clipboard external`, meaning
it forwards OSC 52 escape sequences from applications to Ghostty. Ghostty
supports OSC 52. The correct mechanism here is OSC 52, not `xclip` — and it
works over SSH too, which `xclip` cannot.

Ghostty also has `copy-on-select = true`, so selecting with the mouse already
copies; that path is unaffected by any of this.

## 6. AI features: both models are past their retirement dates

| Integration | Configured model | Status on 2026-08-11 |
|---|---|---|
| gptel | `claude-opus-4-1-20250805` | Deprecated, **retired 2026-08-05** — six days ago |
| minuet | `claude-sonnet-4-20250514` | Deprecated, **retired 2026-06-15** |

Both API keys are present in the environment (`ANTHROPIC_API_KEY`,
`OPENAI_API_KEY`, `GEMINI_API_KEY`). Requests to a retired model ID return 404,
so both integrations are currently non-functional regardless of key validity.

Note also that the README claims minuet defaults to Opus 4.1 while `init.el`
actually sets Sonnet 4 — documentation and code disagree.

Minuet auto-suggestion was deliberately turned off in the most recent commit
(`54ea9ff`), with a `C-c m` toggle added. That is a clear signal: inline
completion is wanted on demand, not ambiently.

## 7. Two developer conveniences are known-broken

- `python-black-on-save-mode-enable-dwim` is hooked into `python-mode`, but
  `black` is not installed. `ruff` *is* installed, and a `ruff-format`
  reformatter is defined in the config — but never bound to anything or hooked
  to any mode.
- `eglot` is hooked into `python-mode`, but `pyright` is not installed. Every
  Python buffer attempts an LSP connection that cannot succeed.
- `markdown-command` is set to `multimarkdown`, falling back to `pandoc` if
  present. Neither is installed, so `markdown-preview` and any export are dead.
- `eglot-server-programs` gains a `markdown-mode → marksman` entry; `marksman`
  is not installed.

## 8. What the evidence supports keeping

Ranked by strength of evidence:

1. **LaTeX authoring** — strongest signal, currently entirely unsupported.
2. **Markdown authoring** — `.md` is second by count; `CLAUDE.md`, docs, notes.
3. **Fast in-buffer navigation and search** — `goto-line`, isearch, consult.
4. **`visual-line-mode`** — the only command run by name, twice. Prose wrapping matters.
5. **Python editing** — real files, real projects, but light-touch.
6. **Git** — every project is a git repo; magit is the plausible interface even
   though it leaves no savehist trace.
7. **Shell/terminal access from Emacs** — plausible but unevidenced (`eshell`
   history file is empty; vterm keeps no history file).
8. **AI chat (gptel) and on-demand completion (minuet)** — deliberately
   configured and deliberately tuned in the last commit, so they are wanted;
   they just need working model IDs.

## 9. What the evidence does not support keeping

| Feature | Evidence against |
|---|---|
| Rust toolchain (`rust-mode`, `cargo`, `flycheck-rust`, `flycheck`) | No `.rs` file in any history |
| `centaur-tabs` | Terminal; graphical styling; also owns the `C-c t` prefix that collides with eglot |
| `dashboard` | Never displayed — Emacs is launched with a file argument |
| `all-the-icons` / `nerd-icons` / `kind-icon` | Guarded off or inert in a terminal |
| `treesit-auto` | Zero grammars installed; contributes nothing |
| `projectile` (pulled in via `treemacs-projectile` and the centaur-tabs grouping call) | `project.el` is the configured project system; projectile's state dir is empty |
| `smart-jump` | Last released 2021; `xref` + eglot cover `M-.`/`M-,` natively in Emacs 30 |
| `undo-tree` | Emacs 28+ has `undo-redo`; `undo-tree` writes history files and is a common source of slowdowns on large buffers |
| `smartparens` | Duplicates `electric-pair-mode`, which is also on — see `F-05` |
| `json-navigator`, `markdown-preview-mode`, `eshell-syntax-highlighting`, `org-bullets` | No trace of use; two of them depend on missing binaries |
| `multiple-cursors`, `expand-region`, `embark`, `hydra` | Bound to keys that mostly cannot be typed in this terminal — see `F-06` |
