# 04 — Requirements

> **Amended 2026-08-11.** Goals and two design decisions were added after this
> document was first written. See [`08-goals-and-decisions.md`](08-goals-and-decisions.md).
> Revised here in place: `R-006`, `R-040`, `R-041`, `R-043`. Added: `R-008`,
> `R-045`, `R-046`, `R-047`. Requirements are tagged **[goal N]** where they
> serve one of the four stated goals.

Each requirement has an ID, a tag, a statement, a rationale, and an acceptance
test. **Every requirement must be verifiable without judgement** — if you cannot
write down how to check it, it is a preference, not a requirement.

Tags:

- **[preserve]** — you use this today; the rebuild must not lose it.
- **[new]** — my proposal. Reject freely; these have the weakest claim.
- **[remove]** — deletion, with the evidence that supports it.
- **[fix]** — the capability exists but is broken.

Priority: **P0** must be in the first working version. **P1** is the same
release, after P0. **P2** is explicitly deferrable.

---

## A. Foundation

### R-001 · Configuration is split into topical modules — P0 [new]

`init.el` must be a loader of no more than ~80 lines. All substantive
configuration lives in `lisp/mjb-<topic>.el` files, each providing a feature and
each independently loadable.

*Rationale:* 948 lines in one file with 63 `use-package` forms is the reason
`F-03`, `F-04`, and `F-05` were not caught — a keybinding collision is invisible
when the two halves are 400 lines apart. The stated goal is self-customization;
topical files are what make "where do I change X" answerable.

*Test:* `wc -l init.el` ≤ 80. Every `lisp/mjb-*.el` ends in `(provide 'mjb-…)`
and byte-compiles standalone with no `void-variable` / `void-function` errors
beyond those from packages it explicitly requires.

### R-002 · Native compilation is enabled — P0 [fix · F-07]

`native-comp-jit-compilation` must be non-nil. The obsolete
`native-comp-deferred-compilation` assignment is removed.

*Test:* after a full package install and one restart,
`(length (directory-files-recursively (car native-comp-eln-load-path) "\\.eln\\'"))`
is greater than 50. Runtime: `native-comp-jit-compilation` → `t`.

### R-003 · Compilation noise is suppressed but not discarded — P0 [preserve]

`native-comp-async-report-warnings-errors` stays `'silent`. Warnings must still
be reachable in `*Async-native-compile-log*`.

*Test:* the buffer exists after a package install and contains entries.

### R-004 · The package set is declared, recorded, and drift is detectable — P0 [fix · F-13] *(revised — original was not achievable)*

**As originally written this requirement could not be met, and saying so is
better than pretending.** It asked for a lockfile that reproduces exact
versions. **MELPA serves only the latest build of each package and does not
retain old versions**, so a lockfile recording `consult 3.7` cannot restore
`consult 3.7` once 3.8 ships — the artifact no longer exists to fetch.

Exact reproduction would require one of: vendoring the sources into the repo, a
manager that clones git and checks out a revision (`straight`/`elpaca`), or
restricting to GNU ELPA, which does keep old versions. Each was rejected under
`R-008`/goal 2 — `elpaca` and `straight` are thousands of lines of external
dependency whose job is managing dependencies.

**What is required instead, and is implemented:**

1. The declared set lives in one place (`mjb-packages` in `lisp/mjb-package.el`).
2. The exact installed set *and versions* are recorded in a committed
   `package-lock.eld` (`M-x mjb-write-lockfile`).
3. Drift from that record is detectable and loud (`M-x mjb-check-lockfile`),
   reporting added, removed, and version-changed packages.
4. The declared names reinstall on a clean machine (`M-x mjb-install-packages`),
   at whatever versions the archives currently serve.

This is **reproducible-by-name with detectable drift**, not byte-identical
reproduction. The gap is documented in `lisp/mjb-package.el` so the next reader
does not assume a guarantee that is not there.

*Test:* `M-x mjb-check-lockfile` reports a match on a clean tree; after
installing or removing any package it names the difference. Verified by
injecting a fake entry — the drift report fired and named it.

### R-005 · Removing a package from the config removes it from disk — P1 [new]

There must be a single documented command that deletes packages no longer
declared.

*Test:* delete a `use-package` form, run the command, confirm the ELPA/elpaca
directory for that package is gone.

### R-006 · Startup budget — P0 [goal 1] *(revised twice; re-measured 2026-08-12)*

**0.5 s → 0.15 s → 0.21 s. Measured: 0.114 s.**

The 0.15 s figure came from an attribution that assumed the 130 ms freed by
removing `doom-modeline`, `dashboard`, `projectile` and `centaur-tabs` would not
be replaced. It was: the rebuild eagerly loads vertico, corfu, cape, marginalia
and diff-hl, plus 13 module files.

**The earlier 0.195 s reading was a measurement artifact, not the steady state.**
`load-prefer-newer` is on (deliberately — see R-007 notes), so a module whose
`.elc` is older than its `.el` is loaded *from source*, uncompiled. Editing a
module and measuring before recompiling therefore times the source path. At the
time of that reading `mjb-ai.el` — the largest module — was stale. With all 14
modules compiled current, the same measurement gives **0.114 s**, and the
0.15 s target is in fact met.

The correction cuts both ways: it means the number moves whenever a module is
edited, so a startup measurement is only meaningful immediately after
`M-x mjb-recompile`. The 0.21 s ceiling stays as the regression guard because it
must hold in the *stale* case too — that is the state a user is actually in
after editing a module.

Attribution at 0.114 s: ~12 ms `load-theme`, ~10 ms `package-initialize`,
the remainder Emacs tty startup, frame setup and the 13 compiled modules.
Net against the old config: **0.230 s → 0.114 s**, ~50%.

Remaining options — deferring the completion packages (~20 ms, costs live
completion in the first buffer), dropping the theme (12 ms, refuses goal 3), or
running a daemon (removes the question entirely) — are in
[`08-goals-and-decisions.md`](08-goals-and-decisions.md) §5.

*Test:*
```
M-x mjb-recompile          # required: see above
TERM=xterm-256color emacs --init-directory=<repo> -nw \
  --eval '(progn (message "%s" (emacs-init-time)) (kill-emacs))'
```
reports ≤ 0.21 s on a warm cache, averaged over five runs. Note this needs a
real pty — under a redirected stdin Emacs exits before loading init and reports
a meaningless 0.02 s. This is a regression guard, not a target.

### R-008 · Dependency provenance is ranked and bounded — P0 [new] [goal 2]

Package selection follows a strict preference order:

1. **Built into Emacs 30** — always preferred, even where a MELPA package is nicer.
2. **GNU / NonGNU ELPA** — GPG-signed and reviewed. Preferred for themes.
3. **MELPA** — only where nothing above suffices, and each such package carries a
   comment naming what it provides that a built-in cannot.

Total MELPA package count must not exceed **20**.

*Rationale:* 71 of the 77 currently installed packages are unsigned MELPA builds
from git HEAD, against 6 signed. Combined with `F-02` (three live API keys in
the process environment), the blast radius of one compromised package is all
three credentials. Emacs 30 already ships `use-package`, `which-key`, `eglot`,
`project`, `tab-bar`, `tab-line`, `treesit`, `flymake`, `reftex`, `bibtex`,
`completion-preview`, and more — see
[`08-goals-and-decisions.md`](08-goals-and-decisions.md) §3.4.

*Test:* a committed batch script counts installed packages by archive and fails
if the MELPA count exceeds 20, or if any installed package appears in the
built-in equivalence list.

### R-007 · The config loads with zero errors and zero warnings — P0 [new]

*Test:* `emacs --batch -l early-init.el -l init.el --eval '(kill-emacs)'`
produces no output on stderr except the Debian `site-start.d` `flavor` messages,
which originate outside this repo. Byte-compiling every `lisp/*.el` produces no
`free variable` or `undefined function` warnings for code this repo owns.

### R-009 · Package signatures are verified, and the exception is named — P0 [new] [goal 2]

`package-check-signature` is `t`, not the Emacs default `allow-unsigned`.
`allow-unsigned` verifies a signature when one is present and silently accepts
the package when it is not, so an archive that stops signing — or a fetch that
is tampered with in a way that drops the `.sig` — downgrades you without a word.

`package-unsigned-archives` is **empty**. It briefly held `"melpa"`, which
publishes no signatures at all — it builds from upstream git on its own servers,
so there is no author signature to check. Dropping vterm removed the last MELPA
package and with it the need for the carve-out, so the policy now has no
exception at all.

MELPA stays in `package-archives` so its packages remain discoverable in
`list-packages`; installing one fails loudly, and re-adding the exemption is a
one-line reviewable diff rather than a silent default.

Verification needs `gpg` on `PATH`; without it `package-check-signature`
degrades silently, so the configuration says so at startup instead of appearing
to verify when it is not. The keyring is imported into `package-gnupghome-dir`
by `package-refresh-contents` itself, but only when signature checking is
already on.

*Rationale:* R-008 ranked archives by trust but did not enforce anything — under
the shipped default, the ranking was a preference, not a control. At the time
R-008 was written 71 of 77 installed packages were unsigned MELPA builds; the
rebuild inverted that to 16 signed against 1 unsigned, which is what makes
enforcement affordable now.

*Test:* `M-x mjb-check-signatures` reads the `NAME-VERSION.signed` files that
package.el writes on successful verification and reports the count — evidence,
not a restatement of policy. Current: **16/16 signed, no exceptions**.
Enforcement was verified adversarially in a throwaway `package-user-dir`: a
signed GNU ELPA package installs and gets a `.signed` file; an unsigned MELPA
package is **refused** with `Unsigned file ... at https://melpa.org/packages/`
when `package-unsigned-archives` is empty, and installs when the exemption is
restored. `scripts/count-packages.el` additionally fails if the check is
weakened or any exempt archive is added — both regressions were tested.

---

## B. Safety

### R-010 · Backups are enabled and versioned, stored outside the source tree — P0 [fix · F-01]

`make-backup-files` is `t`; backups go to a single central directory; version
control is on with a bounded number of kept versions; backup-by-copy is used so
hard links and file permissions survive.

*Rationale:* books are written here. `F-01` is the single highest-consequence
finding in this review.

*Test:* edit and save a file twice; confirm ≥ 2 numbered backup files exist in
the backup directory and none appear beside the original.

### R-011 · Auto-save is enabled — P0 [fix · F-01]

`auto-save-default` is `t`; auto-save files are written to the central state
directory, not beside the source file. Auto-save also fires on focus loss or
idle, so a crash costs at most a short interval of work.

*Test:* open a file, type without saving, wait past the auto-save interval,
confirm a recovery file exists. `M-x recover-this-file` offers it.

### R-012 · Lock files are enabled — P1 [fix · F-01]

`create-lockfiles` is `t`.

*Rationale:* Emacs is launched per-file from tmux panes, which makes concurrent
edits of the same file a real possibility.

*Test:* open the same file in two Emacs instances; the second warns.

### R-013 · Emacs obtains API keys from an encrypted store, not the environment — P0 [fix · F-02]

Emacs must read AI credentials via `auth-source` from `~/.authinfo.gpg`. The
configuration must not require `ANTHROPIC_API_KEY` etc. to be exported in the
shell.

*Rationale:* `F-02`. This removes Emacs's dependence on the plaintext exports;
it does not by itself remove the exports.

*Test:* with all three `*_API_KEY` variables unset in the environment, gptel
successfully completes a request.

### R-014 · The repository documents key rotation and never contains a key — P0 [fix · F-02]

`README` must instruct: rotate the three keys currently in `~/.bashrc` lines
136–140, store the new ones in `~/.authinfo.gpg`, and delete the plaintext
exports. `.gitignore` must exclude `.authinfo*`.

*Test:* `git grep -iE 'sk-ant-|sk-proj-|AIzaSy'` over the full history returns
nothing. (It does today — the exposure is in `~/.bashrc`, not the repo. Keep it
that way.)

### R-015 · Terminal clipboard works via OSC 52 — P0 [fix · F-11]

Killing text in terminal Emacs must place it on the Ghostty system clipboard,
through tmux, without `xclip` and without an X display. The dead `xclip` block
is removed.

*Rationale:* `F-11`. tmux is already `set-clipboard external`; Ghostty supports
OSC 52; this also works over SSH, which `xclip` cannot.

*Test:* in terminal Emacs inside tmux, `M-w` a region, then paste into a
different Ghostty window or another application. Text arrives.

*Note:* OSC 52 is write-mostly — terminals generally do not allow applications
to *read* the clipboard. Pasting into Emacs remains the terminal's job
(`Ctrl-Shift-V` / middle click). This asymmetry should be documented, not
worked around.

### R-016 · `recentf`, `savehist`, and `save-place` are preserved — P0 [preserve]

All three currently hold real, useful history (78 saved positions across four
book projects). The rebuild must keep them, keep `no-littering`-style path
discipline, and **must not delete the existing state files**.

*Test:* after migration, `M-x recentf-open-files` lists the same `.tex` files;
reopening `main.tex` lands on the previous position.

---

## C. Editing core

### R-020 · Exactly one delimiter-pairing mechanism is active — P0 [fix · F-05]

`electric-pair-mode` is the one to keep (built in, predictable, no extra
package). `smartparens` is removed.

*Test:* in a `python-mode` buffer, typing `(` inserts exactly `()`. Typing `)`
immediately after skips over rather than inserting a second.

### R-021 · `visual-line-mode` is on by default in prose buffers — P0 [preserve]

`text-mode`, `markdown-mode`, `org-mode`, and LaTeX modes enable
`visual-line-mode` automatically.

*Rationale:* this is the **only** command in `extended-command-history`, run
twice. It is the clearest single expression of intent in the whole state
directory. It should not need to be typed again.

*Test:* open a `.tex` and a `.md` file; `visual-line-mode` is on in both without
intervention.

### R-022 · Line numbers are absolute, and off in prose — P1 [new]

`display-line-numbers-type` becomes `t` (absolute) rather than `'relative`, and
line numbers are disabled in `text-mode`-derived buffers.

*Rationale:* relative line numbers pay off with `vim`-style counted motions,
which this config does not use (no evil-mode, no `C-u <n>` in any history). In
prose they are visual noise and they cost redisplay on long wrapped lines.
`goto-line` — which *is* in the history — wants absolute numbers.

*This is a preference call. Reject it if relative numbers are deliberate.*

*Test:* line numbers appear in `prog-mode`, absolute; absent in `.tex`/`.md`.

### R-023 · Undo uses built-in `undo-redo` — P1 [remove · undo-tree]

`undo-tree` is removed; `undo-redo` (Emacs 28+) is bound for redo.

*Rationale:* `undo-tree` 0.8.2 is the oldest package in the tree, persists undo
history to disk, and is a well-known source of stalls on large buffers — which
is what a 3000-line `main.tex` is. `vundo` is a lighter optional replacement if
tree visualisation is genuinely wanted.

*Test:* undo, then redo, then undo again, and confirm the sequence is coherent.
No `undo-tree` directory is created under `var/`.

### R-024 · Long-line handling stays enabled — P0 [preserve]

`global-so-long-mode` remains on.

*Test:* opening a minified file does not hang the editor.

---

## D. Keybindings

### R-030 · No two commands may claim the same key sequence or prefix — P0 [fix · F-03, F-04]

Prefix keys are allocated exactly once. A single table in the config is the
authority for every user-defined binding.

*Test:* an automated check (batch script committed to the repo) loads the config
and asserts that (a) no configured binding resolves to `unbound`, and (b) no key
listed in the keybinding table resolves to a different command than the table
says. This test must be runnable with one command and must pass.

### R-031 · `C-c t` is a single prefix with one owner — P0 [fix · F-03]

*Test:* `C-c t` resolves to the same thing in a `python-mode` buffer with eglot
active as in a `fundamental-mode` buffer.

### R-032 · `C-c p` is a single prefix with one owner — P0 [fix · F-04]

Either project commands or completion commands own it, not both. The other
moves.

*Test:* every binding documented under `C-c p` resolves to the documented
command.

### R-033 · Every primary binding is typeable in the target terminal — P0 [fix · F-06]

No command whose loss would be felt may be bound *only* to a
Control-punctuation or Control-Shift-letter sequence. Such bindings may exist as
GUI conveniences, but each must have a terminal-typeable alternative.

*Rationale:* `F-06`. The verification procedure is in `F-06`; run it before
finalising the map.

*Test:* for every entry in the keybinding table, `C-h k` in `emacs -nw` inside
tmux inside Ghostty reports the documented command.

### R-034 · Standard Emacs bindings are not silently repurposed — P1 [fix]

Any rebinding of a default Emacs key must be listed explicitly with its
justification. Currently unlisted casualties:

| Key | Default | Currently taken by |
|---|---|---|
| `M-y` | `yank-pop` | `minuet-complete-with-minibuffer` |
| `M-l` | `downcase-word` | `recenter-top-bottom` |
| `M-0` | `digit-argument` (numeric prefix 0) | `treemacs-select-window` |

`M-y` is the significant one: `C-y M-y M-y` to walk the kill ring is deep muscle
memory, and it is currently unavailable while `consult-yank-pop` sits on
`C-M-y` — itself a Control-punctuation-adjacent binding subject to `F-06`.

*Test:* `M-y` after `C-y` cycles the kill ring.

### R-035 · Which-key stays — P1 [preserve]

Discovery matters more, not less, once keys are reorganised. Emacs 30 ships
`which-key` built in; the ELPA package is no longer needed.

*Test:* holding `C-c` for the idle delay shows the prefix map.

---

## E. Interface

### R-040 · GUI components are guarded and lazy, not deleted — P0 [goal 1, 2] *(revised)*

*Was:* remove `all-the-icons`, `nerd-icons`, `kind-icon`, `dashboard`,
`centaur-tabs` outright. *Revised under decision D-1* (terminal primary, GUI
must also work):

- `centaur-tabs` — **removed.** Replaced by built-in `tab-bar` (`R-045`), and it
  is the cause of `F-03`.
- `dashboard` — **removed.** Emacs is invoked as `emacs <file>`, which suppresses
  the startup screen; it costs 30 ms to render nothing.
- `all-the-icons` / `nerd-icons` — **may be retained**, behind
  `(display-graphic-p)` and lazily loaded, contributing zero terminal startup
  cost. Optional: if goal 2 outweighs GUI icons, drop them.
- `kind-icon` — **removed.** Corfu's built-in annotations suffice.

No component may contribute startup cost in a frame type where it cannot render.

*Test:* in `emacs -nw`, after startup `(featurep 'nerd-icons)` → `nil`;
`(featurep 'centaur-tabs)` and `(featurep 'dashboard)` → `nil` in both frame
types.

### R-041 · Tree-sitter grammars are installed and routed — P1 [goal 3] *(revised)*

*Was:* "usable or absent," recommending removal. *Now:* install grammars for
Python, C, JSON, YAML, and Markdown, and route via `major-mode-remap-alist`.

*Rationale:* goal 3 asks for good syntax highlighting. Parser-based highlighting
is strictly better than regex `font-lock`, `treesit` is built in, and grammar
installation is a one-time command requiring **no package**. `treesit-auto`
stays removed — Emacs 30 handles this natively.

*Note:* LaTeX has no tree-sitter mode in Emacs 30, so the largest workload is
served by `font-lock` plus the chosen LaTeX backend regardless.

*Test:* `treesit-available-language-list` is non-empty; opening a `.py` file
reports `python-ts-mode`.

### R-045 · Workspace tabs via built-in `tab-bar` — P0 [new · D-2] [goal 4]

`tab-bar-mode` gives one tab per project workspace, each holding its own window
configuration. Zero dependencies.

| # | Capability | Test |
|---|---|---|
| a | Create / close / rename a tab | `C-x t 2`, `C-x t 0`, `C-x t r` work in `emacs -nw` |
| b | Switch by name with completion | A command lists tabs and jumps to the chosen one |
| c | Switch by number | Selecting tabs 1–4 works with one keystroke sequence |
| d | Renders cleanly at 80 columns | No wrapping, no stray escape sequences |
| e | Persists across restarts | Layouts survive a restart |
| f | Project switch reuses its tab | `project-switch-project` lands in that project's tab |

**Collision introduced by this requirement:** `C-x t` is the built-in
`tab-prefix-map`, but [`06-keybindings.md`](06-keybindings.md) assigns it to
treemacs. `tab-bar` owns the prefix; treemacs moves (suggested `C-c e`) or is
dropped, given `R-044` is P2 with no evidence of use. Also note `M-1`…`M-9` for
tab selection would displace `digit-argument`, the same defect as `M-0` in
`R-034` — prefer `C-x t <n>`.

### R-046 · 24-bit color is asserted, not assumed — P1 [new] [goal 3]

The configuration must not silently degrade to 256 colors when `COLORTERM` is
absent. Either assert the terminal's color capability at startup, or warn
visibly.

*Rationale:* measured — `COLORTERM=truecolor` yields 16,777,216 colors and its
absence yields 256, on the same `TERM=screen-256color`. Truecolor works today
but depends on a variable that is not reliably propagated over SSH, under
`sudo`, or into detached tmux sessions.

*Test:* `env -u COLORTERM TERM=screen-256color emacs -nw` still reports
`(display-color-cells)` = 16777216, or shows a startup warning naming the cause.

### R-047 · Font configuration is GUI-scoped and real — P1 [new · D-1] [goal 3]

Font settings are retained but must sit inside a `(display-graphic-p)` guard,
and the configured family must be installed on the machine.

*Rationale:* in the terminal the font is Ghostty's (`Berkeley Mono`, size 11)
and Emacs cannot influence it. The current unguarded `JetBrains Mono` / height
120 settings are inert there and should not be documented as working.

*Test:* `fc-list | grep -i "<family>"` matches whatever family the config names.
In `emacs -nw`, no font code executes.

### R-042 · Modeline is minimal and terminal-appropriate — P1 [new]

Show: buffer name, modified state, major mode, line/column, VCS branch, and LSP
state when active. Do not configure options for packages that are not installed.

*Rationale:* `F-15`. The current `doom-modeline` block sets ~35 variables, six
of which reference absent packages.

*Test:* the modeline config is under 15 lines and every variable it sets belongs
to a package that is installed.

### R-043 · Theme is legible in 24-bit terminal and in GUI — P1 [goal 3] *(revised)*

*Was:* P2, cosmetic, "follow the terminal's light/dark setting." *Raised to P1*
under goal 3.

One theme configuration must render correctly in both frame types. Selection
follows `R-008`: prefer `ef-themes` or `modus-themes` (GNU ELPA, GPG-signed,
explicitly designed for terminal contrast and accessibility) over `doom-themes`
(MELPA). A Catppuccin port is acceptable if matching Ghostty's
`light:Catppuccin Latte,dark:Catppuccin Mocha` pair is wanted.

Light/dark following the terminal remains desirable but stays **P2** — a manual
toggle is an acceptable answer.

*Test:* open `main.tex` and a `.py` file in both `emacs -nw` and GUI Emacs.
Syntax colors are distinguishable and comments readable in both.

### R-044 · A file-tree sidebar is available on demand but not required — P2 [preserve]

`treemacs` may stay, bound to `C-x t t` as today, but must not be loaded at
startup and must not own `M-0` (see `R-034`).

*Test:* `(featurep 'treemacs)` is `nil` until the key is pressed.

---

## F. Languages

### R-050 · LaTeX authoring is first-class — P0 [new · the largest gap]

This is the biggest single change in the rebuild. `.tex` is the most-edited file
type on this machine and has no support at all today.

Required capabilities:

| # | Capability | Acceptance test |
|---|---|---|
| a | Build the current document with `latexmk` from inside Emacs, with a keybinding | Open a multi-file paper's `paper/main.tex`, press the build key, a PDF is produced |
| b | Build errors are navigable | After a deliberate `\undefinedmacro`, jumping to the next error lands on the right line in the right `\input` file |
| c | Build runs asynchronously | Emacs stays responsive during a 20-second build |
| d | Multi-file projects resolve the master document | Editing `sections/01_introduction.tex` builds `main.tex`, not the section |
| e | Section/structure navigation | A command lists `\section`/`\subsection` in the current file and jumps to one |
| f | Cross-reference and citation completion | Typing `\ref{` offers labels defined in the project; `\cite{` offers bibliography keys |
| g | Math and environment editing help | Inserting an environment produces matching `\begin`/`\end` |
| h | `visual-line-mode` + spell check in prose | Covered by `R-021` and `R-053` |
| i | Forward search to a PDF viewer | Deferrable (P2) — terminal Emacs cannot host a PDF; an external viewer invocation is acceptable |

*Implementation note (not a requirement):* the realistic options are **AUCTeX**
(mature, `.deb` available as `auctex`, best reference/citation support, brings
RefTeX) or **`eglot` + `texlab`** (lighter, needs `texlab` installed which it
currently is not, weaker build integration). AUCTeX + RefTeX is the stronger fit
for book-length multi-file projects, and `latexmk` is already installed. Either
satisfies the table above; pick one.

### R-051 · Python uses the Astral toolchain, and only it — P0 [fix · F-09] *(revised 2026-08-12)*

Stated directly: **`uv`, `ty` and `ruff`. None of the older tooling.**

| Job | Tool | Not |
|---|---|---|
| Environments, dependencies, running | `uv` | pyvenv, virtualenvwrapper, poetry, pipenv, conda |
| Type checking + language server | `ty` (`ty server`) | pyright, basedpyright, pylsp, jedi-language-server, mypy |
| Linting | `ruff check` via flymake | flake8, pylint, pyflakes |
| Formatting | `ruff format` | black, isort, yapf, autopep8 |

The exclusion is enforced, not merely documented. This module previously carried
`mjb-python-lsp-servers` naming five alternatives
(`basedpyright-langserver`, `pyright-langserver`, `pylsp`,
`jedi-language-server`, `ruff-lsp`) and started whichever it found first — so
installing any of them for an unrelated reason would silently change which
server ran. It is now a single `mjb-python-lsp-command`, defaulting to
`("ty" "server")`.

eglot's own Python entry is **replaced** rather than appended to, for the same
reason: eglot ships a python entry that reaches for pylsp and pyright, and
leaving it in place would reintroduce the drift by the back door.

`ruff-lsp` is excluded on its own merits as well — it is deprecated upstream in
favour of `ruff server`. Neither is used here, because ruff already runs
directly for lint and format and a second language server would duplicate it.

Virtualenv detection understands `uv`-managed `.venv` directories, which needs
no uv-specific code: uv writes `.venv` into the project root, and a plain upward
search finds it. This replaces the `pyvenv` package (~600 lines).

*Test:* open a file in a `uv init` project. `major-mode` is `python-ts-mode`;
`python-shell-interpreter` is the project's `.venv/bin/python`;
`python-flymake-command` is ruff; eglot attaches with `ty server` and no other;
`C-c c f` reformats with ruff; a type error is reported through ty. Verified end
to end 2026-08-12 — ty flagged `Expected int, found Literal["2"]`.

### R-052 · Markdown support does not depend on absent binaries — P1 [fix · F-09]

`markdown-command` must either point at an installed binary or the preview
feature must be removed. `markdown-preview-mode` (which starts a local web
server) is removed unless preview is genuinely wanted.

*Test:* opening a `.md` file produces no error; no configuration references a
missing executable.

### R-053 · Spell checking is available in prose buffers — P1 [new]

Given the workload is books and papers, a spell checker matters more than an LSP
server. Use built-in `flyspell` or `jinx`, enabled in `text-mode`,
`markdown-mode`, and LaTeX modes, and configured to ignore LaTeX macros.

*Test:* a misspelled word in `chapters/01-arpanet.tex` is highlighted;
`\textbf` is not.

### R-054 · Rust support is removed — P1 [remove]

`rust-mode`, `cargo`, `flycheck-rust`, `flycheck`, the `rust-mode` eglot hook,
and `doom-modeline-env-enable-rust` are removed.

*Rationale:* no `.rs` file appears in `recentf`, `save-place`, or
`file-name-history`. `flycheck` exists in the tree only as `flycheck-rust`'s
dependency; the config otherwise uses flymake via eglot, so removing Rust also
removes a redundant second checker framework.

*Reversal cost is one `use-package` form* — if Rust returns, add it back.

*Test:* `(featurep 'rust-mode)` → `nil` after startup; a `.rs` file opens in
`prog-mode` without error.

### R-055 · Remaining format modes are retained — P1 [preserve]

`json-mode`, `yaml-mode`, `toml-mode`, `csv-mode`, `markdown-mode`, `org` stay,
all lazily loaded by file extension. `json-navigator` and `org-bullets` are
removed (no evidence of use, and `org-modern` supersedes the latter).

*Test:* opening `.json`, `.yaml`, `.toml`, `.csv` selects the right mode.

### R-056 · Git integration is preserved — P0 [preserve]

`magit` on `C-x g`, `diff-hl` in the fringe/margin.

*Note:* in a terminal there is no fringe; `diff-hl-margin-mode` is required for
the indicators to be visible at all. That is not currently configured.

*Test:* `C-x g` in a repo opens magit status. In terminal Emacs, an uncommitted
line shows a margin indicator.

---

## G. AI integration

### R-060 · Model IDs are current and live in one place — P0 [fix · F-10]

A single `mjb-ai.el` defines the model IDs as named variables at the top of the
file, with a comment noting that model IDs are retired periodically and where to
check.

*Current IDs:* `claude-opus-5` (flagship, 1M context), `claude-sonnet-5`
(balanced), `claude-haiku-4-5` (fast, 200K).

*Test:* `grep -c 'claude-' lisp/mjb-ai.el` shows the IDs appearing only in the
defvar block.

### R-061 · gptel is preserved and working — P0 [preserve · fix F-10]

Chat via `C-c g`, send via a terminal-typeable key, menu available. Backend:
Anthropic, key from `auth-source` (`R-013`), streaming on.

*Recommended model:* `claude-opus-5`.

*Test:* `C-c g`, ask a question, get a streamed answer with no API key in the
environment.

### R-062 · minuet inline completion is preserved, off by default, toggleable — P0 [preserve · fix F-10]

Auto-suggestion **stays disabled by default** with a toggle command, exactly as
commit `54ea9ff` established. That commit is the clearest recent statement of
intent in the repo and must not be undone.

*Recommended model:* `claude-haiku-4-5`. The configured request timeout is 2.5 s;
a fast, cheap model is the right tier for FIM-style completion, and the flagship
models now think by default, which is the wrong tradeoff at that timeout.

*Test:* opening a `.py` file produces no completion requests. The toggle enables
them. A suggestion appears within the timeout.

### R-063 · `M-y` is returned to `yank-pop` — P0 [fix · R-034]

minuet's minibuffer completion moves to a key that does not displace a core
binding.

*Test:* see `R-034`.

### R-064 · AI features degrade cleanly when unavailable — P1 [new]

With no credential configured, loading the config must not error, and invoking
an AI command must produce a clear message naming what to configure.

*Test:* with `~/.authinfo.gpg` absent, start Emacs (no error) and press `C-c g`
(actionable message, no backtrace).

---

## H. Installation and maintenance

### R-070 · Installation is a git checkout, not a copy — P0 [fix · F-12]

`~/.emacs.d` must be either a clone of this repository or a symlink to a clone.
Editing a config file must show up in `git status`.

*Rationale:* `F-12`. The stated goal is ongoing self-customization; a copy-based
installer makes every local edit invisible and then deletes it.

*Test:* edit `lisp/mjb-ui.el` in `~/.emacs.d`, run `git status` in the repo, see
the change.

### R-071 · Installation is never destructive — P0 [fix · F-12]

No `rm -rf` of an existing `~/.emacs.d`. If a config already exists, the
installer moves it aside with a timestamp and says so, or refuses and explains.
The state directories (`var/`, `etc/`, `eln-cache/`) are preserved across
installs.

*Test:* run the installer twice. The second run does not delete `var/` and does
not re-download packages.

### R-072 · `curl | bash` is not the documented path — P1 [fix · F-12]

The README leads with `git clone`. If a one-liner is kept, it must be secondary
and must recommend reading the script first.

*Test:* the first installation instruction in `README.md` is a `git clone`.

### R-073 · Bootstrap is idempotent and non-interactive — P1 [new]

Running the package bootstrap on an already-installed tree completes without
prompting and without reinstalling.

*Test:* run it twice; the second run is a no-op and exits 0.

---

## I. Documentation

### R-080 · The keybinding reference is generated, not hand-written — P1 [fix · F-14]

`KEYBOARD.md` is produced from the config's binding table by a committed script.

*Rationale:* five documented bindings are currently wrong. Prose kept in
parallel with code drifts; generated prose cannot.

*Test:* running the generator produces no diff against the committed file when
the config is unchanged.

### R-081 · README describes what the config does, verifiably — P1 [fix · F-14]

Every capability claim in `README.md` must correspond to something that works on
a clean install. Claims about missing binaries must be stated as prerequisites,
not as features.

*Test:* walk the README on a scratch `HOME`; every claim holds or is marked as
requiring an install step.

### R-082 · Each module file opens with a comment saying what it owns — P1 [new]

*Test:* every `lisp/mjb-*.el` begins with a `;;; Commentary:` block naming its
scope and its keybinding prefix, if any.

---

## Requirement index

| ID | P | Tag | Summary |
|---|---|---|---|
| R-001 | 0 | new | Modular config, `init.el` ≤ 80 lines |
| R-002 | 0 | fix | Native compilation enabled |
| R-003 | 0 | preserve | Compile warnings silent but reachable |
| R-004 | 0 | fix | Declared set + lockfile + drift detection *(revised — exact pinning is impossible on MELPA; see the entry)* |
| R-005 | 1 | new | `M-x mjb-remove-unused-packages` (wraps `package-autoremove`) |
| R-006 | 0 | goal 1 | Startup ≤ 0.21 s; measured **0.114 s** *(re-measured 2026-08-12; the 0.195 s reading timed stale `.elc`)* |
| R-007 | 0 | new | Zero load errors/warnings |
| R-008 | 0 | goal 2 | Provenance ranked; ≤ 20 MELPA packages *(new)* |
| R-009 | 0 | goal 2 | Signatures enforced (`package-check-signature` = `t`); **no exceptions**, 16/16 signed *(new)* |
| R-010 | 0 | fix | Versioned backups, central directory |
| R-011 | 0 | fix | Auto-save on |
| R-012 | 1 | fix | Lock files on |
| R-013 | 0 | fix | Keys from `auth-source`, not env |
| R-014 | 0 | fix | Document rotation; never commit a key |
| R-015 | 0 | fix | OSC 52 clipboard |
| R-016 | 0 | preserve | recentf/savehist/save-place kept, state not deleted |
| R-020 | 0 | fix | One pairing mechanism |
| R-021 | 0 | preserve | `visual-line-mode` in prose |
| R-022 | 1 | new | Absolute line numbers; none in prose |
| R-023 | 1 | remove | Built-in undo/redo |
| R-024 | 0 | preserve | `so-long` stays |
| R-030 | 0 | fix | No key or prefix collisions; automated check |
| R-031 | 0 | fix | `C-c t` single owner |
| R-032 | 0 | fix | `C-c p` single owner |
| R-033 | 0 | fix | All primary keys typeable in terminal |
| R-034 | 1 | fix | Standard bindings not silently repurposed |
| R-035 | 1 | preserve | which-key |
| R-040 | 0 | goal 1,2 | GUI components guarded + lazy, not deleted *(revised)* |
| R-041 | 1 | goal 3 | Tree-sitter grammars installed and routed *(revised)* |
| R-042 | 1 | new | Minimal modeline |
| R-043 | 1 | goal 3 | Theme legible in 24-bit terminal and GUI *(revised)* |
| R-044 | 2 | preserve | Treemacs on demand only — must vacate `C-x t` |
| R-045 | 0 | goal 4 | Workspace tabs via built-in `tab-bar` *(new)* |
| R-046 | 1 | goal 3 | 24-bit color asserted, not assumed *(new)* |
| R-047 | 1 | goal 3 | Font config GUI-scoped and real *(new)* |
| R-050 | 0 | new | **LaTeX authoring first-class** |
| R-051 | 0 | fix | Python is uv + ty + ruff **only**; older tooling excluded by construction *(revised)* |
| R-052 | 1 | fix | Markdown without missing binaries |
| R-053 | 1 | new | Spell check in prose |
| R-054 | 1 | remove | Rust support removed |
| R-055 | 1 | preserve | Format modes retained |
| R-056 | 0 | preserve | magit + diff-hl (margin mode in terminal) |
| R-060 | 0 | fix | Current model IDs in one place |
| R-061 | 0 | preserve | gptel working |
| R-062 | 0 | preserve | minuet, off by default, toggleable |
| R-063 | 0 | fix | `M-y` back to `yank-pop` |
| R-064 | 1 | new | AI degrades cleanly |
| R-070 | 0 | fix | Install = git checkout |
| R-071 | 0 | fix | Install never destructive |
| R-072 | 1 | fix | `curl \| bash` demoted |
| R-073 | 1 | new | Idempotent bootstrap |
| R-080 | 1 | fix | Generated keybinding reference |
| R-081 | 1 | fix | Verifiable README |
| R-082 | 1 | new | Module header comments |
