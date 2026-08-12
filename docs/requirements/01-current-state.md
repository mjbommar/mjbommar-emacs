# 01 — Current state

Complete inventory of the configuration as it exists on 2026-08-11. This is
descriptive only; judgements are in [`03-findings.md`](03-findings.md).

## 1. Repository

```
mjbommar-emacs/
├── early-init.el      48 lines
├── init.el           948 lines, 63 `use-package` forms, monolithic
├── install.sh        298 lines
├── README.md         feature list + keybinding summary
├── KEYBOARD.md       keybinding reference
└── .gitignore
```

Four commits, all Aug 2025:

| Commit | Date | Change |
|---|---|---|
| `5c32106` | 2025-08-23 | Initial commit — the whole config in one go |
| `aca0e7e` | 2025-08-23 | `C-c l` / `M-l` recenter bindings, "collisions with latest ghostty config" |
| `ace6b06` | 2025-08-23 | xclip-based clipboard integration |
| `54ea9ff` | 2025-08-26 | Minuet auto-suggestions off by default, `C-c m` toggle |

`~/.emacs.d/init.el` is byte-identical to the repo copy. There is no drift to
reconcile.

## 2. Runtime environment (measured)

| Property | Value |
|---|---|
| Emacs | GNU Emacs 30.2 (Debian build) |
| Native compilation | Available (`native-comp-available-p` → `t`) |
| Tree-sitter | Available (`treesit-available-p` → `t`) |
| Installed grammars | **none** (`treesit-available-language-list` → `nil`) |
| Frame type in use | Terminal (`emacs main.tex` on `/dev/pts/7`) |
| Terminal stack | Ghostty → byobu/tmux 3.6 → Emacs |
| `TERM` | `screen-256color` |
| `XDG_SESSION_TYPE` | `tty` (a `DISPLAY=:0` exists but Emacs is not using it) |
| tmux `set-clipboard` | `external` (OSC 52 forwarding is available) |
| tmux `allow-passthrough` | `off` |
| Startup time | 0.23 s, 1 GC (measured, `emacs -nw`) |
| ELPA packages | 85 directories, 39 MB |
| `.elc` in ELPA | 339 |
| `.eln` in ELPA | **0** |
| User `eln-cache` | 104 KB — 6 trampolines only |

### Ghostty configuration (`~/.config/ghostty/config`)

```
theme = light:Catppuccin Latte,dark:Catppuccin Mocha
font-family = Berkeley Mono
font-size = 11
copy-on-select = true
scrollback-limit = 10000000
```

### External tooling present / absent

| Tool | Status | Referenced by |
|---|---|---|
| `rg` | ✅ `~/.cargo/bin/rg` | consult-ripgrep |
| `ruff` | ✅ `~/.local/bin/ruff` | reformatter definition |
| `rust-analyzer` | ✅ `~/.cargo/bin` | eglot (rust) |
| `git` | ✅ | magit |
| `pdflatex`, `latexmk` | ✅ (33 texlive packages) | *nothing in the config* |
| `uv` | ✅ | *nothing in the config* |
| `pyright` | ❌ missing | eglot python hook |
| `black` | ❌ missing | `python-black-on-save-mode` |
| `marksman` | ❌ missing | eglot markdown server entry |
| `pandoc` / `multimarkdown` | ❌ missing | `markdown-command` |
| `xclip` | ❌ missing | terminal clipboard block |
| `fd` | ❌ missing | consult-find fallback |
| `texlab` / `tectonic` | ❌ missing | — |

## 3. `early-init.el`

| Setting | Value | Note |
|---|---|---|
| `gc-cons-threshold` | `most-positive-fixnum` | reset to 2 MB on `emacs-startup-hook` |
| `gc-cons-percentage` | `0.6` | reset to `0.1` |
| `file-name-handler-alist` | nilled, restored on startup | standard |
| `package-enable-at-startup` | `nil` | `init.el` calls `package-initialize` itself |
| `inhibit-startup-*` | `t` | `inhibit-startup-echo-area-message` set to `t` |
| `default-frame-alist` | menu/tool/scrollbars off, 120×40 | GUI-only effect |
| `native-comp-deferred-compilation` | `nil` | **obsolete alias** since 29.1 |
| `frame-inhibit-implied-resize` | `t` | |
| `bidi-display-reordering` | `'left-to-right` (via `setq-default`) | |
| `bidi-inhibit-bpa` | `t` | |
| `fast-but-imprecise-scrolling` | `t` | |
| `redisplay-skip-fontification-on-input` | `t` | |

## 4. `init.el` — package inventory

63 `use-package` forms. Grouped by role:

**Package management / hygiene**: `package.el` (MELPA + GNU + NonGNU),
`use-package` (`:always-ensure t`, `:always-defer t`), `no-littering`.

**Theme & chrome**: `doom-themes` (doom-one, `:demand`), `doom-modeline`
(`:demand`, ~35 settings), `diminish`, `all-the-icons` (`:if
(display-graphic-p)`), `nerd-icons` (same guard), `dashboard` (`:demand`),
`centaur-tabs` (`:demand`, calls `centaur-tabs-group-by-projectile-project`),
`helpful`.

**Completion**: `vertico`, `orderless`, `marginalia`, `consult`, `corfu` (+
`corfu-popupinfo`, `corfu-history`, `corfu-quick`), `kind-icon`, `cape`.

**Version control**: `magit`, `diff-hl`.

**Programming**: `eglot` (python, rust, js, typescript, json, yaml + a
`marksman` server entry for markdown), `treesit-auto`, `project.el`,
`smart-jump`.

**Python**: `python`, `pyvenv`, `python-black`, `reformatter` (defines an
unbound `ruff-format`).

**Rust**: `rust-mode`, `cargo`, `flycheck-rust`.

**AI**: `gptel` (anthropic backend, `claude-opus-4-1-20250805`, org-mode chat
buffers), `minuet` (claude provider, `claude-sonnet-4-20250514`, 2 completions,
4000-char context, 2.5 s timeout, auto-suggestion off by default).

**Shell/terminal**: `vterm`, `eshell`, `eshell-syntax-highlighting`.

**Files**: `dired`, `dired-x`, `treemacs`, `treemacs-projectile`.

**Editing / QoL**: `which-key`, `hydra` (+ a `hydra-code` LSP menu), `avy`,
`expand-region`, `multiple-cursors`, `undo-tree`, `savehist`, `smartparens`,
`rainbow-delimiters`, `hl-todo`, `yasnippet`, `yasnippet-snippets`, `embark`,
`embark-consult`.

**Formats**: `markdown-mode`, `markdown-preview-mode`, `json-mode`,
`json-navigator`, `yaml-mode`, `toml-mode`, `csv-mode`, `org`, `org-bullets`.

**No LaTeX/TeX package of any kind.** No `pdf-tools`. No `auctex`.

## 5. Global editor settings

```elisp
(setq-default
 indent-tabs-mode nil        tab-width 4          fill-column 80
 truncate-lines t            create-lockfiles nil make-backup-files nil
 auto-save-default nil       ring-bell-function 'ignore
 scroll-margin 3             scroll-conservatively 101
 select-enable-clipboard t   mouse-wheel-progressive-speed nil
 display-line-numbers-type 'relative)
```

Modes enabled globally: `global-display-line-numbers-mode`, `column-number-mode`,
`global-auto-revert-mode`, `electric-pair-mode`, `show-paren-mode`,
`save-place-mode`, `recentf-mode`, `savehist-mode`, `global-so-long-mode`,
`global-undo-tree-mode`, `yas-global-mode`, `global-corfu-mode`,
`vertico-mode`, `marginalia-mode`, `which-key-mode`, `centaur-tabs-mode`,
`doom-modeline-mode`.

Line numbers are disabled by hook in `term-mode`, `vterm-mode`, `eshell-mode`,
`help-mode`, `treemacs-mode`.

## 6. Clipboard block (lines 57–77)

```elisp
(setq select-enable-clipboard t
      select-enable-primary t
      save-interprogram-paste-before-kill t)

(when (and (not (display-graphic-p)) (executable-find "xclip"))
  ;; interprogram-cut-function  -> start-process "xclip" …
  ;; interprogram-paste-function -> shell-command-to-string "xclip -o"
  )

(setq mouse-drag-copy-region t)
```

## 7. Fonts

```elisp
(defvar my/default-font "JetBrains Mono")
(defvar my/variable-font "Noto Sans")
(defvar my/font-size 120)
```
Applied to `default`, `fixed-pitch`, `variable-pitch` at load time.

## 8. Keybindings as resolved at runtime

Measured by loading the real config in batch and calling `key-binding`.

| Key | Resolves to |
|---|---|
| `C-c c` | `hydra-code/body` |
| `C-c t` | **prefix keymap** (centaur-tabs) |
| `C-c t t/n/p/</>/s/g/k/o` | centaur-tabs commands |
| `C-c p` | **prefix keymap** (`project-prefix-map`, autoloaded) |
| `C-c l`, `M-l` | `recenter-top-bottom` |
| `C-c m` | `my/toggle-minuet` |
| `C-c M` | `minuet-configure-provider` |
| `C-c g` | `gptel` |
| `C-c RET` | `gptel-send` |
| `C-c C-<return>` | `gptel-menu` |
| `C-c T` | `my/toggle-theme` |
| `M-y` | `minuet-complete-with-minibuffer` |
| `M-i` | `minuet-show-suggestion` |
| `M-0` | `treemacs-select-window` |
| `M-.` / `M-,` / `M-?` | `smart-jump-go` / `-back` / `-references` |
| `C-x g` | `magit-status` |
| `C-x t t` | `treemacs` |
| `C-M-y` | `consult-yank-pop` |
| `M-s l/r/f` | `consult-line` / `-ripgrep` / `-find` |
| `M-g g` | `consult-goto-line` |
| `M-g f/w/e` | `avy-goto-line` / `-word-1` / `-word-0` |
| `C-:` / `C-'` | `avy-goto-char` / `-char-2` |
| `C-.` / `C-;` / `C-h B` | `embark-act` / `-dwim` / `-bindings` |
| `C-=` | `er/expand-region` |
| `C->` / `C-<` / `C-c C-<` | multiple-cursors |
| `C-S-c C-S-c` | `mc/edit-lines` |
| `C-c d/D/r/i/t/n/a/f/h` | eglot commands, **`eglot-mode-map` only** |

`C-c p d/f/k/s/l/w/a/h` (cape) are declared in the config but resolve to
`unbound` — see [`03-findings.md`](03-findings.md) `F-04`.

## 9. `install.sh`

`curl | bash` installer. Flow: optionally `git clone` to a temp dir → `cp -r`
`~/.emacs.d` to `~/.emacs.d.backups/backup_<ts>/` (including the 39 MB `elpa/`)
and write a `restore.sh` → `rm -rf ~/.emacs.d` and `rm -f ~/.emacs` → `mkdir`
and `cp -r "$SOURCE_DIR/"*` plus `cp -r "$SOURCE_DIR/".*` → `rm -rf
~/.emacs.d/.git` → verify `init.el` exists.

There is no symlink or git-checkout mode; the installed copy is detached from
the repo, so local edits in `~/.emacs.d` are invisible to git and are destroyed
by the next install.

## 10. State directory contents

`no-littering` is in effect, so state lives under `etc/` and `var/`:

```
etc/custom.el          (package-selected-packages nil)
etc/yasnippet/snippets (empty)
etc/eshell/            (empty)
var/recentf-save.el    20 entries
var/save-place.el      78 entries
var/savehist.el        20 KB
var/projectile/        empty
var/org/               empty
var/auto-save/sessions (empty)
```
