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
say
say "Installing packages (first run downloads; later runs are a no-op)..."
if [ "$DRY_RUN" -eq 0 ]; then
  emacs --batch \
    --eval "(setq user-emacs-directory \"$REPO/\")" \
    -l "$REPO/early-init.el" -l "$REPO/init.el" \
    --eval '(mjb-install-packages)' 2>&1 | tail -1
fi

# --- optional extras ---------------------------------------------------------
say
say "Optional, and not installed automatically:"
command -v libtool  >/dev/null || say "  vterm needs libtool:  sudo apt install libtool libtool-bin"
command -v rg       >/dev/null || say "  project search needs ripgrep:  cargo install ripgrep"
command -v ruff     >/dev/null || say "  python lint/format needs ruff:  uv tool install ruff"
command -v aspell   >/dev/null || say "  spell checking needs aspell:  sudo apt install aspell aspell-en"
command -v latexmk  >/dev/null || say "  LaTeX builds need latexmk:  sudo apt install latexmk"

cat <<EOF

Done.

  Config lives in : $REPO   (edit here; git status shows your changes)
  Tree-sitter     : M-x mjb-install-treesit-grammars   (one time)
  API keys        : ~/.authinfo.gpg, e.g.
                      machine api.anthropic.com login apikey password sk-ant-...
                    Emacs never reads them from the environment.
  Verify          : ./scripts/smoke.sh
EOF
