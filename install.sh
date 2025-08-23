#!/bin/bash

# Emacs Configuration Installation Script
# This script backs up your existing configuration and installs the new one

set -e  # Exit on error

# Parse command line arguments
SKIP_PROMPTS=false
for arg in "$@"; do
    case $arg in
        --yes|-y)
            SKIP_PROMPTS=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --yes, -y    Skip all prompts and proceed with installation"
            echo "  --help, -h   Show this help message"
            exit 0
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration paths
EMACS_DIR="$HOME/.emacs.d"
EMACS_FILE="$HOME/.emacs"
BACKUP_ROOT="$HOME/.emacs.d.backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_ROOT/backup_$TIMESTAMP"
REPO_URL="https://github.com/mjbommar/mjbommar-emacs.git"
INSTALL_DIR="$HOME/mjbommar-emacs"

# Detect if running from curl/pipe or local directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/init.el" ]; then
    # Running locally from the repository
    SOURCE_DIR="$SCRIPT_DIR"
    RUNNING_FROM_CURL=false
else
    # Running from curl pipe
    SOURCE_DIR="$INSTALL_DIR"
    RUNNING_FROM_CURL=true
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Emacs Configuration Installer${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Function to clone repository when running from curl
clone_repository() {
    echo -e "${YELLOW}Downloading mjbommar-emacs configuration...${NC}"
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        echo -e "${RED}Error: git is not installed!${NC}"
        echo "Please install git and try again."
        exit 1
    fi
    
    # Use a temp directory for cloning
    TEMP_DIR="$(mktemp -d)"
    
    # Clone the repository to temp directory
    if git clone "$REPO_URL" "$TEMP_DIR/mjbommar-emacs"; then
        echo -e "${GREEN}✓ Repository downloaded successfully${NC}"
        SOURCE_DIR="$TEMP_DIR/mjbommar-emacs"
    else
        echo -e "${RED}Error: Failed to download repository${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
}

# Check if source directory is valid (only for local runs)
if [ "$RUNNING_FROM_CURL" = false ] && [ ! -f "$SOURCE_DIR/init.el" ]; then
    echo -e "${RED}Error: init.el not found in $SOURCE_DIR${NC}"
    echo "Please run this script from the mjbommar-emacs directory"
    exit 1
fi

# Function to create backup
backup_existing() {
    local backup_needed=false
    
    # Check if backup is needed
    if [ -d "$EMACS_DIR" ] || [ -f "$EMACS_FILE" ]; then
        backup_needed=true
    fi
    
    if [ "$backup_needed" = false ]; then
        echo -e "${GREEN}No existing configuration found. Skipping backup.${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Creating backup directory: $BACKUP_DIR${NC}"
    mkdir -p "$BACKUP_DIR"
    
    # Backup .emacs.d directory
    if [ -d "$EMACS_DIR" ]; then
        echo -e "${YELLOW}Backing up $EMACS_DIR...${NC}"
        cp -r "$EMACS_DIR" "$BACKUP_DIR/emacs.d"
        echo -e "${GREEN}✓ Backed up .emacs.d${NC}"
    fi
    
    # Backup .emacs file
    if [ -f "$EMACS_FILE" ]; then
        echo -e "${YELLOW}Backing up $EMACS_FILE...${NC}"
        cp "$EMACS_FILE" "$BACKUP_DIR/emacs"
        echo -e "${GREEN}✓ Backed up .emacs${NC}"
    fi
    
    # Create a restore script
    cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/bin/bash
# Restore script for this backup

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "This will restore your Emacs configuration from this backup."
echo "Current configuration will be overwritten!"
read -p "Are you sure? (y/N) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Remove current config
    rm -rf "$HOME/.emacs.d"
    rm -f "$HOME/.emacs"
    
    # Restore from backup
    if [ -d "$SCRIPT_DIR/emacs.d" ]; then
        cp -r "$SCRIPT_DIR/emacs.d" "$HOME/.emacs.d"
        echo "Restored .emacs.d"
    fi
    
    if [ -f "$SCRIPT_DIR/emacs" ]; then
        cp "$SCRIPT_DIR/emacs" "$HOME/.emacs"
        echo "Restored .emacs"
    fi
    
    echo "Restoration complete!"
else
    echo "Restoration cancelled."
fi
EOF
    chmod +x "$BACKUP_DIR/restore.sh"
    
    echo -e "${GREEN}✓ Backup complete at: $BACKUP_DIR${NC}"
    echo -e "${BLUE}  (A restore script has been created in the backup directory)${NC}"
}

# Function to install new configuration
install_config() {
    echo
    echo -e "${YELLOW}Installing new configuration...${NC}"
    
    # Remove old configuration
    if [ -d "$EMACS_DIR" ]; then
        echo -e "${YELLOW}Removing old .emacs.d...${NC}"
        rm -rf "$EMACS_DIR"
    fi
    
    if [ -f "$EMACS_FILE" ]; then
        echo -e "${YELLOW}Removing old .emacs file...${NC}"
        rm -f "$EMACS_FILE"
    fi
    
    # Copy configuration files to ~/.emacs.d
    echo -e "${YELLOW}Copying configuration to $EMACS_DIR...${NC}"
    mkdir -p "$EMACS_DIR"
    
    # Copy all files from source to destination
    cp -r "$SOURCE_DIR/"* "$EMACS_DIR/" 2>/dev/null || true
    cp -r "$SOURCE_DIR/".* "$EMACS_DIR/" 2>/dev/null || true
    
    # Remove .git directory if it was copied
    rm -rf "$EMACS_DIR/.git"
    
    echo -e "${GREEN}✓ Configuration installed to: $EMACS_DIR${NC}"
}

# Function to verify installation
verify_installation() {
    echo
    echo -e "${YELLOW}Verifying installation...${NC}"
    
    if [ -d "$EMACS_DIR" ]; then
        echo -e "${GREEN}✓ Configuration directory created successfully${NC}"
        
        if [ -f "$EMACS_DIR/init.el" ]; then
            echo -e "${GREEN}✓ init.el is accessible${NC}"
        else
            echo -e "${RED}✗ init.el not found!${NC}"
            return 1
        fi
        
        if [ -f "$EMACS_DIR/early-init.el" ]; then
            echo -e "${GREEN}✓ early-init.el is accessible${NC}"
        fi
    else
        echo -e "${RED}✗ Installation verification failed!${NC}"
        return 1
    fi
    
    return 0
}

# Function to show post-installation instructions
show_instructions() {
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Installation Complete!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Start Emacs - packages will auto-install on first run"
    echo "2. The first startup may take a few minutes to download packages"
    echo "3. If prompted about installing packages, answer 'y' (yes)"
    echo
    echo -e "${YELLOW}Important files:${NC}"
    echo "• Configuration: $EMACS_DIR/init.el"
    echo "• Keyboard shortcuts: $EMACS_DIR/KEYBOARD.md"
    echo "• README: $EMACS_DIR/README.md"
    echo
    echo -e "${YELLOW}Set up API keys (for AI features):${NC}"
    echo "Add to your ~/.bashrc or ~/.zshrc:"
    echo "  export OPENAI_API_KEY='your-key-here'"
    echo
    if [ -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}Your old configuration was backed up to:${NC}"
        echo "  $BACKUP_DIR"
        echo "  Run $BACKUP_DIR/restore.sh to restore it"
    fi
    echo
    echo -e "${GREEN}Enjoy your new Emacs configuration!${NC}"
}

# Main installation flow
main() {
    echo "This script will:"
    if [ "$RUNNING_FROM_CURL" = true ]; then
        echo "1. Download the mjbommar-emacs configuration"
        echo "2. Back up your existing Emacs configuration (if any)"
        echo "3. Install the configuration to ~/.emacs.d"
    else
        echo "1. Back up your existing Emacs configuration (if any)"
        echo "2. Copy this configuration to ~/.emacs.d"
    fi
    echo
    echo -e "${YELLOW}Target directory: $EMACS_DIR${NC}"
    echo
    
    if [ "$SKIP_PROMPTS" = false ]; then
        read -p "Do you want to continue? (y/N) " -n 1 -r
        echo
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Installation cancelled.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}Auto-installing (--yes flag detected)...${NC}"
    fi
    
    # Clone repository if running from curl
    if [ "$RUNNING_FROM_CURL" = true ]; then
        clone_repository
    fi
    
    # Perform installation steps
    backup_existing
    install_config
    
    # Clean up temp directory if running from curl
    if [ "$RUNNING_FROM_CURL" = true ] && [ -n "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    
    if verify_installation; then
        show_instructions
    else
        echo -e "${RED}Installation failed! Please check the errors above.${NC}"
        echo -e "${YELLOW}You can restore your backup by running:${NC}"
        echo "  $BACKUP_DIR/restore.sh"
        exit 1
    fi
}

# Run main function
main