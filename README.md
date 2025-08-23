My Emacs Configuration

A minimal, aesthetic Emacs configuration optimized for Python and Rust development with AI integration.

# Quick Start

## 🚀 One-Line Installer

```bash
curl -fsSL https://raw.githubusercontent.com/mjbommar/mjbommar-emacs/master/install.sh | bash
```

Or skip all prompts with:
```bash
curl -fsSL https://raw.githubusercontent.com/mjbommar/mjbommar-emacs/master/install.sh | bash -s -- --yes
```

This will automatically:
- Back up your existing Emacs configuration
- Download and install the configuration to `~/.emacs.d`
- No symlinks - the files are copied directly (safe to delete temp files later)

## Manual Installation

1. **Backup your existing Emacs configuration** (if any):
   ```bash
   mv ~/.emacs.d ~/.emacs.d.backup
   ```

2. **Clone and install this configuration**:
   ```bash
   git clone https://github.com/mjbommar/mjbommar-emacs.git /tmp/mjbommar-emacs
   mkdir -p ~/.emacs.d
   cp -r /tmp/mjbommar-emacs/* ~/.emacs.d/
   rm -rf ~/.emacs.d/.git
   ```

3. **Install system dependencies**:
   ```bash
   # Fonts
   # Install JetBrains Mono: https://github.com/JetBrains/JetBrainsMono
   # Install Noto Sans: https://fonts.google.com/noto
   
   # Python LSP server
   pip install pyright  # or pylsp
   
   # Rust analyzer
   rustup component add rust-analyzer
   
   # Terminal emulator dependencies for vterm
   # Ubuntu/Debian:
   sudo apt install cmake libtool-bin libterm-dev
   # macOS:
   brew install cmake
   ```

4. **Start Emacs** - packages will auto-install on first run

5. **Configure AI keys** (optional):
   Set in `~/.bashrc` or `~/.zshrc`:
   ```bash
   export ANTHROPIC_API_KEY='sk-ant-...'  # For Claude (default)
   export OPENAI_API_KEY='sk-...'         # For OpenAI (optional)
   ```
   Or create `~/.authinfo` with:
   ```
   machine api.anthropic.com login apikey password YOUR_ANTHROPIC_KEY
   machine api.openai.com login apikey password YOUR_OPENAI_KEY
   ```

# Features

## ✨ Aesthetics & UI

- **Doom One** theme - Perfect balance of colors and contrast
- **Doom One Light** - Switch with `C-c T` for light mode (uppercase T)
- **Dashboard** - Beautiful startup screen with recent files & projects
- **JetBrains Mono** font with ligatures
- Clean, minimal UI with no distractions

## 🐍 Python Development

- Full LSP support via Eglot
- Virtual environment management (pyvenv)
- Black/Ruff formatting on save
- Syntax checking with Flymake

## 🦀 Rust Development

- Rust-analyzer LSP integration
- Cargo integration
- Format on save with rustfmt
- Flycheck for error checking

## 📝 File Formats

- **Markdown** - Full featured with live preview, GitHub flavor
- **JSON** - Syntax highlighting, formatting, LSP support
- **YAML** - Full support with LSP
- **TOML** - Cargo.toml, pyproject.toml support
- **CSV** - Table viewing and editing

## 🤖 AI Features

- **GPTel** - Complete ChatGPT/LLM integration for chat
  - `C-c g` - Start new chat session
  - `C-c RET` - Send prompt to AI
  - `C-c C-RET` - Open GPTel menu
  - Default: Claude Opus 4.1 (claude-opus-4-1-20250805)
  - Also supports OpenAI, Gemini, Ollama (local models)
  - Stream responses in real-time

- **Minuet** - Copilot-style inline code completion
  - `M-i` - Show AI suggestion as ghost text
  - `M-y` - Complete with minibuffer (multiple suggestions)
  - `C-c M` - Configure AI provider
  - Default: Claude Opus 4.1 (claude-opus-4-1-20250805)
  - When suggestion is shown:
    - `M-a` - Accept current line
    - `M-A` - Accept entire suggestion
    - `M-n/M-p` - Cycle through suggestions
    - `M-e` - Dismiss suggestion
  - Auto-suggestions enabled in programming modes

## 🚀 Productivity

- **Vertico** for fast minibuffer completion
- **Consult** for powerful search commands
- **Magit** for Git (`C-x g`)
- **Vterm** for full terminal emulation
- **Which-key** for discovering keybindings
- **Avy** for lightning-fast cursor navigation
- **YASnippet** for code templates and snippets
- **Treemacs** for file tree sidebar (`C-x t t`)
- **Embark** for contextual actions (`C-.`)

# Key Bindings

All keybindings follow standard Emacs conventions (no Vim emulation).

## Essential Commands

- `C-x g` - Open Magit
- `C-c g` - Start new GPTel chat
- `C-c RET` - Send to GPT
- `C-c t` - Toggle light/dark theme
- `C-x t t` - Toggle Treemacs sidebar
- `C-x b` - Switch buffer (enhanced with Consult)
- `M-s r` - Ripgrep search
- `C-=` - Expand region
- `C-:` - Avy jump to char
- `C-.` - Embark act (contextual actions)

## Code Navigation (NEW!)

- `C-c c` - Open code navigation menu (Hydra)
- `C-c d` - Jump to definition (like Doom's SPC c d)
- `C-c r` - Find references
- `C-c n` - Rename symbol
- `C-c a` - Code actions
- `M-.` - Smart jump to definition
- `M-,` - Jump back
- `M-?` - Find references

## Project Management

- `C-c p f` - Find file in project
- `C-c p p` - Switch project
- `C-c p c` - Compile project

# Customization

- Theme: Press `C-c T` to toggle between doom-one and doom-one-light
- Font size: Adjust `my/font-size` variable in init.el (default: 120)
- Font family: Change `my/default-font` to your preferred monospace font
- AI Model: The default is Claude Opus 4.1 - change via `C-c M` (Minuet) or `C-c C-RET` (GPTel)
- Additional packages: Add to init.el using `use-package` declarations with `:ensure t`

# Performance

- Startup time: < 0.5 seconds
- Lazy loading for most packages
- Optimized garbage collection
- Native compilation support (Emacs 28+)

# Troubleshooting

## Slow startup

Check `*Messages*` buffer for startup time and GC count.

## LSP not working

Ensure language servers are installed:
```bash
which pyright
which rust-analyzer
```

## Fonts not displaying correctly

Install JetBrains Mono and Noto Sans fonts system-wide:
```bash
# Ubuntu/Debian
sudo apt install fonts-jetbrains-mono fonts-noto

# macOS with Homebrew
brew tap homebrew/cask-fonts
brew install --cask font-jetbrains-mono
brew install --cask font-noto-sans
```

## AI features not working

Check your `~/.authinfo` file has correct API keys.

# Directory Structure

```
~/.emacs.d/
├── init.el          # Main configuration
├── early-init.el    # Early startup optimizations
├── CLAUDE.md        # Development guide
├── README.md        # This file
├── etc/            # (auto-created) no-littering config files
├── var/            # (auto-created) no-littering data files
└── elpa/           # (auto-created) installed packages
```

# Learning Resources

- [Emacs From Scratch](https://github.com/daviwil/emacs-from-scratch) - Video series
- [Mastering Emacs](https://www.masteringemacs.org/) - Comprehensive guide
- [Emacs Wiki](https://www.emacswiki.org/) - Community knowledge base

# Credits

Configuration inspired by:
- System Crafters' Emacs From Scratch
- Purcell's emacs.d
- Prelude
- Centaur Emacs
