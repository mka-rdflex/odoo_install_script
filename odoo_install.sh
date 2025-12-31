#!/bin/bash

set -e

# =============================================================================
# Odoo Installation Script (Versions 12-19)
# =============================================================================
# Supported: Ubuntu/Debian based systems
# =============================================================================

OE_USER=$(whoami)
OE_HOME="/home/$OE_USER"

# Prompt for PostgreSQL password (default: admin)
read -p "Enter PostgreSQL password for Odoo user (default: admin): " OE_PASSWORD
OE_PASSWORD="${OE_PASSWORD:-admin}"

read -p "Enter version (integer between 12 and 19): " version

if [[ ! $version =~ ^[0-9]+$ || $version -lt 12 || $version -gt 19 ]]; then
    echo "Error: Enter a valid version (integer between 12 and 19)"
    exit 1
fi

echo "Version is odoo${version}"

f_version="${version}.0"

OE_HOME_EXT="$OE_HOME/workspace/odoo${version}"
CUSTOM="$OE_HOME/workspace/custom_addons/odoo${version}"
sudo -u "$OE_USER" mkdir -p "$OE_HOME_EXT"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect current shell
detect_shell() {
    if [ -n "$BASH_VERSION" ]; then
        echo "bash"
    elif [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    else
        basename "$SHELL"
    fi
}

# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"

sudo apt install -y libpq-dev

# Check if the version is less than 15 (requires older Python via pyenv)
if [ "$version" -lt 15 ]; then
    echo "Version is less than 15. Proceeding with pyenv installation..."

    echo "Updating and upgrading system packages..."

    # Install dependencies
    echo "Installing required dependencies..."
    sudo apt install -y make build-essential libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
        libncurses5-dev libncursesw5-dev xz-utils tk-dev \
        libffi-dev liblzma-dev python3-pyopenssl git

    # Configure pyenv in shell files
    update_shell_config() {
        local shell_config=$1
        echo "Configuring $shell_config for pyenv..."
        if ! grep -q 'export PYENV_ROOT="$HOME/.pyenv"' "$shell_config"; then
            echo -e '\n# Pyenv configuration' >>"$shell_config"
            echo 'export PYENV_ROOT="$HOME/.pyenv"' >>"$shell_config"
            echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >>"$shell_config"
            echo 'eval "$(pyenv init --path)"' >>"$shell_config"
            echo 'eval "$(pyenv init -)"' >>"$shell_config"
        fi
    }

    # Install pyenv if not already installed
    if command_exists pyenv; then
        echo "pyenv is already installed."
    else
        echo "Installing pyenv..."
        curl https://pyenv.run | bash
        update_shell_config ~/.bashrc

        # Check and update ~/.zshrc if zsh is installed
        if command_exists zsh; then
            echo "zsh is installed. Updating ~/.zshrc..."
            update_shell_config ~/.zshrc
        else
            echo "zsh is not installed. Skipping ~/.zshrc configuration."
        fi

        # Reload shell configuration based on current shell
        echo "Reloading shell configuration..."
        current_shell=$(detect_shell)
        if [ "$current_shell" = "bash" ] && [ -f ~/.bashrc ]; then
            source ~/.bashrc
        elif [ "$current_shell" = "zsh" ] && [ -f ~/.zshrc ]; then
            source ~/.zshrc
        fi
    fi

    # Verify pyenv installation and setup Python 3.6
    if command_exists pyenv; then
        echo "pyenv installation completed successfully!"
        pyenv --version

        # Install Python 3.6 if not present
        if ! pyenv versions --bare | grep -q "^3\.6"; then
            echo "Installing Python 3.6..."
            pyenv install 3.6
        else
            echo "Python 3.6 is already installed."
        fi

        if [ -d "$OE_HOME_EXT" ]; then
            cd "$OE_HOME_EXT" || exit
            echo "Switched to directory: $OE_HOME_EXT"
            pyenv local 3.6

            # Verify local version is set (any 3.6.x)
            local_version=$(pyenv version-name)
            if [[ ! "$local_version" =~ ^3\.6 ]]; then
                echo "Error: pyenv local version not set correctly."
                exit 1
            fi
            echo "Python version set to: $local_version"
        else
            echo "Error: Directory $OE_HOME_EXT does not exist."
            exit 1
        fi
    else
        echo "Error: pyenv installation failed. Please check for errors."
        exit 1
    fi
else
    if [ -d "$OE_HOME_EXT" ]; then
        cd "$OE_HOME_EXT" || exit
        echo "Switched to directory: $OE_HOME_EXT"
    else
        echo "Error: Directory $OE_HOME_EXT does not exist."
        exit 1
    fi
fi

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------

echo -e "\n---- Installing the default PostgreSQL version based on Linux version ----"
sudo apt-get install -y postgresql postgresql-server-dev-all

echo -e "\n---- Creating the ODOO PostgreSQL User ----"
sudo -u postgres createuser -s "$OE_USER" 2>/dev/null || true
sudo -u postgres psql -c "ALTER ROLE \"$OE_USER\" WITH PASSWORD '$OE_PASSWORD';"

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 --"
sudo apt-get install -y python3 python3-pip
sudo apt-get install -y git python3-cffi build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng-dev libjpeg-dev gdebi

echo -e "\n---- Install python packages/requirements ----"

# Download requirements file and install
REQUIREMENTS_URL="https://github.com/odoo/odoo/raw/$f_version/requirements.txt"

if [ "$version" -lt 15 ]; then
    if pip3 install -r "$REQUIREMENTS_URL"; then
        echo "Python packages installed successfully."
    else
        echo "Error: Failed to install the required Python packages."
        exit 1
    fi
else
    if pip3 install -r "$REQUIREMENTS_URL" --break-system-packages; then
        echo "Python packages installed successfully."
    else
        echo "Error: Failed to install the required Python packages."
        exit 1
    fi
fi

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------

echo -e "\n---- Installing wkhtmltopdf ----"

# Detect OS and architecture for wkhtmltopdf
detect_wkhtmltopdf_package() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$VERSION_CODENAME" in
            jammy|kinetic|lunar|mantic|noble)
                echo "odoo-wkhtmltopdf-ubuntu-jammy-x86_64-0.13.0-nightly.deb"
                ;;
            focal)
                echo "odoo-wkhtmltopdf-ubuntu-focal-x86_64-0.13.0-nightly.deb"
                ;;
            *)
                # Default to jammy for newer versions
                echo "odoo-wkhtmltopdf-ubuntu-jammy-x86_64-0.13.0-nightly.deb"
                ;;
        esac
    else
        echo "odoo-wkhtmltopdf-ubuntu-jammy-x86_64-0.13.0-nightly.deb"
    fi
}

WKHTMLTOPDF_PKG=$(detect_wkhtmltopdf_package)
WKHTMLTOPDF_URL="https://github.com/odoo/wkhtmltopdf/releases/download/nightly/$WKHTMLTOPDF_PKG"

if wget -q "$WKHTMLTOPDF_URL" -O "$WKHTMLTOPDF_PKG"; then
    sudo dpkg -i "$WKHTMLTOPDF_PKG" || sudo apt-get install -f -y
    rm -f "$WKHTMLTOPDF_PKG"
    echo "wkhtmltopdf installed successfully."
else
    echo "Warning: Failed to download wkhtmltopdf. You may need to install it manually."
fi

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="

if git clone --depth 1 --branch "$f_version" https://www.github.com/odoo/odoo; then
    echo "Odoo $f_version cloned successfully."
else
    echo "Error: Failed to clone Odoo repository."
    exit 1
fi

echo -e "\n---- Create custom module directory ----"
sudo -u "$OE_USER" mkdir -p "$CUSTOM"

echo -e "\n=============================================="
echo "  Odoo $version Installation Complete!"
echo "=============================================="
echo ""
echo "Installation details:"
echo "  - Odoo location: $OE_HOME_EXT/odoo"
echo "  - Custom addons: $CUSTOM"
echo "  - PostgreSQL user: $OE_USER"
echo ""
echo "To start Odoo, run:"
echo "  cd $OE_HOME_EXT/odoo && python3 odoo-bin"
echo ""
