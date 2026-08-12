# 07 — Migration plan

Seven phases. Each has an exit gate that must pass before the next begins.
Nothing touches `~/.emacs.d` until Phase 6.

The whole plan is built to run **beside** the current config:

```
emacs -nw --init-directory ~/src/mjbommar-emacs-next
```

`--init-directory` is Emacs 29+. Until Phase 6, the working config keeps
working.

---

## Phase 0 — Decisions (no code)

Four choices shape everything downstream. They should be made explicitly rather
than defaulted into.

| Decision | Options | Recommendation |
|---|---|---|
| LaTeX backend (`R-050`) | AUCTeX + RefTeX / eglot + texlab | **AUCTeX** — mature, `latexmk` already installed, best multi-file and citation support |
| Package manager (`R-004`) | elpaca / straight / package.el | **elpaca** — async install, native lockfile |
| GUI Emacs also in scope? | yes / no | Answer determines whether `F-06`-affected bindings return under a guard |
| Keep embark + multiple-cursors? | yes / no | No evidence of use; both hit by `F-06` |

Also do the two out-of-repo safety items now, since they are independent of
everything else:

- Rotate the three API keys exposed in `~/.bashrc:136-140` (`F-02`).
- Run the `F-06` terminal key test and record the results in
  [`06-keybindings.md`](06-keybindings.md).

**Gate:** four decisions recorded; keys rotated; key-test results written down.

---

## Phase 1 — Skeleton and safety

Build the module structure and everything in requirement group **B**. This is
the phase that removes the S1 risks, so it comes first even though it is not the
most interesting.

Scope: `early-init.el`, `init.el`, `mjb-core.el`, package bootstrap, plus
`R-002` (native comp), `R-010`–`R-012` (backups, auto-save, lock files),
`R-013`–`R-014` (auth-source), `R-015` (OSC 52), `R-016` (state preservation),
`R-007` (clean load), `scripts/smoke.sh`.

**Gate:**
- `scripts/smoke.sh` exits 0 with no warnings.
- Edit-and-save twice produces numbered backups in the central directory.
- Auto-save recovery file appears after the idle interval.
- `M-w` in the new config pastes into another Ghostty window.
- gptel authenticates with `ANTHROPIC_API_KEY` unset.
- `.eln` files appear under `eln-cache` after a restart.

---

## Phase 2 — Editing, completion, keys

Groups **C** and **D**, plus `mjb-completion.el` and `mjb-editing.el`.

Scope: vertico / orderless / marginalia / consult / corfu / cape (`R-055`
adjacent), `R-020` (single pairing), `R-021` (`visual-line-mode`), `R-022`
(line numbers), `R-023` (undo), `R-024` (so-long), the full keybinding table
(`R-030`–`R-035`), and `scripts/check-keys.el`.

**Gate:**
- `scripts/check-keys.el` passes: no entry unbound, no entry resolving to an
  unexpected command.
- `M-y` after `C-y` cycles the kill ring.
- Typing `(` in a Python buffer inserts exactly `()`.
- Every key in the table verified by hand with `C-h k` in the real terminal.

---

## Phase 3 — LaTeX

The largest new capability (`R-050`). Give it its own phase; it is the reason
the rebuild is worth doing.

**Gate** — all against real files, not a toy document:

- `<redacted-paper>/paper/main.tex` builds to PDF from inside Emacs.
- Editing `sections/01_introduction.tex` and pressing build compiles
  `main.tex`, not the section.
- A deliberate `\undefinedmacro` produces a navigable error that lands on the
  correct line in the correct file.
- `\ref{` completes labels defined elsewhere in the project.
- `\cite{` completes bibliography keys.
- The build runs asynchronously — Emacs stays responsive.
- `<redacted-book>`, `<redacted-book>`, and
  `<redacted-book>/book` all build too. Four projects, four
  different structures; one working on its own proves little.

---

## Phase 4 — Prose, languages, VC

Groups **E** and **F** minus LaTeX.

Scope: `mjb-prose.el` (`R-053` spell check, markdown `R-052`), `mjb-python.el`
(`R-051` ruff), `mjb-formats.el` (`R-055`), `mjb-vc.el` (`R-056` incl.
`diff-hl-margin-mode`), `mjb-ui.el` (`R-040`–`R-044`), removals (`R-054` Rust,
`R-041` tree-sitter).

**Gate:**
- Opening `<redacted_project>/driver.py` produces no LSP error in `*Messages*`; saving
  formats with ruff; an unused import is flagged.
- A misspelling in `chapters/01-arpanet.tex` is highlighted and `\textbf` is
  not.
- `C-x g` opens magit; an uncommitted line shows a **margin** indicator in
  terminal Emacs.
- `(featurep 'rust-mode)`, `(featurep 'centaur-tabs)`, `(featurep 'dashboard)`
  all `nil`.
- Startup still under 0.5 s (`R-006`).

---

## Phase 5 — AI

Group **G**.

**Gate:**
- `C-c a a` opens a chat and streams a response on `claude-opus-5`.
- Opening a `.py` file sends no completion request; `C-c t a` enables them;
  a suggestion arrives inside the 2.5 s timeout on `claude-haiku-4-5`.
- With `~/.authinfo.gpg` moved aside, Emacs starts without error and `C-c a a`
  gives an actionable message rather than a backtrace.
- Model IDs appear only in the defvar block of `mjb-ai.el`.

---

## Phase 6 — Cut over

Only now does `~/.emacs.d` change.

1. `mv ~/.emacs.d ~/.emacs.d.pre-rebuild` — **move, do not delete.** The 78
   saved positions and 20 recent files in `var/` are real state.
2. Clone the repo to `~/.emacs.d` (or symlink from a working tree) — `R-070`.
3. Copy `var/` and `etc/` back from the moved-aside directory — `R-016`.
4. Bootstrap packages; confirm the lockfile reproduces.
5. Use it for a full working day on real files before deleting anything.

**Gate:**
- `git status` in `~/.emacs.d` is clean and shows the repo (`R-070`).
- `M-x recentf-open-files` lists the same `.tex` files as before.
- Reopening `main.tex` lands on the previous position.
- Editing a module file in `~/.emacs.d` shows up in `git status`.
- Running the installer twice does not delete `var/` and does not re-download
  packages (`R-071`, `R-073`).

---

## Phase 7 — Documentation

Group **I**, done last so it describes what exists rather than what was planned.

Scope: `scripts/gen-keyboard-doc.el` and a regenerated `KEYBOARD.md` (`R-080`),
rewritten `README.md` (`R-081`, `R-072` — lead with `git clone`), module header
comments (`R-082`), and the `R-014` key-rotation note.

**Gate:**
- Regenerating `KEYBOARD.md` produces no diff.
- Every claim in `README.md` verified on a scratch `HOME`.
- `git grep -iE 'sk-ant-|sk-proj-|AIzaSy'` over full history returns nothing.

---

## Rollback

At every phase before 6, rollback is "stop using `--init-directory`". After
Phase 6 it is:

```
mv ~/.emacs.d ~/.emacs.d.new && mv ~/.emacs.d.pre-rebuild ~/.emacs.d
```

Keep `~/.emacs.d.pre-rebuild` until the new config has survived a full week,
including at least one complete book build.

---

## Effort shape

Rough relative sizing, not a schedule:

| Phase | Size | Risk |
|---|---|---|
| 0 Decisions | small | low |
| 1 Skeleton + safety | medium | low — mostly built-in settings |
| 2 Editing + keys | medium | medium — the key table needs hand verification |
| 3 LaTeX | **large** | **high** — new capability, four real projects to satisfy |
| 4 Prose/langs/VC | medium | low |
| 5 AI | small | low — two model strings and an auth source |
| 6 Cut over | small | medium — state preservation is the risk |
| 7 Docs | small | low |

Phase 3 is where the value is and where the time goes. Phases 1 and 5 are the
ones that fix things that are broken right now.

## Sequencing note

If you want the *fastest* path to "things that are broken now are fixed," Phases
1 and 5 alone deliver: backups and auto-save on, keys out of the environment,
clipboard working, native compilation on, and both AI integrations functional
again. That is a meaningful subset and it does not require committing to the
full rebuild.
