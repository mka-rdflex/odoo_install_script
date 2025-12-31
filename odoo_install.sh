#!/bin/bash

set -e

# =============================================================================
# Odoo Installation Script (Versions 12-19)
# =============================================================================
# Supported: Ubuntu/Debian based systems
# =============================================================================

OE_USER=$(whoami)
OE_HOME="/home/$OE_USER"

# =============================================================================
# Configuration Prompts
# =============================================================================

echo ""
echo "=============================================="
echo "  Odoo Installation Configuration"
echo "=============================================="
echo ""

# PostgreSQL password
read -p "Enter PostgreSQL password for Odoo user (default: admin): " OE_PASSWORD
OE_PASSWORD="${OE_PASSWORD:-admin}"

# Odoo version
read -p "Enter Odoo version (12-19): " version

if [[ ! $version =~ ^[0-9]+$ || $version -lt 12 || $version -gt 19 ]]; then
    echo "Error: Enter a valid version (integer between 12 and 19)"
    exit 1
fi

echo "Version is odoo${version}"
f_version="${version}.0"

# HTTP Port
read -p "Enter HTTP port (default: 8069): " OE_PORT
OE_PORT="${OE_PORT:-8069}"

# Longpolling Port (for live chat/websocket)
read -p "Enter Longpolling port (default: 8072): " OE_LONGPOLLING_PORT
OE_LONGPOLLING_PORT="${OE_LONGPOLLING_PORT:-8072}"

# Admin Master Password
read -p "Enter Odoo Master/Admin password (default: admin): " OE_SUPERADMIN
OE_SUPERADMIN="${OE_SUPERADMIN:-admin}"

# Worker configuration
read -p "Enter number of workers (0=disabled, recommended: CPU cores * 2 + 1, default: 0): " OE_WORKERS
OE_WORKERS="${OE_WORKERS:-0}"

# Database filter
read -p "Enter database filter regex (default: .*): " OE_DB_FILTER
OE_DB_FILTER="${OE_DB_FILTER:-.*}"

# Log level
echo "Log levels: debug, info, warning, error, critical"
read -p "Enter log level (default: info): " OE_LOG_LEVEL
OE_LOG_LEVEL="${OE_LOG_LEVEL:-info}"

# Limit memory
read -p "Enter memory limit per worker in MB (default: 1024): " OE_LIMIT_MEMORY_SOFT
OE_LIMIT_MEMORY_SOFT="${OE_LIMIT_MEMORY_SOFT:-1024}"
OE_LIMIT_MEMORY_SOFT=$((OE_LIMIT_MEMORY_SOFT * 1024 * 1024))

read -p "Enter hard memory limit per worker in MB (default: 2048): " OE_LIMIT_MEMORY_HARD
OE_LIMIT_MEMORY_HARD="${OE_LIMIT_MEMORY_HARD:-2048}"
OE_LIMIT_MEMORY_HARD=$((OE_LIMIT_MEMORY_HARD * 1024 * 1024))

# Directory paths
OE_HOME_EXT="$OE_HOME/workspace/odoo${version}"
CUSTOM="$OE_HOME/workspace/custom_addons/odoo${version}"
OE_CONFIG_DIR="$OE_HOME/workspace/odoo${version}/config"
OE_CONFIG_FILE="$OE_CONFIG_DIR/odoo${version}.conf"
OE_LOG_DIR="$OE_HOME/workspace/odoo${version}/logs"
OE_DATA_DIR="$OE_HOME/workspace/odoo${version}/data"

# Create directories
sudo -u "$OE_USER" mkdir -p "$OE_HOME_EXT"
sudo -u "$OE_USER" mkdir -p "$OE_CONFIG_DIR"
sudo -u "$OE_USER" mkdir -p "$OE_LOG_DIR"
sudo -u "$OE_USER" mkdir -p "$OE_DATA_DIR"
sudo -u "$OE_USER" mkdir -p "$CUSTOM"

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

# =============================================================================
# Generate Odoo Configuration File
# =============================================================================
generate_odoo_config() {
    echo -e "\n---- Generating Odoo configuration file ----"
    
    cat > "$OE_CONFIG_FILE" << EOF
[options]
; =============================================================================
; Odoo ${version} Configuration File
; Generated on: $(date)
; =============================================================================

; -----------------------------------------------------------------------------
; Admin & Security
; -----------------------------------------------------------------------------
admin_passwd = ${OE_SUPERADMIN}

; -----------------------------------------------------------------------------
; Database Configuration
; -----------------------------------------------------------------------------
db_host = localhost
db_port = 5432
db_user = ${OE_USER}
db_password = ${OE_PASSWORD}
db_name = False
db_filter = ${OE_DB_FILTER}
db_maxconn = 64
db_template = template0

; -----------------------------------------------------------------------------
; Paths
; -----------------------------------------------------------------------------
addons_path = ${OE_HOME_EXT}/odoo/addons,${CUSTOM}
data_dir = ${OE_DATA_DIR}

; -----------------------------------------------------------------------------
; Server Configuration
; -----------------------------------------------------------------------------
http_port = ${OE_PORT}
longpolling_port = ${OE_LONGPOLLING_PORT}
http_interface = 0.0.0.0
proxy_mode = False
xmlrpc = True

; -----------------------------------------------------------------------------
; Logging
; -----------------------------------------------------------------------------
logfile = ${OE_LOG_DIR}/odoo${version}.log
log_level = ${OE_LOG_LEVEL}
log_handler = :${OE_LOG_LEVEL}
logrotate = True
syslog = False

; -----------------------------------------------------------------------------
; Performance & Workers
; -----------------------------------------------------------------------------
workers = ${OE_WORKERS}
max_cron_threads = 2
limit_memory_soft = ${OE_LIMIT_MEMORY_SOFT}
limit_memory_hard = ${OE_LIMIT_MEMORY_HARD}
limit_time_cpu = 600
limit_time_real = 1200
limit_time_real_cron = 3600
limit_request = 8192

; -----------------------------------------------------------------------------
; Email Configuration (Update these for production)
; -----------------------------------------------------------------------------
; smtp_server = smtp.example.com
; smtp_port = 587
; smtp_ssl = False
; smtp_user = your-email@example.com
; smtp_password = your-email-password
; email_from = odoo@example.com

; -----------------------------------------------------------------------------
; Development Options (Disable in production)
; -----------------------------------------------------------------------------
dev_mode = False
; dev_mode = reload,qweb,xml

; -----------------------------------------------------------------------------
; Miscellaneous
; -----------------------------------------------------------------------------
list_db = True
without_demo = all
server_wide_modules = base,web
EOF

    chmod 640 "$OE_CONFIG_FILE"
    echo "Configuration file created: $OE_CONFIG_FILE"
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

#--------------------------------------------------
# Generate Configuration File
#--------------------------------------------------
generate_odoo_config

#--------------------------------------------------
# Create Helper Scripts
#--------------------------------------------------
echo -e "\n---- Creating helper scripts ----"

# Start script
cat > "$OE_HOME_EXT/start-odoo.sh" << EOF
#!/bin/bash
cd $OE_HOME_EXT/odoo
python3 odoo-bin -c $OE_CONFIG_FILE
EOF
chmod +x "$OE_HOME_EXT/start-odoo.sh"

# Stop script (for when running in background)
cat > "$OE_HOME_EXT/stop-odoo.sh" << EOF
#!/bin/bash
pkill -f "odoo-bin -c $OE_CONFIG_FILE" || echo "Odoo is not running"
EOF
chmod +x "$OE_HOME_EXT/stop-odoo.sh"

echo "Helper scripts created."

#--------------------------------------------------
# Installation Complete
#--------------------------------------------------
echo -e "\n=============================================="
echo "  Odoo $version Installation Complete!"
echo "=============================================="
echo ""
echo "Installation Details:"
echo "  - Odoo source:     $OE_HOME_EXT/odoo"
echo "  - Custom addons:   $CUSTOM"
echo "  - Config file:     $OE_CONFIG_FILE"
echo "  - Log file:        $OE_LOG_DIR/odoo${version}.log"
echo "  - Data directory:  $OE_DATA_DIR"
echo ""
echo "Configuration Summary:"
echo "  - HTTP Port:       $OE_PORT"
echo "  - Longpolling:     $OE_LONGPOLLING_PORT"
echo "  - Workers:         $OE_WORKERS"
echo "  - Log Level:       $OE_LOG_LEVEL"
echo "  - DB User:         $OE_USER"
echo ""
echo "Commands:"
echo "  Start Odoo:   $OE_HOME_EXT/start-odoo.sh"
echo "  Stop Odoo:    $OE_HOME_EXT/stop-odoo.sh"
echo "  View logs:    tail -f $OE_LOG_DIR/odoo${version}.log"
echo ""
echo "Or start manually:"
echo "  cd $OE_HOME_EXT/odoo && python3 odoo-bin -c $OE_CONFIG_FILE"
echo ""
echo "Access Odoo at: http://localhost:$OE_PORT"
echo ""
