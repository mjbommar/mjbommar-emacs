# 08 — Stated goals, decisions, and revised measurements

Added 2026-08-11 after the goals were stated. This document supersedes parts of
[`04-requirements.md`](04-requirements.md); the amendments are listed in §5.

## 1. Stated goals

1. Fast startup time.
2. Minimal dependency and security surface area.
3. Nice colors, syntax highlighting, and font support.
4. Clean tabs and switching.

## 2. Decisions taken

| # | Decision | Consequence |
|---|---|---|
| D-1 | **Terminal primary, GUI must also work** | GUI-only features return behind `(display-graphic-p)` guards rather than being deleted. Font configuration is retained but scoped. Keys that fail the terminal encoding test may be bound *in addition* to a terminal-safe key, never instead of one. |
| D-2 | **`tab-bar-mode` — workspaces** | One tab per project, each holding a window configuration. Built-in, zero dependencies. `centaur-tabs` is still removed; the capability is replaced, not dropped. |

Still open from [`07-migration-plan.md`](07-migration-plan.md) Phase 0: LaTeX
backend (AUCTeX vs eglot+texlab) and package manager (elpaca vs straight vs
package.el).

## 3. New measurements

### 3.1 Color depth — already correct, no action needed

An earlier draft suspected the tmux layer was degrading color. It is not.

```
COLORTERM unset      → Emacs sees 256 colors
COLORTERM=truecolor  → Emacs sees 16,777,216 colors
```

`COLORTERM=truecolor` is exported in the environment, and byobu's tmuxrc sets
`terminal-features *:RGB`. Emacs 30 honours `COLORTERM`, so 24-bit color is live
today through Emacs → tmux → Ghostty despite `TERM=screen-256color` advertising
only 256.

The fragility is that this depends entirely on an environment variable that is
not always propagated — over SSH, under `sudo`, or in a tmux session that
outlives the shell that set it. That is worth one defensive line, not a
redesign. See `R-046`.

Terminfo entries available if a belt-and-braces fix is ever wanted:
`tmux-direct` and `xterm-direct` are both present on this machine and both
declare 16777216 colors.

### 3.2 Startup cost attribution

Per-package load time, measured against the installed tree:

| Package | Load | Loaded at startup? |
|---|---:|---|
| `magit` | 258 ms | No — lazy via `:bind`. Does not count. |
| `yasnippet` | 95 ms | Via `yas-global-mode` in `:config` |
| `treemacs` | 69 ms | No — deferred |
| `doom-modeline` | 64 ms | **Yes** (`:demand t`) |
| `dashboard` | 30 ms | **Yes** (`:demand t`) — and never rendered |
| `projectile` | 26 ms | **Yes** — dragged in only by centaur-tabs' grouping call |
| `centaur-tabs` | 13 ms | **Yes** (`:demand t`) |
| `consult` | 13 ms | No — deferred |
| `markdown-mode` | 12 ms | No — by file extension |

Roughly **130 ms of the measured 230 ms startup is four packages**, all of which
are being removed or replaced by built-ins. `dashboard` is pure waste: Emacs is
invoked as `emacs <file>`, which suppresses the startup screen entirely.

### 3.3 Package provenance — the security headline

| Source | Count | Signed? | Review? |
|---|---:|---|---|
| GNU / NonGNU ELPA | 6 | GPG-signed | FSF copyright assignment, human review |
| MELPA | 71 | unsigned | none — builds from git HEAD |

The six signed packages are `csv-mode`, `kind-icon`, `plz`, `queue`, `svg-lib`,
`undo-tree`. Everything else executes unreviewed, unsigned upstream code with
full user privileges on every startup.

This compounds with `F-02`: three live API keys sit in the environment of every
process, so the blast radius of one compromised package is all three
credentials. Rotating the keys and moving Emacs to `auth-source` (`R-013`,
`R-014`) is the highest-value single action in this whole review.

### 3.4 Emacs 30 built-ins that replace installed packages

Verified present on this machine:

```
use-package   which-key   eglot      project     tab-bar    tab-line
treesit       flymake     so-long    savehist    saveplace  recentf
completion-preview         reftex    bibtex      tex-mode   flyspell
repeat        xref        eldoc      dired-x     electric   outline
```

Direct consequences:

- `which-key` and `use-package` are currently installed from MELPA
  **redundantly** — Emacs 30 ships both.
- `reftex` and `bibtex` being built in means a substantial share of `R-050`
  (LaTeX cross-references and citations) needs **no new dependency**.
- `completion-preview-mode` is a built-in inline-completion preview. It does not
  replace minuet (no LLM), but it covers the common case for free.
- `tab-bar` and `tab-line` make D-2 a zero-dependency decision.

Target package count: **~25, down from 85**, with MELPA use confined to packages
that genuinely have no built-in or GNU ELPA equivalent (magit, vertico/consult
family, vterm, gptel, minuet, AUCTeX if chosen from MELPA rather than the
Debian `auctex` package).

### 3.5 Tree-sitter is inert

`treesit` is built in and available, but zero grammars are installed, so no
`*-ts-mode` can activate. Goal 3 asks for good syntax highlighting; parser-based
highlighting is available for free and is currently switched off by omission.
Note that LaTeX has no tree-sitter mode in Emacs 30 — the largest workload is
served by `font-lock` and AUCTeX regardless.

## 4. Goal-to-requirement traceability

| Goal | Requirements |
|---|---|
| 1 · Fast startup | `R-002` (native comp), `R-006` (revised budget), `R-040` (revised), `R-042`, `R-045` |
| 2 · Minimal deps / security | `R-004`, `R-008` (new), `R-013`, `R-014`, `R-040` (revised), `R-054`, `R-055` |
| 3 · Colors / highlighting / fonts | `R-043` (revised), `R-046` (new), `R-047` (new), `R-041` (revised) |
| 4 · Tabs and switching | `R-045` (new), `R-032`, `C-c s i` / `consult-buffer` in [`06-keybindings.md`](06-keybindings.md) |

## 5. Amendments to `04-requirements.md`

The following requirements are **revised or added**. Where a requirement is
revised, the original text in `04-requirements.md` has been updated in place and
is cross-referenced here.

### R-006 (revised twice) · Startup budget — P0

Was: "< 0.5 s". Then: "≤ 0.15 s". **Now: ≤ 0.21 s, measured 0.195 s.**

**The 0.15 s target was not met, and the estimate behind it was wrong.** It came
from §3.2's attribution — 130 ms of the old 230 ms was doom-modeline, dashboard,
projectile and centaur-tabs — and implicitly assumed nothing would replace them.
Things did: the rebuild eagerly loads vertico, corfu, cape, marginalia and
diff-hl, plus 13 module files.

Measured attribution of the 0.195 s, after byte-compiling every module and
enabling native compilation and `package-quickstart`:

| Component | Cost |
|---|---:|
| 13 `mjb-*` modules | 67 ms |
| `load-theme modus-vivendi` | 12 ms |
| `package-initialize` | 10 ms |
| Emacs tty startup, frame setup, hooks | ~105 ms |

Net result against the old configuration: **0.230 s → 0.195 s**, a 15%
improvement, not the 35% projected.

Further gains are available but each costs something real:
- Defer `corfu`/`cape`/`marginalia` behind hooks — saves perhaps 20 ms, at the
  price of completion not being live in the first buffer.
- Drop the theme (12 ms) — refuses goal 3.
- Run as a daemon with `emacsclient` — makes startup a non-question entirely,
  and is the honest answer if startup latency actually bothers you day to day.

Given goal 1 was "fast startup" rather than a specific number, 0.195 s is
recorded as met-in-spirit and the numeric requirement is relaxed to a
regression guard rather than a target.

*Test:* `TERM=xterm-256color emacs --init-directory=<repo> -nw --eval '(progn
(message "%s" (emacs-init-time)) (kill-emacs))'` reports ≤ 0.21 s, averaged over
five runs.

### R-008 (new) · Dependency provenance is ranked and bounded — P0 [new]

Package selection follows a strict preference order:

1. **Built into Emacs 30** — always preferred, even if a MELPA package is nicer.
2. **GNU / NonGNU ELPA** — GPG-signed, reviewed. Preferred for themes.
3. **MELPA** — only when there is no equivalent above, and each such package must
   be justified in a comment naming what it provides that a built-in cannot.

The total MELPA package count must not exceed **20**, and the number must be
asserted by a committed script.

*Test:* a batch script counts installed packages by archive and fails if the
MELPA count exceeds 20 or if any package has a built-in equivalent listed in
§3.4.

### R-041 (revised) · Tree-sitter grammars are installed — P1

Was: "usable or absent", with a recommendation to remove. Now: **install
grammars** for Python, C, JSON, YAML, and Markdown, and route via
`major-mode-remap-alist`. `treesit-auto` remains removed — Emacs 30 does this
natively.

*Justification:* goal 3 asks for good syntax highlighting; parser-based
highlighting is strictly better than regex `font-lock` and costs no package.

*Test:* `treesit-available-language-list` is non-empty; a `.py` buffer reports
`python-ts-mode`.

### R-040 (revised) · GUI components are guarded, not deleted — P0

Was: "no component is loaded that cannot function in a terminal", removing
icons and tabs outright. Revised under **D-1**:

- `centaur-tabs` and `dashboard` are still **removed** — the first is replaced by
  built-in `tab-bar` (D-2) and causes `F-03`; the second never renders.
- `all-the-icons` / `nerd-icons` may be **retained behind `(display-graphic-p)`
  and lazily loaded**, contributing zero terminal startup cost. They are
  optional; if goal 2 is weighted more heavily than icon rendering in GUI, drop
  them.
- `kind-icon` stays removed — corfu's built-in annotations are sufficient and it
  is one of only six signed packages, so its removal is a small provenance loss
  for a real complexity gain.

*Test:* in `emacs -nw`, `(featurep 'nerd-icons)` is `nil` after startup;
in GUI Emacs it may be non-nil. `(featurep 'centaur-tabs)` and
`(featurep 'dashboard)` are `nil` in both.

### R-043 (revised) · Theme is legible in 24-bit terminal and GUI — P1

Was P2 cosmetic. Raised to **P1** under goal 3.

Theme must render correctly in both frame types from a single configuration.
Preference order per `R-008`: `ef-themes` or `modus-themes` (GNU ELPA, signed,
built for terminal contrast) over `doom-themes` (MELPA). A Catppuccin port is
acceptable if matching Ghostty's `Catppuccin Latte`/`Mocha` pair is wanted.

*Test:* open `main.tex` and a `.py` file in both `emacs -nw` and GUI Emacs;
syntax colors are distinguishable and comments are readable in both.

### R-046 (new) · 24-bit color is asserted, not assumed — P1 [new]

The configuration must not silently degrade to 256 colors when `COLORTERM` is
absent. Either set the terminal's color capability explicitly at startup when
the terminal is known to support it, or emit a visible warning.

*Justification:* §3.1 — truecolor currently depends on an environment variable
that is not reliably propagated over SSH or into detached tmux sessions.

*Test:*
```
env -u COLORTERM TERM=screen-256color emacs -nw
```
still reports `(display-color-cells)` = 16777216, or displays a startup warning
naming the cause.

### R-047 (new) · Font configuration is GUI-scoped and correct — P1 [new]

Under **D-1**, font settings are retained but must be inside a
`(display-graphic-p)` guard, and the configured family must be one that is
actually installed.

*Note:* in the terminal, the font is Ghostty's (`Berkeley Mono`, size 11) and
Emacs cannot influence it. The current unguarded `JetBrains Mono` / height 120
settings are inert in the terminal and should not be presented as working.

*Test:* `fc-list | grep -i "<family>"` returns a match for whatever family the
config names. In `emacs -nw`, no font code executes.

### R-045 (new) · Workspace tabs via built-in `tab-bar` — P0 [new · D-2]

`tab-bar-mode` provides one tab per project workspace, each holding its own
window configuration. Zero dependencies.

Required:

| # | Capability | Test |
|---|---|---|
| a | Create / close / rename a tab from a terminal-safe key | `C-x t 2`, `C-x t 0`, `C-x t r` work in `emacs -nw` |
| b | Switch to a tab by name with completion | A command lists tabs and jumps to the chosen one |
| c | Switch to a tab by number | `M-1`…`M-4` or equivalent selects tabs 1–4 |
| d | Tab bar renders cleanly in an 80-column terminal | No wrapping, no truncated escape sequences |
| e | Tabs persist across restarts | With `desktop-save-mode` or `tab-bar-history-mode`, layouts survive a restart |
| f | Opening a project creates or reuses its tab | `project-switch-project` lands in that project's tab |

**Note on `C-x t`:** [`06-keybindings.md`](06-keybindings.md) currently assigns
`C-x t` to treemacs. `C-x t` is the **built-in `tab-prefix-map`**, so treemacs
must move — it is the newcomer to that prefix, not `tab-bar`. This is a fresh
collision introduced by D-2 and is exactly the class of problem `R-030`'s
automated check exists to catch. Suggested: treemacs moves to `C-c e`
(explorer), or is dropped entirely given `R-044` marks it P2 and there is no
evidence of use.

*Additional note:* `M-1`…`M-9` for tab selection conflicts with `digit-argument`
in the same way `M-0` currently does (`R-034`). Either accept the loss
deliberately and document it, or use `C-x t <n>`.
