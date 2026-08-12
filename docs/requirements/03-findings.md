# 03 — Findings

Each finding has an ID, a severity, the evidence, and the requirement(s) that
address it. Severity is about consequence, not effort:

- **S1** — data loss, security exposure, or a feature that silently does nothing.
- **S2** — broken or unreachable functionality; wasted resources.
- **S3** — friction, drift, or maintenance burden.

---

## F-01 · Backups, auto-save, and lock files are all disabled — S1

```elisp
;; init.el:41-55
(setq-default create-lockfiles nil
              make-backup-files nil
              auto-save-default nil)
```

Verified at runtime: `backups=nil autosave=nil lockfiles=nil`.

This machine is used to write books in LaTeX across sessions lasting hours. With
all three off there is no recovery path from a crash, an accidental
`C-x C-c`-without-save, a bad `undo` chain, or an out-of-disk write failure. The
`var/auto-save/sessions/` directory that `no-littering` prepared is empty
because auto-save never runs.

`create-lockfiles nil` additionally removes the guard against two Emacs
instances editing the same file — relevant here, because Emacs is launched
ad-hoc per file from tmux panes rather than as a single daemon.

→ **R-010, R-011, R-012**

---

## F-02 · API keys are in plaintext in `~/.bashrc` — S1

`~/.bashrc` lines 136–140 export `OPENAI_API_KEY`, `GEMINI_API_KEY`, and
`ANTHROPIC_API_KEY` as literal values. `~/.authinfo` does not exist.

Consequences: every process started from a login shell inherits three live
API credentials in its environment; any of them can be read from
`/proc/<pid>/environ` by the user's own processes; they will be captured by any
shell-session recording, any `env` dump in a bug report, and any backup of the
dotfiles. `.bashrc` is not in the emacs repo, so this is not a repo leak — but
it is a live exposure.

The config reads them from the environment:
`(getenv "ANTHROPIC_API_KEY")` for gptel, `(plist-put minuet-claude-options
:api-key "ANTHROPIC_API_KEY")` for minuet.

Two separate actions are implied: rotate the exposed keys, and change how Emacs
obtains them. Only the second is in scope for this repo; the first is worth
doing regardless.

→ **R-013, R-014**

---

## F-03 · `C-c t` is claimed by two packages; eglot wins in code buffers — S2

```elisp
;; centaur-tabs
:bind ("C-c t p" . centaur-tabs-backward)
      ("C-c t n" . centaur-tabs-forward)   ; …and 6 more under C-c t

;; eglot
:bind (:map eglot-mode-map
            ("C-c t" . eglot-find-typeDefinition))
```

`eglot-mode-map` is a minor-mode map and shadows the global map. So in any
buffer where eglot is active, `C-c t` runs `eglot-find-typeDefinition` and the
entire tab prefix is unreachable; in every other buffer the tab prefix works and
`eglot-find-typeDefinition` does not exist. The behaviour of `C-c t n` therefore
depends on whether an LSP server happens to be attached — and since `pyright`
is missing (`F-09`), it depends on something that currently never succeeds.

`README.md` compounds this by documenting `C-c t` as "Toggle light/dark theme",
which is wrong in a third way — the theme toggle is `C-c T`.

→ **R-030, R-031**

---

## F-04 · All nine `cape` keybindings are dead — S2

```elisp
;; project.el
:bind-keymap ("C-c p" . project-prefix-map)

;; cape
:bind (("C-c p p" . completion-at-point)
       ("C-c p d" . cape-dabbrev)  ; …and 7 more
```

`:bind-keymap` installs a prefix keymap at `C-c p`. Every `C-c p <x>` binding
from cape is placed in the *global* map underneath that prefix and is therefore
shadowed by the keymap. Runtime probe confirms `C-c p` resolves to the
project-prefix autoload and `C-c p d`, `C-c p f`, `C-c p p` all resolve to
`unbound` at load time; after `project` loads, `C-c p f` is
`project-find-file`.

`KEYBOARD.md` documents both sets as if both work. Six of the documented
"Cape Completions" bindings cannot ever fire.

→ **R-030, R-032**

---

## F-05 · `electric-pair-mode` and `smartparens` are both active — S2

`electric-pair-mode` is enabled globally at init.el:83.
`smartparens-mode` is hooked into `prog-mode`.

Both insert closing delimiters. In any `prog-mode` buffer they are stacked, and
the two have different ideas about wrapping regions, skipping over closers, and
handling quotes in strings/comments. The usual symptom is doubled delimiters or
a closer that refuses to be typed over.

→ **R-020**

---

## F-06 · A large share of documented keybindings cannot be typed in this terminal — S2

The following are bound in `init.el` and documented in `KEYBOARD.md`:

```
C-.  embark-act          C-;  embark-dwim         C-:  avy-goto-char
C-'  avy-goto-char-2     C-=  er/expand-region    C->  mc/mark-next-like-this
C-<  mc/mark-previous    C-S-c C-S-c  mc/edit-lines
C-c C-<return>  gptel-menu
```

Control combined with punctuation, and Control-Shift-letter, have no
representation in the legacy terminal input encoding. A terminal can only send
them if it implements an extended keyboard protocol (Kitty keyboard protocol or
xterm `modifyOtherKeys`) *and* the application decodes it. Ghostty implements
the Kitty protocol; **Emacs 30 does not decode it without an add-on package**,
and tmux sits in between with `extended-keys` unset.

Rather than assert the outcome, verify it. In the real terminal, run:

```
C-h k   then press the key in question
```

If the echo area reports the plain character (`.`, `;`, `=`) or nothing, the
binding is unreachable. Do this for each key above before deciding what to keep.

The rebuild should not bind primary functionality to keys that fail this test.

→ **R-033, R-034**

---

## F-07 · Native compilation is switched off by an obsolete variable name — S2

```elisp
;; early-init.el:33
(setq native-comp-deferred-compilation nil)
```

`native-comp-deferred-compilation` was renamed to `native-comp-jit-compilation`
in Emacs 29.1 and is an obsolete *alias* — assigning to it still assigns the new
variable. Runtime probe confirms `native-comp-jit-compilation` is `nil`.

Result: none of the 85 ELPA packages are ever natively compiled. Evidence:
`find ~/.emacs.d/elpa -name '*.eln'` → **0 files**; the user `eln-cache`
contains 6 trampolines and nothing else, 104 KB total. Every package runs as
byte-code on a machine where native compilation is available.

The setting was presumably added to avoid compilation stalls during a session.
The correct way to get that without giving up native code is to compile ahead of
time at install, or to leave JIT on and accept a one-off background compile.

→ **R-002, R-003**

---

## F-08 · The tree-sitter setup provides nothing — S3

`treesit-auto` is configured with `treesit-auto-install 'prompt` and
`global-treesit-auto-mode`. `treesit-available-language-list` returns `nil` —
no grammars are installed. Every `*-ts-mode` therefore falls back, and the
package is pure startup cost.

Separately, `treesit-auto`'s last release was 2024-05; Emacs 30 ships
`treesit-auto-install-all`-style handling and `major-mode-remap-alist` natively,
so the package is not needed to get tree-sitter modes.

→ **R-041**

---

## F-09 · Four configured tools are not installed — S2

| Config expects | Present? | Effect |
|---|---|---|
| `pyright` (eglot python hook) | ❌ | Every Python buffer starts a failing LSP connection |
| `black` (`python-black-on-save-mode`) | ❌ | Format-on-save silently does nothing |
| `marksman` (eglot markdown entry) | ❌ | Dead server entry |
| `multimarkdown` / `pandoc` (`markdown-command`) | ❌ | Markdown preview/export dead |

Meanwhile `ruff` **is** installed and the config defines a `ruff-format`
reformatter that is bound to nothing and hooked to nothing. `uv` is installed
and unused by the config.

→ **R-050, R-051, R-052**

---

## F-10 · Both AI model IDs are past their retirement dates — S2

| Integration | Configured | Status 2026-08-11 |
|---|---|---|
| gptel | `claude-opus-4-1-20250805` | retired 2026-08-05 |
| minuet | `claude-sonnet-4-20250514` | retired 2026-06-15 |

Requests to a retired model ID fail. Both integrations are non-functional right
now. `README.md` additionally claims minuet uses Opus 4.1, contradicting
`init.el`.

Current model IDs, for reference: `claude-opus-5` (flagship, 1M context),
`claude-sonnet-5` (balanced), `claude-haiku-4-5` (fast/cheap, 200K).

Model IDs will keep expiring. The requirement is not "set the right string once"
but "put the string in one obvious place with a comment saying it expires."

→ **R-060, R-061, R-062**

---

## F-11 · Terminal clipboard integration has never worked on this machine — S2

Covered in [`02-usage-evidence.md`](02-usage-evidence.md) §5. `xclip` is absent,
so the guard `(executable-find "xclip")` fails and the block is inert. The
correct mechanism for this stack (Emacs → tmux `set-clipboard external` →
Ghostty) is OSC 52, which also works over SSH.

→ **R-015**

---

## F-12 · The installer is destructive and detaches the config from git — S2

`install.sh` does `rm -rf "$EMACS_DIR"` then `cp -r`. Consequences:

- Any file created in `~/.emacs.d` that is not in the repo — including
  `etc/custom.el`, snippets, and the entire 39 MB `elpa/` tree — is deleted and
  must be re-downloaded.
- The backup step copies that same 39 MB `elpa/` tree into
  `~/.emacs.d.backups/backup_<timestamp>/` every run, so repeated installs
  accumulate hundreds of megabytes.
- `cp -r "$SOURCE_DIR/".*` matches `.` and `..`; it is suppressed by
  `2>/dev/null || true`, which also suppresses genuine copy failures.
- Because the installed tree is a copy rather than a checkout, an edit made in
  `~/.emacs.d/init.el` is invisible to `git status` in the repo and is destroyed
  by the next install. This is a live trap for exactly the workflow the user
  asked for — "customize it myself."
- The advertised entry point is `curl … | bash`, which executes an unreviewed
  remote script.

→ **R-070, R-071, R-072**

---

## F-13 · Package versions are unpinned and unreproducible — S3

`use-package-always-ensure t` with plain `package.el` and no version pinning.
`etc/custom.el` records `(package-selected-packages nil)` — so even the
selected-package list is empty and `package-autoremove` has nothing to work
from. The installed set is 85 packages whose versions are whatever MELPA served
on the day each was first installed (dates range 2021 to 2026-02).

There is no lockfile, so the config cannot be reproduced on another machine or
rolled back after a bad upgrade.

→ **R-004, R-005**

---

## F-14 · Documentation contradicts the code in at least five places — S3

| Claim | Reality |
|---|---|
| README: "`C-c t` – Toggle light/dark theme" | `C-c t` is the centaur-tabs prefix; the toggle is `C-c T` |
| README: minuet "Default: Claude Opus 4.1" | `init.el` sets `claude-sonnet-4-20250514` |
| README: "Auto-suggestions enabled in programming modes" | Disabled by default since commit `54ea9ff` |
| KEYBOARD.md: nine `C-c p …` cape bindings | All shadowed (`F-04`) |
| KEYBOARD.md: "Rust: `C-c C-c C-r` cargo run" | `cargo-minor-mode` uses `C-c C-c C-r`; but no Rust is used at all |

Documentation drift is cheap to fix and expensive to trust. The rebuild should
generate the keybinding reference from the config rather than maintaining a
parallel prose copy.

→ **R-080, R-081**

---

## F-15 · Startup-cost items that never pay off — S3

Not urgent, but worth recording since the rebuild removes them anyway:

- `dashboard` is `:demand t` and sets up a startup hook, but Emacs is invoked as
  `emacs <file>`, which suppresses the startup screen.
- `centaur-tabs` `:config` calls `centaur-tabs-group-by-projectile-project`,
  which loads `projectile` at startup even though the config uses `project.el`.
- `doom-modeline` sets ~35 variables, several of which (`persp-name`, `mu4e`,
  `gnus`, `irc`, `github`, `modal`) refer to packages that are not installed.
- `inhibit-startup-echo-area-message` is set to `t`; it only suppresses the
  message when set to the literal username string, so it does nothing.
- Measured startup is 0.23 s, so none of this is *urgent* — but each item is
  code that has to be read and maintained for no return.

→ **R-040, R-042**

---

## Findings summary

| ID | Severity | One line |
|---|---|---|
| F-01 | S1 | No backups, no auto-save, no lock files |
| F-02 | S1 | Three API keys in plaintext in `.bashrc` |
| F-03 | S2 | `C-c t` collision: centaur-tabs vs eglot |
| F-04 | S2 | All nine cape bindings shadowed by `C-c p` prefix |
| F-05 | S2 | electric-pair and smartparens both active |
| F-06 | S2 | Control-punctuation bindings likely unreachable in terminal |
| F-07 | S2 | Native compilation disabled by obsolete variable |
| F-08 | S3 | tree-sitter configured with zero grammars |
| F-09 | S2 | pyright / black / marksman / pandoc all missing |
| F-10 | S2 | Both AI model IDs past retirement |
| F-11 | S2 | xclip clipboard block is dead code |
| F-12 | S2 | Installer is destructive and detaches from git |
| F-13 | S3 | No version pinning or lockfile |
| F-14 | S3 | Docs contradict code in ≥5 places |
| F-15 | S3 | Startup work that never pays off |
