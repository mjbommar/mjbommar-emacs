# Requirements: Emacs configuration rebuild

Written 2026-08-11. Basis: full read of `init.el` (948 lines), `early-init.el`,
`install.sh`, plus measurement of the live installation at `~/.emacs.d`
(identical to the repo at time of writing) and of the surrounding environment
(Emacs 30.2, terminal + tmux + Ghostty, 85 installed ELPA packages).

## Purpose

The current configuration was generated largely in one pass in August 2025 and
has been touched three times since. It works, but a substantial fraction of it
targets a workflow and an environment that do not match how the machine is
actually used. This document set exists to:

1. Record what the configuration currently does — completely, not
   impressionistically.
2. Record what is actually being used, from evidence on disk rather than from
   the README.
3. Enumerate the concrete defects, with reproduction detail.
4. State the requirements for a replacement in a form that can be checked off
   and tested.

The requirements are the deliverable. Everything else is the justification for
them.

## Reading order

| File | Contents |
|---|---|
| [`01-current-state.md`](01-current-state.md) | Inventory: every package, every setting, every keybinding, as installed. |
| [`02-usage-evidence.md`](02-usage-evidence.md) | What the on-disk state says about actual use. The load-bearing document. |
| [`03-findings.md`](03-findings.md) | Numbered defects and risks (`F-01`…), each with evidence. |
| [`04-requirements.md`](04-requirements.md) | Numbered requirements (`R-001`…), each testable, each traced to a finding or a used feature. |
| [`05-target-architecture.md`](05-target-architecture.md) | Proposed file layout, package management, and conventions. |
| [`06-keybindings.md`](06-keybindings.md) | Target keymap, with the terminal-encoding constraints that shape it. |
| [`07-migration-plan.md`](07-migration-plan.md) | Phased execution with a verification gate per phase. |
| [`08-goals-and-decisions.md`](08-goals-and-decisions.md) | **Stated goals, decisions taken, and amendments to `04`.** Read after `04`. |

## The one-paragraph summary

The configuration is built for a graphical, mouse-and-icons IDE doing Python and
Rust development. The machine is used for terminal Emacs inside tmux inside
Ghostty, writing LaTeX books and Markdown, with Python second and no Rust at
all. Roughly a third of the installed packages cannot function in that
environment, several documented keybindings cannot be typed in it, backups and
auto-save are switched off on a machine used for long-form writing, native
compilation is disabled by an early-init setting that was renamed in Emacs 29,
both AI integrations point at model IDs that are past their retirement dates,
and API keys sit in plaintext in `~/.bashrc`. There is no LaTeX support of any
kind despite `.tex` being the most-edited file type.

None of that means the config is bad — it means it was written for a different
machine than the one it ended up on. The rebuild is a re-fit, not a rescue.

## Ownership note

The findings and requirements below are my analysis and my proposals. Where a
requirement preserves something you demonstrably use, it is marked
**[preserve]**. Where it is my suggestion for something new, it is marked
**[new]**. Where it removes something, it is marked **[remove]** and states what
evidence supports the removal. You should feel free to reject any **[new]** item
outright; they are the ones with the weakest claim on your time.
