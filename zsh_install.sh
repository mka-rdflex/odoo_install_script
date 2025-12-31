#!/bin/bash

# =============================================================================
# ZSH + Powerlevel10k + Autosuggestions Complete Installation Script
# =============================================================================
# This script installs:
#   - Oh-My-Zsh
#   - Powerlevel10k theme
#   - zsh-autosuggestions plugin
#   - MesloLGS NF fonts (recommended for Powerlevel10k)
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[-]${NC} $1"
}

# Check if zsh is installed
check_zsh() {
    if ! command -v zsh &> /dev/null; then
        print_error "zsh is not installed. Please install zsh first."
        echo ""
        echo "Install zsh using:"
        echo "  Ubuntu/Debian: sudo apt install zsh"
        echo "  Fedora: sudo dnf install zsh"
        echo "  Arch: sudo pacman -S zsh"
        echo "  macOS: brew install zsh"
        exit 1
    fi
    print_success "zsh is installed"
}

# Check for required tools
check_requirements() {
    print_status "Checking requirements..."

    check_zsh

    if ! command -v git &> /dev/null; then
        print_error "git is not installed. Please install git first."
        exit 1
    fi
    print_success "git is installed"

    if ! command -v curl &> /dev/null; then
        print_error "curl is not installed. Please install curl first."
        exit 1
    fi
    print_success "curl is installed"
}

# Remove existing zsh configuration
clean_existing() {
    print_status "Removing existing zsh configuration..."

    rm -rf ~/.oh-my-zsh 2>/dev/null || true
    rm -f ~/.zshrc 2>/dev/null || true
    rm -f ~/.zshrc.* 2>/dev/null || true
    rm -f ~/.p10k.zsh 2>/dev/null || true

    print_success "Cleaned existing configuration"
}

# Install Oh-My-Zsh
install_ohmyzsh() {
    print_status "Installing Oh-My-Zsh..."

    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

    print_success "Oh-My-Zsh installed"
}

# Install Powerlevel10k theme
install_powerlevel10k() {
    print_status "Installing Powerlevel10k theme..."

    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

    print_success "Powerlevel10k installed"
}

# Install zsh-autosuggestions
install_autosuggestions() {
    print_status "Installing zsh-autosuggestions..."

    git clone https://github.com/zsh-users/zsh-autosuggestions \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"

    print_success "zsh-autosuggestions installed"
}

# Install MesloLGS NF fonts
install_fonts() {
    print_status "Installing MesloLGS NF fonts..."

    # Create fonts directory
    mkdir -p ~/.local/share/fonts

    # Download fonts
    cd ~/.local/share/fonts
    curl -fsSLO "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
    curl -fsSLO "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
    curl -fsSLO "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
    curl -fsSLO "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"

    # Refresh font cache (Linux only)
    if command -v fc-cache &> /dev/null; then
        fc-cache -f -v ~/.local/share/fonts/ > /dev/null 2>&1
    fi

    print_success "Fonts installed"
}

# Configure .zshrc
configure_zshrc() {
    print_status "Configuring .zshrc..."

    # Set Powerlevel10k theme
    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc

    # Add zsh-autosuggestions to plugins
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions)/' ~/.zshrc

    print_success ".zshrc configured"
}

# Set zsh as default shell
set_default_shell() {
    print_status "Setting zsh as default shell..."

    if [ "$SHELL" != "$(which zsh)" ]; then
        print_warning "Run 'chsh -s \$(which zsh)' to set zsh as your default shell"
    else
        print_success "zsh is already the default shell"
    fi
}

# Main installation
main() {
    echo ""
    echo "=============================================="
    echo "  ZSH + Powerlevel10k Installation Script"
    echo "=============================================="
    echo ""

    check_requirements

    echo ""
    read -p "This will remove existing zsh config. Continue? (y/n) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Installation cancelled"
        exit 0
    fi

    echo ""
    clean_existing
    install_ohmyzsh
    install_powerlevel10k
    install_autosuggestions
    install_fonts
    configure_zshrc
    set_default_shell

    echo ""
    echo "=============================================="
    echo "  Installation Complete!"
    echo "=============================================="
    echo ""
    print_warning "IMPORTANT: Set 'MesloLGS NF' as your terminal font"
    echo ""
    echo "Next steps:"
    echo "  1. Set terminal font to 'MesloLGS NF'"
    echo "  2. Run 'exec zsh' or restart your terminal"
    echo "  3. Run 'p10k configure' to customize your prompt"
    echo ""
}

main "$@"
