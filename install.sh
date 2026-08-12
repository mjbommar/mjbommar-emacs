#!/usr/bin/env bash
# install.sh -- link this repository as your Emacs configuration.
#
# Requirements this satisfies:
#   R-070  the installed config is a git checkout, so edits show in git status
#   R-071  never destructive: an existing ~/.emacs.d is MOVED, never deleted,
#          and var/ etc/ eln-cache/ are carried across
#   R-073  idempotent: running twice is a no-op and does not re-download
#
# The previous version of this script did `rm -rf "$HOME/.emacs.d"` and then
# copied files in.  That deleted the 39 MB elpa tree on every run, and -- worse
# for a configuration whose whole point is that you keep editing it -- meant
# any edit made in ~/.emacs.d was invisible to git and destroyed by the next
# install.  Neither happens now.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${EMACS_DIR:-$HOME/.emacs.d}"
STAMP="$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
ASSUME_YES=0

usage() {
  cat <<EOF
Usage: $0 [--yes] [--dry-run] [--target DIR]

  --yes        do not prompt
  --dry-run    print what would happen and exit
  --target DIR install somewhere other than ~/.emacs.d

This creates a SYMLINK from \$TARGET to this repository, so that editing a
module here is the same as editing your live configuration.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y)   ASSUME_YES=1 ;;
    --dry-run)  DRY_RUN=1 ;;
    --target)   shift; TARGET="$1" ;;
    --help|-h)  usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

say()  { printf '%s\n' "$*"; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then say "  would: $*"; else "$@"; fi; }

# --- sanity ------------------------------------------------------------------
[ -f "$REPO/init.el" ] || { echo "no init.el in $REPO -- is this the repo?" >&2; exit 1; }
command -v emacs >/dev/null || { echo "emacs not found on PATH" >&2; exit 1; }
command -v git   >/dev/null || { echo "git not found on PATH" >&2; exit 1; }
# Signature verification is enforced (R-009) and needs gpg.  Without it
# package.el degrades silently, so fail loudly here instead.
command -v gpg   >/dev/null || {
  echo "gpg not found on PATH -- package signatures could not be verified." >&2
  echo "  Debian/Ubuntu: sudo apt install gnupg" >&2
  exit 1; }

EMACS_VER="$(emacs --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
case "$EMACS_VER" in
  30.*|31.*|3[2-9].*) ;;
  *) echo "warning: this config targets Emacs 30+; found $EMACS_VER" >&2 ;;
esac

say "repository: $REPO"
say "target:     $TARGET"
say "emacs:      $EMACS_VER"
say

# --- already installed? (R-073) ----------------------------------------------
if [ -L "$TARGET" ] && [ "$(readlink -f "$TARGET")" = "$REPO" ]; then
  say "Already linked to this repository. Nothing to do."
  say "To update:  git -C \"$REPO\" pull"
  exit 0
fi

# --- move an existing config aside (R-071) -----------------------------------
if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
  BACKUP="${TARGET}.pre-mjb.${STAMP}"
  say "An existing configuration is present at $TARGET."
  say "It will be MOVED to:"
  say "    $BACKUP"
  say "Nothing is deleted. Your state (var/ etc/ eln-cache/) is copied forward."
  say
  if [ "$ASSUME_YES" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    read -r -p "Continue? [y/N] " reply
    case "$reply" in [Yy]*) ;; *) echo "Aborted."; exit 1 ;; esac
  fi
  run mv "$TARGET" "$BACKUP"

  # Carry state forward so recentf/savehist/save-place survive (R-016).
  for d in var etc eln-cache; do
    if [ -d "$BACKUP/$d" ]; then
      say "  carrying forward: $d"
      run mkdir -p "$REPO/$d"
      if [ "$DRY_RUN" -eq 0 ]; then
        cp -an "$BACKUP/$d/." "$REPO/$d/" 2>/dev/null || true
      fi
    fi
  done
fi

# --- link --------------------------------------------------------------------
run ln -s "$REPO" "$TARGET"
say "Linked $TARGET -> $REPO"

# --- packages ----------------------------------------------------------------
# Bootstrap WITHOUT loading init.el.  init.el requires mjb-completion, which
# requires vertico -- so on a machine that does not have the packages yet,
# loading init first fails before it can install anything.  This is only
# invisible on a machine where elpa/ already exists.  mjb-package.el depends on
# nothing but `package' and `seq', so it can be loaded on its own.
say
say "Installing packages (first run downloads; later runs are a no-op)..."
if [ "$DRY_RUN" -eq 0 ]; then
  if ! emacs --batch \
      --eval "(setq user-emacs-directory \"$REPO/\")" \
      -l "$REPO/early-init.el" \
      --eval "(progn (add-to-list 'load-path \"$REPO/lisp\")
                     (require 'package) (package-initialize)
                     (require 'mjb-package) (mjb-install-packages))" 2>&1 \
      | grep -vE '^Loading|site-start|void: flavor' | sed 's/^/  /'; then
    echo "package installation failed -- see the output above" >&2
    exit 1
  fi

  # Now that the packages exist, the full configuration must load cleanly.
  say
  say "Verifying the full configuration loads..."
  if emacs --batch \
      --eval "(setq user-emacs-directory \"$REPO/\")" \
      -l "$REPO/early-init.el" -l "$REPO/init.el" \
      --eval '(message "mjb: configuration loaded")' 2>&1 \
      | grep -qE 'configuration loaded'; then
    say "  ok"
  else
    echo "the configuration did not load cleanly -- run ./scripts/smoke.sh" >&2
    exit 1
  fi
fi

# --- tree-sitter grammars ----------------------------------------------------
# Best-effort: needs git and a C compiler.  A failure here is not fatal -- the
# affected modes fall back (prog-mode for Rust, c-mode for C) and the message
# names the fix.
say
if [ "$DRY_RUN" -eq 0 ]; then
  if command -v cc >/dev/null || command -v gcc >/dev/null; then
    say "Installing tree-sitter grammars..."
    emacs --batch \
      --eval "(setq user-emacs-directory \"$REPO/\")" \
      -l "$REPO/early-init.el" -l "$REPO/init.el" \
      --eval '(mjb-install-treesit-grammars)' 2>&1 \
      | grep -E '^mjb:' | tail -1 || say "  grammars: some failed; M-x mjb-install-treesit-grammars to retry"
  else
    say "No C compiler: skipping tree-sitter grammars."
    say "  sudo apt install build-essential, then M-x mjb-install-treesit-grammars"
  fi
fi

# --- optional extras ---------------------------------------------------------
# Kept in step with what the modules actually call.  Each is optional; the
# config degrades rather than failing when one is missing.
say
missing=0
opt() { command -v "$1" >/dev/null || { say "  $2"; missing=1; }; }
say "Optional tools:"
opt rg            "project search needs ripgrep:      sudo apt install ripgrep"
opt uv            "python envs need uv:               curl -LsSf https://astral.sh/uv/install.sh | sh"
opt ruff          "python lint/format needs ruff:     uv tool install ruff"
opt ty            "python types need ty:              uv tool install ty"
opt rust-analyzer "rust LSP needs rust-analyzer:      rustup component add rust-analyzer"
opt rustfmt       "rust format needs rustfmt:         rustup component add rustfmt"
opt clangd        "C LSP needs clangd:                sudo apt install clangd"
opt aspell        "spell checking needs aspell:       sudo apt install aspell aspell-en"
opt latexmk       "LaTeX builds need latexmk:         sudo apt install latexmk texlive"
[ "$missing" -eq 0 ] && say "  all present."

cat <<EOF

Done.

  Config lives in : $REPO   (edit here; git status shows your changes)
  Update          : git -C $REPO pull
  API keys        : ~/.authinfo.gpg, e.g.
                      machine api.anthropic.com login apikey password sk-ant-...
                    Emacs never reads them from the environment.
  Verify          : ./scripts/smoke.sh
EOF
