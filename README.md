# mjbommar-emacs

A terminal-first Emacs 30 configuration for writing books in LaTeX, with GUI
support, built from Emacs built-ins wherever a built-in exists.

**13 packages.** The previous version of this configuration had 85.

## Design

Three rules, in order:

1. **Built into Emacs 30** — always preferred, even where a package is nicer.
2. **Hand-written elisp** — if it is small enough to own.
3. **A package** — only when neither of the above works, with a comment saying
   what it does that a built-in cannot.

Emacs 30 already ships `use-package`, `which-key`, `eglot`, `project`,
`tab-bar`, `treesit`, `flymake`, `reftex`, `bibtex`, `completion-preview`,
`modus-themes` and more. Most of what a config used to install is now in the
box.

Everything is verifiable: `./scripts/smoke.sh` byte-compiles all 13 modules,
loads the whole configuration, and asserts every keybinding resolves to the
command it claims.

## Install

```sh
git clone https://github.com/mjbommar/mjbommar-emacs.git
cd mjbommar-emacs
./install.sh
```

`install.sh` **symlinks** `~/.emacs.d` to the checkout, so editing a module here
*is* editing your live configuration and `git status` shows your changes. An
existing `~/.emacs.d` is **moved aside with a timestamp, never deleted**, and
its `var/`, `etc/` and `eln-cache/` are carried forward. Running it twice is a
no-op.

Try it without installing anything:

```sh
emacs --init-directory=$PWD -nw
```

### Prerequisites

Emacs 30+ built with native compilation and tree-sitter. On Ubuntu:

```sh
sudo apt install emacs-pgtk        # terminal + GUI; emacs-nox has no GUI at all
```

Everything below is optional; the config degrades cleanly without each one and
`install.sh` tells you which are missing.

| Tool | Enables | Install |
|---|---|---|
| `latexmk`, texlive | LaTeX builds | `sudo apt install latexmk texlive` |
| `ripgrep` | project search | `cargo install ripgrep` |
| `ruff` | Python lint + format | `uv tool install ruff` |
| `aspell` + `aspell-en` | spell checking | `sudo apt install aspell aspell-en` |
| `libtool`, `cmake` | vterm's C module | `sudo apt install libtool libtool-bin cmake` |

### One-time setup

```
M-x mjb-install-treesit-grammars     # python, c, bash, json, yaml, toml, markdown
```

## Credentials

Emacs reads API keys from `~/.authinfo.gpg` via `auth-source`. It never reads
them from the process environment.

```
machine api.anthropic.com login apikey password sk-ant-...
```

> **If you are migrating from the previous config:** it relied on
> `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` and `GEMINI_API_KEY` being exported in
> `~/.bashrc`. Plaintext keys in a shell rc file are inherited by every process
> you start and readable from `/proc/<pid>/environ`. **Rotate those keys**, put
> the new ones in `~/.authinfo.gpg`, and delete the exports. Nothing in this
> config needs them anymore.

## Layout

```
early-init.el     GC, native compilation, package paths, frame
init.el           loader only (70 lines)
lisp/
  mjb-core.el       defaults, backups, auto-save, auth-source, OSC 52 clipboard
  mjb-ui.el         modus theme, hand-written modeline, tab-bar, fonts
  mjb-completion.el vertico, orderless, marginalia, consult, corfu, cape
  mjb-editing.el    region expansion, jump-to-text, undo
  mjb-vc.el         magit, diff-hl (margin mode for the terminal)
  mjb-project.el    project.el, ripgrep, dired sidebar
  mjb-prose.el      text/markdown, flyspell
  mjb-latex.el      tex-mode + reftex + latexmk -- no AUCTeX
  mjb-python.el     ruff format + lint, optional eglot, .venv detection
  mjb-formats.el    json/toml/yaml/csv/org, tree-sitter grammars
  mjb-shell.el      vterm, eshell
  mjb-ai.el         gptel, minuet
  mjb-keys.el       THE keybinding table
scripts/
  smoke.sh              byte-compile + load + key check
  check-keys.el         asserts no collisions and no dead bindings
  gen-keyboard-doc.el   regenerates KEYBOARD.md
```

To change something, the module names are the map. Global keys live **only** in
`mjb-keys.el`, so a collision is a diff rather than a surprise.

`load-prefer-newer` is on, so editing a module and restarting picks up your
change even if a stale `.elc` is sitting next to it. Run `M-x mjb-recompile`
when you want the compiled speed back.

## Keys

See [KEYBOARD.md](KEYBOARD.md) — it is **generated** from the key table, so it
cannot drift from the code.

The short version: `C-c a` AI, `C-c c` code, `C-c s` search, `C-c t` toggles,
`C-c p` project, `C-c e` file sidebar, `C-x t` tabs, `C-x g` magit.

Nothing important is bound to `C-.` `C-;` `C-=` `C->` or Control-Shift-letter:
those have no legacy terminal encoding and cannot be transmitted through tmux.

## LaTeX

The largest feature, and it uses **no packages at all** — `tex-mode`, `reftex`,
`bibtex`, `compile` and `outline` are built into Emacs. AUCTeX is ~50,000 lines
and is not needed; RefTeX is standalone.

| Key | Does |
|---|---|
| `C-c C-c` | build the master document with `latexmk`, asynchronously |
| `C-c C-v` | open the resulting PDF |
| `C-c C-t` | table of contents across every `\input` file |
| `C-c (` `C-c )` `C-c [` | insert label / reference / citation |

Multi-file projects work: editing `sections/01_introduction.tex` builds
`main.tex`. The master is found by walking up for a file containing
`\documentclass`. Build errors are navigable because `latexmk -file-line-error`
emits `./file.tex:12: message`, which Emacs's built-in `gnu` compilation rule
already parses.

## Terminal notes

The primary environment is `emacs -nw` inside tmux inside Ghostty.

- **Clipboard** is OSC 52: no helper binary, works through tmux, works over SSH.
  It is write-only — pasting *into* Emacs stays the terminal's job
  (`Ctrl-Shift-V` or middle click). That asymmetry is inherent to OSC 52.
- **24-bit colour** works via `COLORTERM=truecolor`. If that variable is not
  propagated (over SSH, under `sudo`), Emacs falls back to 256 colours and the
  config says so at startup instead of just looking flat.
- **Fonts** are Ghostty's business in the terminal. Emacs font settings apply
  only to GUI frames and only if the family is actually installed.
- **Completion popups** need a child frame, which a tty does not have before
  Emacs 31. Corfu falls back to the built-in `*Completions*` buffer there
  automatically; no extra package is needed.

## Verify

```sh
./scripts/smoke.sh
```

Checks that all 13 modules byte-compile with zero warnings, that the whole
configuration loads with no errors, and that every declared keybinding resolves
to the command it claims — including that `M-y` is still `yank-pop`.

## Requirements and rationale

[`docs/requirements/`](docs/requirements/) documents what the previous
configuration did, what the on-disk evidence said was actually being used, the
defects found, and a numbered requirement for each with an acceptance test.
Read [`03-findings.md`](docs/requirements/03-findings.md) first if you want the
short version of why this was rebuilt.
