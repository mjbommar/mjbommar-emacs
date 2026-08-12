# mjbommar-emacs

A terminal-first Emacs 30 configuration for writing books in LaTeX, with GUI
support, built from Emacs built-ins wherever a built-in exists.

**10 packages.** The previous version of this configuration had 85.

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

Everything is verifiable: `./scripts/smoke.sh` byte-compiles all 16 modules,
loads the whole configuration, and asserts every keybinding resolves to the
command it claims.

## Install

New machine or server, one line:

```sh
git clone https://github.com/mjbommar/mjbommar-emacs.git ~/src/mjbommar-emacs && ~/src/mjbommar-emacs/install.sh --yes
```

Deliberately not `curl … | sh`: this clones first, so the code that is about to
run on your machine is on disk and reviewable before it runs, and the same
checkout is what you keep.

That single command installs the 10 packages (verifying every signature),
builds the tree-sitter grammars, verifies the whole configuration loads, and
tells you which optional tools are missing. On a fresh Debian/Ubuntu box the
only prerequisites are:

```sh
sudo apt install emacs-pgtk git gnupg build-essential
```

`gnupg` is required, not optional — package signatures are enforced and Emacs
degrades silently without it, so `install.sh` refuses to run rather than
pretend to verify.

`install.sh` **symlinks** `~/.emacs.d` to the checkout, so editing a module here
*is* editing your live configuration and `git status` shows your changes. An
existing `~/.emacs.d` is **moved aside with a timestamp, never deleted**, and
its `var/`, `etc/` and `eln-cache/` are carried forward. Running it twice is a
no-op. `--dry-run` prints what it would do; `--target DIR` installs elsewhere.

To update later: `git -C ~/src/mjbommar-emacs pull`.

Try it without installing anything:

```sh
emacs --init-directory=$PWD -nw
```

### Prerequisites

| | |
|---|---|
| **Required** | `emacs` 30+ (with native compilation and tree-sitter), `git`, `gnupg` |
| **For grammars** | a C compiler (`build-essential`); without one, tree-sitter modes fall back and say so |

```sh
sudo apt install emacs-pgtk git gnupg build-essential
```

`emacs-pgtk` gives terminal *and* GUI; `emacs-nox` has no GUI at all.

Everything below is optional. The configuration degrades cleanly without each
one, and `install.sh` lists exactly which are missing on this machine.

| Tool | Enables | Install |
|---|---|---|
| `latexmk` + texlive | LaTeX builds | `sudo apt install latexmk texlive` |
| `aspell` + `aspell-en` | spell checking | `sudo apt install aspell aspell-en` |
| `ripgrep` | project search | `sudo apt install ripgrep` |
| `uv` | Python environments | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| `ruff` | Python lint + format | `uv tool install ruff` |
| `ty` | Python types + LSP | `uv tool install ty` |
| `rust-analyzer`, `rustfmt` | Rust LSP + format | `rustup component add rust-analyzer rustfmt` |
| `clangd` | C LSP | `sudo apt install clangd` |

### One-time setup

None — `install.sh` installs the tree-sitter grammars (python, rust, c, bash,
json, yaml, toml, markdown). `M-x mjb-install-treesit-grammars` re-runs it if a
grammar is added or a build failed.

## AI: multi-provider, no packages

`lisp/mjb-ai.el` (590 lines, 456 excluding comments) replaces gptel + minuet
while keeping the multi-provider support they had. Three wire formats cover
essentially everything:

| Wire | Endpoint | Providers |
|---|---|---|
| `anthropic` | `/v1/messages` | Claude |
| `openai` | `/v1/chat/completions` | OpenAI, xAI, vLLM, Ollama, llama.cpp, LM Studio, TGI, OpenRouter, Together, … |
| `gemini` | `:streamGenerateContent` | Google |

Shipped and live-tested: `anthropic`, `openai`, `xai`, `gemini`, `ollama`.
`C-c a p` switches provider (each carries its own default models);
`C-c a m` picks an exact model; **model lists are fetched from each
provider's `/models` endpoint**, so the picker never goes stale.

Provider and model are two variables, so `C-c a p` sets both — switching
provider alone would leave the previous provider's model name selected, which
the new provider then rejects. Defaults as of 2026-08, each verified against
the provider's live API:

| Provider | Chat | Completion (latency-bound) |
|---|---|---|
| `anthropic` | `claude-opus-5` | `claude-haiku-4-5` |
| `openai` | `gpt-5.6-sol` | `gpt-5.6-luna` |
| `xai` | `grok-4.5` | `grok-4.3` |
| `gemini` | `gemini-3.6-flash` | `gemini-3.5-flash-lite` |
| `ollama` | asked, from the server's own `/models` | ” |

These are a starting point, not a pin. Two places where the wire format differs
per model, both found by actually calling the APIs rather than by reading docs:

- GPT-5.x rejects `max_tokens` outright and wants `max_completion_tokens`;
  every other OpenAI-compatible server still wants `max_tokens`.
- Gemini 3.x rejects `thinkingBudget` with a bare 400 naming no field, and
  takes `thinkingLevel`; 2.x is the other way round. Unversioned aliases like
  `gemini-flash-latest` resolve to 3.x, so the version test matches the *old*
  generations and lets everything else default forward.

Add a vLLM box or any other OpenAI-compatible server:

```elisp
(mjb-ai-add-openai-compatible 'gpu-box
  "http://gpu-box.local:8000/v1/chat/completions")          ; no auth, model asked
(mjb-ai-add-openai-compatible 'gpu-box
  "http://gpu-box.local:8000/v1/chat/completions"
  nil "Qwen/Qwen3-Coder-30B-A3B-Instruct")                  ; served model as default
(mjb-ai-add-openai-compatible 'together
  "https://api.together.xyz/v1/chat/completions" "TOGETHER_API_KEY")
```

## Package trust

`package-check-signature` is `t`, not Emacs's default `allow-unsigned` — which
verifies a signature when one is present and silently accepts the package when
it is not, so an archive that stops signing downgrades you without a word.

**All 16 installed packages are signed** by the GNU/NonGNU ELPA keys and were
verified on install. There is no exception: `package-unsigned-archives` is
empty. It briefly held `"melpa"` — which signs nothing, because it builds from
upstream git on its own servers — but dropping vterm removed the last MELPA
package and with it the need for the carve-out.

MELPA is not listed at all. It publishes no signatures — its
`archive-contents.sig` is a 404 — so under this policy every refresh failed
against it with `Failed to download 'melpa' archive`, including on the first run
of a new machine. An archive you have made unusable buys nothing and looks like
a broken install. Taking a MELPA package deliberately means adding it back
*and* exempting it: two reviewable lines, not a silent default.

`scripts/count-packages.el` fails if the check is weakened, if any exempt
archive is added, or if any installed package turns up unsigned.

```
M-x mjb-check-signatures     ; reads the .signed files package.el wrote
```

That reads evidence rather than restating policy. Verification needs `gpg` on
`PATH`; without it the check degrades silently, so the config says so at startup
instead of appearing to verify when it isn't.

## Credentials

`auth-source` (`~/.authinfo.gpg`) first, then the provider's environment
variable — so your existing `*_API_KEY` exports keep working while you migrate.

```
machine api.anthropic.com login apikey password sk-ant-...
machine api.openai.com    login apikey password sk-proj-...
```

`C-c a ?` shows every provider and whether its credential resolves from
authinfo, env, or not at all.

> **If you are migrating from the previous config:** it relied on
> `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` and `GEMINI_API_KEY` being exported in
> `~/.bashrc`. Plaintext keys in a shell rc file are inherited by every process
> you start and readable from `/proc/<pid>/environ`. **Rotate those keys**, put
> the new ones in `~/.authinfo.gpg`, and delete the exports. Nothing in this
> config needs them anymore.

## Layout

```
early-init.el     GC, native compilation, package paths, frame
init.el           loader only (57 lines)
lisp/
  mjb-package.el    declared package set, lockfile, pruning
  mjb-core.el       defaults, backups, auto-save, auth-source, OSC 52 clipboard
  mjb-ui.el         modus theme, hand-written modeline, tab-bar, fonts
  mjb-completion.el vertico, orderless, marginalia, consult, corfu, cape
  mjb-editing.el    region expansion, jump-to-text, undo
  mjb-vc.el         magit, diff-hl (margin mode for the terminal)
  mjb-project.el    project.el, ripgrep, dired sidebar
  mjb-prose.el      text/markdown, flyspell
  mjb-latex.el      tex-mode + reftex + latexmk -- no AUCTeX
  mjb-python.el     ruff format + lint, optional eglot
  mjb-rust.el       rust-ts-mode, rustfmt, cargo, rust-analyzer, .venv detection
  mjb-formats.el    json/toml/yaml/csv/org, tree-sitter grammars
  mjb-shell.el      eshell + ansi-term (built-in; no packages)
  mjb-ai.el         multi-provider chat + inline completion (no packages)
  mjb-keys.el       THE keybinding table + section data
  mjb-cheatsheet.el C-c ? reference buffer (autoloaded, not required)
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

**`C-c ?` opens a cheat sheet** with every binding in it — two columns when the
window is at least ~104 columns wide, one below that. `q` closes it, `g`
refreshes. It is rendered from `mjb-key-table` at display time, so it shows what
is actually bound, not what someone remembered to write down.

To have it open instead of `*scratch*` at startup:

```elisp
(setq mjb-cheatsheet-at-startup t)
```

That only applies when Emacs starts with no file arguments — `emacs foo.tex`
still lands you in `foo.tex`. It costs nothing at startup either way: the
renderer lives in `lisp/mjb-cheatsheet.el` and is **autoloaded**, so it is not
read until you press the key (measured at −0.6 ± 3 ms, i.e. free; loading it
eagerly cost 6 ms, which is why it is a separate file).

[KEYBOARD.md](KEYBOARD.md) is the same content as a committed file, **generated**
from the same table and the same section data by `scripts/gen-keyboard-doc.el`.
The buffer and the file cannot disagree, and neither can drift from the code.

The short version: `C-c a` AI, `C-c c` code, `C-c s` search, `C-c t` toggles,
`C-c p` project, `C-c e` file sidebar, `C-x t` tabs, `C-x g` magit.

Emacs 30's built-in `which-key` also shows the options for a prefix if you pause
after `C-c a`, so the cheat sheet is for "what exists", which-key for "what
comes next".

Nothing important is bound to `C-.` `C-;` `C-=` `C->` or Control-Shift-letter:
those have no legacy terminal encoding and cannot be transmitted through tmux.

## Languages

75% of the work here is Markdown and LaTeX; the rest is Python, Rust and C.

| | Mode | Lint | Format | LSP |
|---|---|---|---|---|
| LaTeX | `tex-mode` + reftex | — | — | `C-c C-c` builds with latexmk |
| Markdown | `markdown-mode` | flyspell | — | — |
| Python | `python-ts-mode` | ruff (flymake) | ruff, on save | `ty server` |
| Rust | `rust-ts-mode` | `cargo check` / `clippy` | rustfmt, on save | rust-analyzer |
| C | `c-ts-mode` | — | — | clangd, if installed |

**Rust was entirely unconfigured until 2026-08-12** — `.rs` files opened in
`fundamental-mode`, with no highlighting, indentation or LSP, despite
rust-analyzer, rustfmt and clippy all being installed. The cause is a
chicken-and-egg in Emacs itself: `rust-ts-mode.el` ends with

```elisp
(if (treesit-ready-p 'rust)
    (add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-ts-mode)))
```

which only runs when that file is *loaded*, and nothing loads it, because the
only thing that would is the entry it is trying to add. `lisp/mjb-rust.el` makes
the association explicitly, guarded on the grammar so a machine without it falls
back to `prog-mode` and says how to fix it.

In Rust buffers: `C-c C-c` cargo check, `C-c C-l` clippy, `C-c C-t` test,
`C-c C-k` any cargo subcommand. Errors are navigable because Emacs's built-in
`rustc` compilation rule already matches rust's `--> src/main.rs:12:5`.

`C-c c f` formats the buffer via whichever formatter the mode registered
(`mjb-format-functions`) — ruff for Python, rustfmt for Rust — falling back to
the language server when a mode has none. It used to call
`mjb-python-format-buffer` directly, so the one "format" key did nothing in
every language but Python.

**Python is uv + ty + ruff, and nothing else** — no pyright, basedpyright,
pylsp, jedi, mypy, black, isort, flake8 or pyvenv. That is enforced rather than
just documented: the module used to try five language servers in preference
order, so installing any of them for an unrelated reason silently changed which
one ran. It is now a single `mjb-python-lsp-command` (`ty server`), and eglot's
own Python entry — which reaches for pylsp and pyright — is *replaced* rather
than appended to, so the old tools cannot come back through the side door.

`uv` needs no special support: it writes `.venv` into the project root, which
the plain upward search already finds and uses for the REPL and for subprocesses.

In Python buffers: `C-c C-u` runs uv (sync, add, run, …), `C-c C-y` runs
`ty check`, `C-c C-l` runs `ruff check`. Formatting is `C-c c f` as everywhere
else.

`C` works out of the box via `c-ts-mode`. Installing `clangd`
(`sudo apt install clangd`) is all that's needed for LSP there; eglot already
knows about it.

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

Checks that all 16 modules byte-compile with zero warnings, that the whole
configuration loads with no errors, and that every declared keybinding resolves
to the command it claims — including that `M-y` is still `yank-pop`.

## Requirements and rationale

[`docs/requirements/`](docs/requirements/) documents what the previous
configuration did, what the on-disk evidence said was actually being used, the
defects found, and a numbered requirement for each with an acceptance test.
Read [`03-findings.md`](docs/requirements/03-findings.md) first if you want the
short version of why this was rebuilt.
