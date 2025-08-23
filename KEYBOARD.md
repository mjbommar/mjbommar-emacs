# Emacs Keyboard Shortcuts Reference

A comprehensive guide to the most important keyboard shortcuts in our Emacs configuration.

## 🎯 Essential Commands

### File Operations
- `C-x C-f` - Find/open file
- `C-x C-s` - Save file
- `C-x C-w` - Save as...
- `C-x C-c` - Quit Emacs
- `C-x k` - Kill buffer

### Window Management
- `C-x 2` - Split window horizontally
- `C-x 3` - Split window vertically
- `C-x 1` - Delete other windows
- `C-x 0` - Delete current window
- `C-x o` - Switch to other window
- `M-0` - Focus Treemacs window

### Buffer Navigation
- `C-x b` - Switch buffer (enhanced with Consult)
- `C-x 4 b` - Switch buffer in other window
- `C-x C-b` - List buffers
- `C-x ←/→` - Previous/next buffer

### Tab Navigation (Centaur Tabs)
- `C-c t t` - Create new empty tab
- `C-c t p` - Previous tab
- `C-c t n` - Next tab
- `C-c t <` - Move current tab left
- `C-c t >` - Move current tab right
- `C-c t s` - Switch tab group
- `C-c t g` - Choose tab group with Counsel
- `C-c t k` - Kill/close current tab
- `C-c t o` - Kill other tabs in group
- `C-x C-f` - Open file (creates new tab)

## 🚀 Navigation & Movement

### Quick Navigation
- `C-:` - Jump to character (Avy)
- `C-'` - Jump to 2 characters (Avy)
- `M-g f` - Jump to line (Avy)
- `M-g w` - Jump to word (Avy)
- `M-g g` - Go to line number (Consult)

### Search
- `C-s` - Incremental search forward
- `C-r` - Incremental search backward
- `M-s l` - Search lines in buffer (Consult)
- `M-s r` - Ripgrep search in project (Consult)
- `M-s f` - Find files (Consult)

## 💻 Code Navigation & LSP

### Code Navigation Menu
- `C-c c` - Open code navigation hydra menu
  - `d` - Jump to definition
  - `D` - Definition in other window
  - `r` - Find references
  - `i` - Find implementation
  - `t` - Find type definition
  - `n` - Rename symbol
  - `a` - Code actions
  - `f` - Format buffer
  - `h` - Show documentation
  - `s` - Search symbol in buffer
  - `S` - Search in project

### Direct Navigation
- `C-c d` - Jump to definition
- `C-c r` - Find references
- `C-c n` - Rename symbol
- `C-c a` - Code actions
- `C-c f` - Format buffer
- `M-.` - Smart jump to definition
- `M-,` - Jump back
- `M-?` - Find references

## 🤖 AI Features

### GPTel (Chat Mode)
- `C-c g` - Start new GPT chat
- `C-c RET` - Send prompt to AI
- `C-c C-RET` - Open GPTel menu

### Minuet (Code Completion)
- `M-i` - Show AI suggestion as ghost text
- `M-y` - Complete with minibuffer (multiple suggestions)
- `C-c M` - Configure AI provider

When suggestion is active:
- `M-a` - Accept one line
- `M-A` - Accept entire suggestion
- `M-n` - Next suggestion
- `M-p` - Previous suggestion
- `M-e` - Dismiss suggestion

## ✏️ Editing

### Text Manipulation
- `C-=` - Expand region selection
- `C-w` - Cut (kill)
- `M-w` - Copy
- `C-y` - Paste (yank)
- `M-y` - Cycle through kill ring
- `C-/` - Undo
- `C-?` - Redo (with undo-tree)

### Multiple Cursors
- `C-S-c C-S-c` - Edit lines with multiple cursors
- `C->` - Mark next like this
- `C-<` - Mark previous like this
- `C-c C-<` - Mark all like this

### Completion
- `TAB` - Complete at point / Next suggestion (Corfu)
- `S-TAB` - Previous suggestion (Corfu)
- `RET` - Accept completion
- `C-c p p` - Trigger completion at point

### Cape Completions
- `C-c p d` - Complete with dabbrev
- `C-c p f` - Complete file path
- `C-c p k` - Complete keyword
- `C-c p s` - Complete Elisp symbol
- `C-c p l` - Complete entire line
- `C-c p w` - Complete dictionary word

## 🎨 UI & Appearance

- `C-c T` - Toggle between dark/light theme (uppercase T)
- `C-x C-+` - Increase font size (or `C-x C-=`)
- `C-x C--` - Decrease font size
- `C-x C-0` - Reset font size

## 📁 File Management

### Treemacs
- `C-x t t` - Toggle Treemacs sidebar
- `C-x t d` - Select directory in Treemacs
- `C-x t B` - Bookmark in Treemacs
- `C-x t 1` - Delete other windows (Treemacs focus)

### Project Management
- `C-c p f` - Find file in project
- `C-c p p` - Switch project
- `C-c p c` - Compile project
- `C-c p s` - Search in project

## 🔧 Version Control (Magit)

- `C-x g` - Open Magit status
- In Magit status:
  - `s` - Stage file/hunk
  - `u` - Unstage file/hunk
  - `c c` - Commit
  - `P p` - Push
  - `F p` - Pull
  - `b b` - Switch branch
  - `l l` - View log

## 🔍 Help & Discovery

- `C-h f` - Describe function
- `C-h v` - Describe variable
- `C-h k` - Describe key
- `C-h m` - Describe modes
- `C-h B` - Show all keybindings (Embark)
- `C-.` - Contextual actions (Embark)
- `C-;` - Do what I mean (Embark)

## 💡 Special Features

### Snippets (YASnippet)
- `TAB` - Expand snippet (after typing trigger)
- `C-x C-n` - Next field in snippet
- `C-x C-p` - Previous field in snippet

### Terminal
- `M-x vterm` - Open terminal emulator
- `M-x eshell` - Open Eshell

### Org Mode
- `TAB` - Cycle visibility
- `S-TAB` - Cycle entire buffer
- `C-c C-t` - Cycle TODO states
- `C-c C-c` - Execute code block / Update

## 🎮 Pro Tips

1. **Which-key**: Hold any prefix key (like `C-x` or `C-c`) for 0.5 seconds to see available commands
2. **Hydra**: Use `C-c c` to open the code navigation menu with visual hints
3. **Consult**: Most search commands support preview - navigate results with `C-n/C-p` to preview
4. **Embark**: Press `C-.` on any item (file, buffer, symbol) for contextual actions
5. **Corfu**: Auto-completion appears automatically after typing 2+ characters
6. **Minuet**: Auto-suggestions appear after 0.5 seconds of idle time in programming modes

## 📝 Mode-Specific

### Python
- `C-c C-p` - Start Python REPL
- `C-c C-c` - Send buffer to REPL
- `C-c C-r` - Send region to REPL

### Rust
- `C-c C-c C-r` - cargo run
- `C-c C-c C-b` - cargo build
- `C-c C-c C-t` - cargo test

### Markdown
- `C-c C-c p` - Preview markdown
- `C-c C-c l` - Insert link
- `C-c C-c i` - Insert image

## 🔄 Customization

To add your own keybindings, add to init.el:
```elisp
(global-set-key (kbd "YOUR-KEY") 'your-command)
```

Or for mode-specific bindings:
```elisp
(define-key python-mode-map (kbd "YOUR-KEY") 'your-command)
```