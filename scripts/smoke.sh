#!/usr/bin/env bash
# smoke.sh -- R-007 acceptance test: the config loads with zero errors and
# zero byte-compile warnings for code this repository owns.
set -uo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"
fail=0

echo "== byte-compiling every module =="
for f in lisp/mjb-*.el; do
  out=$(emacs -Q --batch \
          --eval "(progn (setq package-user-dir (expand-file-name \"elpa\" \"$REPO\"))
                         (require 'package) (package-initialize)
                         (add-to-list 'load-path (expand-file-name \"lisp\" \"$REPO\"))
                         (setq byte-compile-dest-file-function (lambda (_) \"/dev/null\"))
                         (byte-compile-file \"$f\"))" 2>&1 \
          | grep -E 'Warning|Error' || true)
  if [ -n "$out" ]; then
    echo "  FAIL $f"; echo "$out" | sed 's/^/        /'; fail=1
  else
    echo "  ok   $f"
  fi
done

echo
echo "== loading the full configuration =="
# NOTE --batch implies -q, so the init file is NOT loaded automatically.
# user-emacs-directory must be set before init.el, which derives load-path
# and package-user-dir from it.
out=$(emacs --batch \
        --eval "(setq user-emacs-directory \"$REPO/\")" \
        -l "$REPO/early-init.el" -l "$REPO/init.el" \
        --eval '(kill-emacs 0)' 2>&1 \
        | grep -vE '^Loading|^Repeat mode|site-start.d|Symbol.s value as variable is void: flavor' || true)
if [ -n "$out" ]; then
  echo "  output during load:"; echo "$out" | sed 's/^/        /'
  case "$out" in *Error*|*error*) fail=1 ;; esac
else
  echo "  ok   clean load"
fi

echo
echo "== keybinding table =="
if emacs --batch \
     --eval "(setq user-emacs-directory \"$REPO/\")" \
     -l "$REPO/early-init.el" -l "$REPO/init.el" \
     -l scripts/check-keys.el 2>&1 | grep -vE '^Loading|^Repeat mode|site-start|void: flavor' | sed 's/^/  /'; then
  :
else
  fail=1
fi

echo
echo "== package provenance + signatures (R-008, R-009) =="
if emacs --batch \
     --eval "(setq user-emacs-directory \"$REPO/\")" \
     -l "$REPO/early-init.el" -l "$REPO/init.el" \
     -l scripts/count-packages.el 2>&1 | grep -vE '^Loading|^Repeat mode|site-start|void: flavor' | sed 's/^/  /'; then
  :
else
  fail=1
fi

echo
echo "== generated docs are current (R-080) =="
emacs --batch \
  --eval "(setq user-emacs-directory \"$REPO/\")" \
  -l "$REPO/early-init.el" -l "$REPO/init.el" \
  -l scripts/gen-keyboard-doc.el >/dev/null 2>&1
if git -C "$REPO" diff --quiet KEYBOARD.md 2>/dev/null; then
  echo "  ok   KEYBOARD.md matches the key table"
else
  echo "  FAIL KEYBOARD.md is stale -- regenerate and commit"; fail=1
fi

echo
[ "$fail" -eq 0 ] && echo "SMOKE: PASS" || echo "SMOKE: FAIL"
exit "$fail"
