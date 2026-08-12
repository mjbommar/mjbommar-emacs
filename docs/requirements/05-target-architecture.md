# 05 — Target architecture

Satisfies `R-001`, `R-004`, `R-007`, `R-082`. This describes *shape*, not
implementation; the requirements in [`04-requirements.md`](04-requirements.md)
are the contract.

## File layout

```
mjbommar-emacs/
├── early-init.el              GC, frame, native-comp, package system off
├── init.el                    ≤ 80 lines: load path, bootstrap, require modules
├── lisp/
│   ├── mjb-core.el            defaults, files, backups, auto-save, encoding
│   ├── mjb-keys.el            THE keybinding table — single source of truth
│   ├── mjb-ui.el              theme, modeline, line numbers, which-key
│   ├── mjb-completion.el      vertico, orderless, marginalia, consult, corfu, cape
│   ├── mjb-editing.el         electric-pair, undo, expand-region, whitespace
│   ├── mjb-vc.el              magit, diff-hl (+ margin mode for terminal)
│   ├── mjb-project.el         project.el, ripgrep, file navigation
│   ├── mjb-prose.el           text-mode, markdown, spell check, visual-line
│   ├── mjb-latex.el           the big new one — see R-050
│   ├── mjb-python.el          ruff, flymake, optional eglot
│   ├── mjb-formats.el         json / yaml / toml / csv / org
│   ├── mjb-shell.el           eshell + ansi-term (built-in)
│   └── mjb-ai.el              gptel + minuet, model IDs at the top
├── etc/                       (generated, gitignored) no-littering config state
├── var/                       (generated, gitignored) no-littering data state
├── scripts/
│   ├── check-keys.el          batch: assert no collisions, no unbound (R-030)
│   ├── gen-keyboard-doc.el    batch: regenerate KEYBOARD.md (R-080)
│   └── smoke.sh               batch: load config, assert zero errors (R-007)
├── docs/requirements/         this document set
├── README.md
└── KEYBOARD.md                GENERATED — do not hand-edit
```

Rules:

1. A module owns its packages, its settings, **and its mode-local keys**. Global
   keys live only in `mjb-keys.el`.
2. Every module ends `(provide 'mjb-<name>)` and byte-compiles clean.
3. Every module opens with a `;;; Commentary:` naming its scope and prefix
   (`R-082`).
4. `init.el` contains no `setq` of anything other than load path and bootstrap
   variables.

## Why keys are centralised

`F-03` and `F-04` are both collisions between packages configured 300 lines
apart, each using `use-package :bind`. Distributed `:bind` forms make collisions
structurally invisible. One table makes them a diff.

The tradeoff is that `:bind`'s automatic autoloading is lost, so the table must
either use `autoload` explicitly or bind through commands that are already
autoloaded. That is a small, contained cost.

Mode-local maps (`LaTeX-mode-map`, `python-mode-map`) stay with their module —
they cannot collide globally by construction.

## Package management

`R-004` requires pinning. Two viable choices:

| | elpaca | straight.el |
|---|---|---|
| Lockfile | native (`elpaca-write-lockfile`) | `versions/default.el` via `straight-freeze-versions` |
| Install model | async, git clones | git clones |
| Maturity | newer, actively developed | older, very widely used |
| `use-package` integration | yes | yes |
| Emacs 30 built-in packages | handled via `:ensure nil` | handled via `:type built-in` |

Either satisfies the requirement. **Recommendation: elpaca**, on the grounds
that async installs make the first-run experience on a new machine much less
painful and lockfile support is a first-class feature rather than a bolt-on.

Plain `package.el` + `package-selected-packages` is the third option: simpler,
no bootstrap, but gives declaration without pinning, so it fails `R-004` as
written. If pinning turns out not to matter to you, say so and this requirement
drops — but then `F-13` stands.

## State directory discipline

Keep `no-littering`. It already works, and the existing `var/` state
(`R-016` — 78 saved positions, 20 recent files) must survive migration
untouched. Both `etc/` and `var/` stay gitignored.

`eln-cache/` will grow once `R-002` lands (native compilation on). Expect
several hundred MB; it is disposable and gitignored.

## The verification scripts

These exist because three of the findings (`F-03`, `F-04`, `F-06`) are exactly
the class of bug that a human reading a 948-line file will not catch.

**`scripts/check-keys.el`** — loads the config in batch, walks the keybinding
table, and fails if any entry resolves to `unbound`, to a keymap where a command
is expected, or to a command other than the one declared. This directly
implements the `R-030` test.

**`scripts/smoke.sh`** — the `R-007` test. Runs in CI or by hand before any
commit.

**`scripts/gen-keyboard-doc.el`** — the `R-080` generator.

None of these is elaborate; together they are perhaps 150 lines, and they turn
three recurring failure modes into a command you can run.

## What terminal-first means concretely

The config targets `emacs -nw` inside tmux inside Ghostty as the *primary*
environment. That has specific consequences that should be encoded once, in
`mjb-core.el` / `mjb-ui.el`, rather than rediscovered:

- No fringe. Anything that draws in the fringe (`diff-hl`, flymake indicators)
  needs its margin variant enabled (`R-056`).
- No SVG, no images, no variable-pitch. Icon packages are pointless (`R-040`).
- Font and frame-size settings are inert; the terminal owns them.
- Clipboard is OSC 52 out, terminal paste in (`R-015`).
- Mouse works if `xterm-mouse-mode` is on — currently it is not, and Ghostty's
  `copy-on-select` means enabling it would *disable* the terminal's own
  selection. That is a real tradeoff; leave mouse mode off unless asked.
- Key encoding is the legacy set (`F-06`, `R-033`).

If GUI Emacs is also wanted, the pattern is `(when (display-graphic-p) …)`
blocks in `mjb-ui.el` — not a second config.

## Migration safety

The rebuild must be able to run side by side with the current config before
replacing it:

```
emacs -nw --init-directory ~/src/mjbommar-emacs-next
```

`--init-directory` (Emacs 29+) makes this a one-flag operation. Nothing in
`~/.emacs.d` is touched until the new config passes its own tests and a day of
real use.
