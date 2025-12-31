#!/bin/bash

set -e

# =============================================================================
# Odoo Installation Script (Versions 12-19)
# =============================================================================
# Supported: Ubuntu/Debian based systems
# Features: TUI Menu, Docker Support, SMTP Config, UFW Firewall
# =============================================================================

OE_USER=$(whoami)
OE_HOME="/home/$OE_USER"

# Default values
OE_PASSWORD="admin"
OE_PORT="8069"
OE_LONGPOLLING_PORT="8072"
OE_SUPERADMIN="admin"
OE_WORKERS="0"
OE_DB_FILTER=".*"
OE_LOG_LEVEL="info"
OE_LIMIT_MEMORY_SOFT="1024"
OE_LIMIT_MEMORY_HARD="2048"
INSTALL_TYPE="native"
CONFIGURE_UFW="no"
CONFIGURE_SMTP="no"

# SMTP defaults
SMTP_SERVER=""
SMTP_PORT="587"
SMTP_SSL="False"
SMTP_USER=""
SMTP_PASSWORD=""
EMAIL_FROM=""

# =============================================================================
# Helper Functions
# =============================================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

detect_shell() {
    if [ -n "$BASH_VERSION" ]; then
        echo "bash"
    elif [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    else
        basename "$SHELL"
    fi
}

check_whiptail() {
    if ! command_exists whiptail; then
        echo "Installing whiptail for interactive menu..."
        sudo apt-get update && sudo apt-get install -y whiptail
    fi
}

# =============================================================================
# Interactive TUI Menu Functions
# =============================================================================

show_welcome() {
    whiptail --title "Odoo Installation Script" --msgbox \
"Welcome to the Odoo Installation Script!

This script will help you install Odoo ERP (versions 12-19) with:
- Native installation OR Docker-based setup
- Auto-generated configuration file
- Optional SMTP email configuration
- Optional UFW firewall setup

Press OK to continue." 16 60
}

select_install_type() {
    INSTALL_TYPE=$(whiptail --title "Installation Type" --menu \
"Choose installation method:" 15 60 2 \
"native" "Traditional installation (recommended)" \
"docker" "Docker-based installation" \
3>&1 1>&2 2>&3) || exit 1
}

select_version() {
    version=$(whiptail --title "Odoo Version" --menu \
"Select Odoo version to install:" 20 60 8 \
"19" "Odoo 19 (Latest)" \
"18" "Odoo 18" \
"17" "Odoo 17" \
"16" "Odoo 16 (LTS)" \
"15" "Odoo 15" \
"14" "Odoo 14" \
"13" "Odoo 13" \
"12" "Odoo 12" \
3>&1 1>&2 2>&3) || exit 1
    
    f_version="${version}.0"
}

configure_basic_settings() {
    OE_PASSWORD=$(whiptail --title "PostgreSQL Password" --inputbox \
"Enter PostgreSQL password for Odoo user:" 10 60 "$OE_PASSWORD" \
3>&1 1>&2 2>&3) || exit 1

    OE_PORT=$(whiptail --title "HTTP Port" --inputbox \
"Enter HTTP port for Odoo web interface:" 10 60 "$OE_PORT" \
3>&1 1>&2 2>&3) || exit 1

    OE_LONGPOLLING_PORT=$(whiptail --title "Longpolling Port" --inputbox \
"Enter Longpolling port (for live chat/websocket):" 10 60 "$OE_LONGPOLLING_PORT" \
3>&1 1>&2 2>&3) || exit 1

    OE_SUPERADMIN=$(whiptail --title "Master Password" --passwordbox \
"Enter Odoo Master/Admin password:" 10 60 \
3>&1 1>&2 2>&3) || exit 1
    OE_SUPERADMIN="${OE_SUPERADMIN:-admin}"
}

configure_performance() {
    OE_WORKERS=$(whiptail --title "Workers" --inputbox \
"Enter number of workers (0=disabled, recommended: CPU cores * 2 + 1):" 10 60 "$OE_WORKERS" \
3>&1 1>&2 2>&3) || exit 1

    OE_LOG_LEVEL=$(whiptail --title "Log Level" --menu \
"Select logging level:" 15 60 5 \
"info" "Standard logging (recommended)" \
"debug" "Verbose debugging" \
"warning" "Warnings only" \
"error" "Errors only" \
"critical" "Critical errors only" \
3>&1 1>&2 2>&3) || exit 1

    OE_LIMIT_MEMORY_SOFT=$(whiptail --title "Memory Limit (Soft)" --inputbox \
"Enter soft memory limit per worker in MB:" 10 60 "$OE_LIMIT_MEMORY_SOFT" \
3>&1 1>&2 2>&3) || exit 1

    OE_LIMIT_MEMORY_HARD=$(whiptail --title "Memory Limit (Hard)" --inputbox \
"Enter hard memory limit per worker in MB:" 10 60 "$OE_LIMIT_MEMORY_HARD" \
3>&1 1>&2 2>&3) || exit 1
}

configure_smtp() {
    if whiptail --title "Email Configuration" --yesno \
"Do you want to configure SMTP email settings?" 10 60; then
        CONFIGURE_SMTP="yes"
        
        SMTP_SERVER=$(whiptail --title "SMTP Server" --inputbox \
"Enter SMTP server address (e.g., smtp.gmail.com):" 10 60 "" \
3>&1 1>&2 2>&3) || SMTP_SERVER=""

        SMTP_PORT=$(whiptail --title "SMTP Port" --inputbox \
"Enter SMTP port (587 for TLS, 465 for SSL, 25 for plain):" 10 60 "587" \
3>&1 1>&2 2>&3) || SMTP_PORT="587"

        if whiptail --title "SMTP SSL" --yesno \
"Use SSL for SMTP connection? (Select No for TLS/STARTTLS)" 10 60; then
            SMTP_SSL="True"
        else
            SMTP_SSL="False"
        fi

        SMTP_USER=$(whiptail --title "SMTP Username" --inputbox \
"Enter SMTP username/email:" 10 60 "" \
3>&1 1>&2 2>&3) || SMTP_USER=""

        SMTP_PASSWORD=$(whiptail --title "SMTP Password" --passwordbox \
"Enter SMTP password:" 10 60 \
3>&1 1>&2 2>&3) || SMTP_PASSWORD=""

        EMAIL_FROM=$(whiptail --title "Email From" --inputbox \
"Enter 'From' email address for outgoing emails:" 10 60 "$SMTP_USER" \
3>&1 1>&2 2>&3) || EMAIL_FROM="$SMTP_USER"
    fi
}

configure_firewall() {
    if whiptail --title "Firewall Configuration" --yesno \
"Do you want to configure UFW firewall rules for Odoo?" 10 60; then
        CONFIGURE_UFW="yes"
    fi
}

show_summary() {
    local summary="Installation Summary:

Installation Type: $INSTALL_TYPE
Odoo Version: $version

Ports:
  - HTTP: $OE_PORT
  - Longpolling: $OE_LONGPOLLING_PORT

Performance:
  - Workers: $OE_WORKERS
  - Log Level: $OE_LOG_LEVEL
  - Memory Soft: ${OE_LIMIT_MEMORY_SOFT}MB
  - Memory Hard: ${OE_LIMIT_MEMORY_HARD}MB

SMTP: $([ "$CONFIGURE_SMTP" = "yes" ] && echo "Configured ($SMTP_SERVER)" || echo "Not configured")
UFW Firewall: $([ "$CONFIGURE_UFW" = "yes" ] && echo "Will be configured" || echo "Skipped")

Press OK to start installation or Cancel to abort."

    whiptail --title "Confirm Installation" --yesno "$summary" 24 60 || exit 1
}

# =============================================================================
# Installation Functions
# =============================================================================

setup_directories() {
    OE_HOME_EXT="$OE_HOME/workspace/odoo${version}"
    CUSTOM="$OE_HOME/workspace/custom_addons/odoo${version}"
    OE_CONFIG_DIR="$OE_HOME/workspace/odoo${version}/config"
    OE_CONFIG_FILE="$OE_CONFIG_DIR/odoo${version}.conf"
    OE_LOG_DIR="$OE_HOME/workspace/odoo${version}/logs"
    OE_DATA_DIR="$OE_HOME/workspace/odoo${version}/data"

    sudo -u "$OE_USER" mkdir -p "$OE_HOME_EXT"
    sudo -u "$OE_USER" mkdir -p "$OE_CONFIG_DIR"
    sudo -u "$OE_USER" mkdir -p "$OE_LOG_DIR"
    sudo -u "$OE_USER" mkdir -p "$OE_DATA_DIR"
    sudo -u "$OE_USER" mkdir -p "$CUSTOM"
}

generate_odoo_config() {
    echo -e "\n---- Generating Odoo configuration file ----"
    
    local memory_soft=$((OE_LIMIT_MEMORY_SOFT * 1024 * 1024))
    local memory_hard=$((OE_LIMIT_MEMORY_HARD * 1024 * 1024))
    
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
limit_memory_soft = ${memory_soft}
limit_memory_hard = ${memory_hard}
limit_time_cpu = 600
limit_time_real = 1200
limit_time_real_cron = 3600
limit_request = 8192

; -----------------------------------------------------------------------------
; Email Configuration
; -----------------------------------------------------------------------------
EOF

    if [ "$CONFIGURE_SMTP" = "yes" ] && [ -n "$SMTP_SERVER" ]; then
        cat >> "$OE_CONFIG_FILE" << EOF
smtp_server = ${SMTP_SERVER}
smtp_port = ${SMTP_PORT}
smtp_ssl = ${SMTP_SSL}
smtp_user = ${SMTP_USER}
smtp_password = ${SMTP_PASSWORD}
email_from = ${EMAIL_FROM}
EOF
    else
        cat >> "$OE_CONFIG_FILE" << EOF
; smtp_server = smtp.example.com
; smtp_port = 587
; smtp_ssl = False
; smtp_user = your-email@example.com
; smtp_password = your-email-password
; email_from = odoo@example.com
EOF
    fi

    cat >> "$OE_CONFIG_FILE" << EOF

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

configure_ufw_firewall() {
    if [ "$CONFIGURE_UFW" = "yes" ]; then
        echo -e "\n---- Configuring UFW Firewall ----"
        
        # Install UFW if not present
        if ! command_exists ufw; then
            sudo apt-get install -y ufw
        fi
        
        # Allow SSH first to prevent lockout
        sudo ufw allow ssh
        
        # Allow Odoo ports
        sudo ufw allow "$OE_PORT"/tcp comment "Odoo HTTP"
        sudo ufw allow "$OE_LONGPOLLING_PORT"/tcp comment "Odoo Longpolling"
        
        # Allow PostgreSQL only from localhost (already default)
        # sudo ufw allow from 127.0.0.1 to any port 5432
        
        # Enable UFW if not already enabled
        if ! sudo ufw status | grep -q "Status: active"; then
            echo "y" | sudo ufw enable
        fi
        
        sudo ufw reload
        echo "UFW firewall configured successfully."
        sudo ufw status verbose
    fi
}

install_native() {
    echo -e "\n---- Starting Native Installation ----"
    
    # Update Server
    echo -e "\n---- Update Server ----"
    sudo apt install -y libpq-dev

    # Check if the version is less than 15 (requires older Python via pyenv)
    if [ "$version" -lt 15 ]; then
        echo "Version is less than 15. Proceeding with pyenv installation..."

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

        if command_exists pyenv; then
            echo "pyenv is already installed."
        else
            echo "Installing pyenv..."
            curl https://pyenv.run | bash
            update_shell_config ~/.bashrc

            if command_exists zsh; then
                update_shell_config ~/.zshrc
            fi

            current_shell=$(detect_shell)
            if [ "$current_shell" = "bash" ] && [ -f ~/.bashrc ]; then
                source ~/.bashrc
            elif [ "$current_shell" = "zsh" ] && [ -f ~/.zshrc ]; then
                source ~/.zshrc
            fi
        fi

        if command_exists pyenv; then
            pyenv --version
            if ! pyenv versions --bare | grep -q "^3\.6"; then
                pyenv install 3.6
            fi
            cd "$OE_HOME_EXT" || exit
            pyenv local 3.6
        else
            echo "Error: pyenv installation failed."
            exit 1
        fi
    else
        cd "$OE_HOME_EXT" || exit
    fi

    # Install PostgreSQL
    echo -e "\n---- Installing PostgreSQL ----"
    sudo apt-get install -y postgresql postgresql-server-dev-all
    sudo -u postgres createuser -s "$OE_USER" 2>/dev/null || true
    sudo -u postgres psql -c "ALTER ROLE \"$OE_USER\" WITH PASSWORD '$OE_PASSWORD';"

    # Install Dependencies
    echo -e "\n--- Installing Python 3 + pip3 --"
    sudo apt-get install -y python3 python3-pip
    sudo apt-get install -y git python3-cffi build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng-dev libjpeg-dev gdebi

    # Install Python requirements
    echo -e "\n---- Install python packages/requirements ----"
    REQUIREMENTS_URL="https://github.com/odoo/odoo/raw/$f_version/requirements.txt"

    if [ "$version" -lt 15 ]; then
        pip3 install -r "$REQUIREMENTS_URL" || { echo "Error: Failed to install Python packages."; exit 1; }
    else
        pip3 install -r "$REQUIREMENTS_URL" --break-system-packages || { echo "Error: Failed to install Python packages."; exit 1; }
    fi

    # Install Wkhtmltopdf
    echo -e "\n---- Installing wkhtmltopdf ----"
    detect_wkhtmltopdf_package() {
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$VERSION_CODENAME" in
                jammy|kinetic|lunar|mantic|noble) echo "odoo-wkhtmltopdf-ubuntu-jammy-x86_64-0.13.0-nightly.deb" ;;
                focal) echo "odoo-wkhtmltopdf-ubuntu-focal-x86_64-0.13.0-nightly.deb" ;;
                *) echo "odoo-wkhtmltopdf-ubuntu-jammy-x86_64-0.13.0-nightly.deb" ;;
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
    else
        echo "Warning: Failed to download wkhtmltopdf."
    fi

    # Clone Odoo
    echo -e "\n==== Installing ODOO Server ===="
    cd "$OE_HOME_EXT" || exit
    git clone --depth 1 --branch "$f_version" https://www.github.com/odoo/odoo || { echo "Error: Failed to clone Odoo."; exit 1; }

    # Generate config
    generate_odoo_config

    # Create helper scripts
    create_helper_scripts
    
    # Configure firewall
    configure_ufw_firewall
}

install_docker() {
    echo -e "\n---- Starting Docker Installation ----"
    
    # Install Docker if not present
    if ! command_exists docker; then
        echo "Installing Docker..."
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Add user to docker group
        sudo usermod -aG docker "$OE_USER"
    fi
    
    echo "Docker installed successfully."
    
    # Create docker-compose.yml
    echo -e "\n---- Creating Docker Compose configuration ----"
    
    local memory_soft=$((OE_LIMIT_MEMORY_SOFT * 1024 * 1024))
    local memory_hard=$((OE_LIMIT_MEMORY_HARD * 1024 * 1024))
    
    cat > "$OE_HOME_EXT/docker-compose.yml" << EOF
version: '3.8'

services:
  odoo:
    image: odoo:${version}
    container_name: odoo${version}
    depends_on:
      - db
    ports:
      - "${OE_PORT}:8069"
      - "${OE_LONGPOLLING_PORT}:8072"
    volumes:
      - odoo-web-data:/var/lib/odoo
      - ${CUSTOM}:/mnt/extra-addons
      - ${OE_CONFIG_DIR}:/etc/odoo
      - ${OE_LOG_DIR}:/var/log/odoo
    environment:
      - HOST=db
      - USER=${OE_USER}
      - PASSWORD=${OE_PASSWORD}
    command: ["--config=/etc/odoo/odoo${version}.conf"]
    restart: unless-stopped
    mem_limit: ${OE_LIMIT_MEMORY_HARD}m

  db:
    image: postgres:15
    container_name: postgres_odoo${version}
    environment:
      - POSTGRES_DB=postgres
      - POSTGRES_PASSWORD=${OE_PASSWORD}
      - POSTGRES_USER=${OE_USER}
      - PGDATA=/var/lib/postgresql/data/pgdata
    volumes:
      - odoo-db-data:/var/lib/postgresql/data/pgdata
    restart: unless-stopped

volumes:
  odoo-web-data:
  odoo-db-data:
EOF

    echo "Docker Compose file created: $OE_HOME_EXT/docker-compose.yml"
    
    # Generate config for Docker
    generate_docker_config
    
    # Create helper scripts for Docker
    create_docker_helper_scripts
    
    # Configure firewall
    configure_ufw_firewall
}

generate_docker_config() {
    echo -e "\n---- Generating Odoo configuration for Docker ----"
    
    local memory_soft=$((OE_LIMIT_MEMORY_SOFT * 1024 * 1024))
    local memory_hard=$((OE_LIMIT_MEMORY_HARD * 1024 * 1024))
    
    cat > "$OE_CONFIG_FILE" << EOF
[options]
; Odoo ${version} Docker Configuration
; Generated on: $(date)

admin_passwd = ${OE_SUPERADMIN}

; Database (Docker internal)
db_host = db
db_port = 5432
db_user = ${OE_USER}
db_password = ${OE_PASSWORD}
db_filter = ${OE_DB_FILTER}

; Paths
addons_path = /mnt/extra-addons
data_dir = /var/lib/odoo

; Server
http_port = 8069
longpolling_port = 8072
proxy_mode = True

; Logging
logfile = /var/log/odoo/odoo${version}.log
log_level = ${OE_LOG_LEVEL}

; Performance
workers = ${OE_WORKERS}
limit_memory_soft = ${memory_soft}
limit_memory_hard = ${memory_hard}

EOF

    if [ "$CONFIGURE_SMTP" = "yes" ] && [ -n "$SMTP_SERVER" ]; then
        cat >> "$OE_CONFIG_FILE" << EOF
; Email
smtp_server = ${SMTP_SERVER}
smtp_port = ${SMTP_PORT}
smtp_ssl = ${SMTP_SSL}
smtp_user = ${SMTP_USER}
smtp_password = ${SMTP_PASSWORD}
email_from = ${EMAIL_FROM}
EOF
    fi

    cat >> "$OE_CONFIG_FILE" << EOF

; Misc
list_db = True
without_demo = all
EOF

    chmod 640 "$OE_CONFIG_FILE"
}

create_helper_scripts() {
    echo -e "\n---- Creating helper scripts ----"

    cat > "$OE_HOME_EXT/start-odoo.sh" << EOF
#!/bin/bash
cd $OE_HOME_EXT/odoo
python3 odoo-bin -c $OE_CONFIG_FILE
EOF
    chmod +x "$OE_HOME_EXT/start-odoo.sh"

    cat > "$OE_HOME_EXT/stop-odoo.sh" << EOF
#!/bin/bash
pkill -f "odoo-bin -c $OE_CONFIG_FILE" || echo "Odoo is not running"
EOF
    chmod +x "$OE_HOME_EXT/stop-odoo.sh"

    cat > "$OE_HOME_EXT/restart-odoo.sh" << EOF
#!/bin/bash
$OE_HOME_EXT/stop-odoo.sh
sleep 2
$OE_HOME_EXT/start-odoo.sh
EOF
    chmod +x "$OE_HOME_EXT/restart-odoo.sh"

    cat > "$OE_HOME_EXT/logs-odoo.sh" << EOF
#!/bin/bash
tail -f $OE_LOG_DIR/odoo${version}.log
EOF
    chmod +x "$OE_HOME_EXT/logs-odoo.sh"
}

create_docker_helper_scripts() {
    echo -e "\n---- Creating Docker helper scripts ----"

    cat > "$OE_HOME_EXT/start-odoo.sh" << EOF
#!/bin/bash
cd $OE_HOME_EXT
docker compose up -d
echo "Odoo started. Access at http://localhost:$OE_PORT"
EOF
    chmod +x "$OE_HOME_EXT/start-odoo.sh"

    cat > "$OE_HOME_EXT/stop-odoo.sh" << EOF
#!/bin/bash
cd $OE_HOME_EXT
docker compose down
EOF
    chmod +x "$OE_HOME_EXT/stop-odoo.sh"

    cat > "$OE_HOME_EXT/restart-odoo.sh" << EOF
#!/bin/bash
cd $OE_HOME_EXT
docker compose restart
EOF
    chmod +x "$OE_HOME_EXT/restart-odoo.sh"

    cat > "$OE_HOME_EXT/logs-odoo.sh" << EOF
#!/bin/bash
cd $OE_HOME_EXT
docker compose logs -f odoo
EOF
    chmod +x "$OE_HOME_EXT/logs-odoo.sh"

    cat > "$OE_HOME_EXT/shell-odoo.sh" << EOF
#!/bin/bash
cd $OE_HOME_EXT
docker compose exec odoo bash
EOF
    chmod +x "$OE_HOME_EXT/shell-odoo.sh"
}

show_completion() {
    clear
    echo ""
    echo "=============================================="
    echo "  Odoo $version Installation Complete!"
    echo "=============================================="
    echo ""
    echo "Installation Type: $INSTALL_TYPE"
    echo ""
    echo "Paths:"
    echo "  - Install dir:   $OE_HOME_EXT"
    echo "  - Custom addons: $CUSTOM"
    echo "  - Config file:   $OE_CONFIG_FILE"
    echo "  - Log file:      $OE_LOG_DIR/odoo${version}.log"
    echo ""
    echo "Configuration:"
    echo "  - HTTP Port:     $OE_PORT"
    echo "  - Longpolling:   $OE_LONGPOLLING_PORT"
    echo "  - Workers:       $OE_WORKERS"
    echo "  - Log Level:     $OE_LOG_LEVEL"
    
    if [ "$CONFIGURE_SMTP" = "yes" ]; then
        echo "  - SMTP Server:   $SMTP_SERVER:$SMTP_PORT"
    fi
    
    if [ "$CONFIGURE_UFW" = "yes" ]; then
        echo "  - UFW Firewall:  Configured"
    fi
    echo ""
    echo "Commands:"
    echo "  Start:    $OE_HOME_EXT/start-odoo.sh"
    echo "  Stop:     $OE_HOME_EXT/stop-odoo.sh"
    echo "  Restart:  $OE_HOME_EXT/restart-odoo.sh"
    echo "  Logs:     $OE_HOME_EXT/logs-odoo.sh"
    
    if [ "$INSTALL_TYPE" = "docker" ]; then
        echo "  Shell:    $OE_HOME_EXT/shell-odoo.sh"
        echo ""
        echo "Note: Log out and back in for Docker group permissions."
    fi
    echo ""
    echo "Access Odoo at: http://localhost:$OE_PORT"
    echo ""
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    # Check and install whiptail
    check_whiptail
    
    # Show welcome and run interactive configuration
    show_welcome
    select_install_type
    select_version
    configure_basic_settings
    configure_performance
    configure_smtp
    configure_firewall
    show_summary
    
    # Setup directories
    setup_directories
    
    # Run installation based on type
    if [ "$INSTALL_TYPE" = "docker" ]; then
        install_docker
    else
        install_native
    fi
    
    # Show completion message
    show_completion
}

# Run main function
main "$@"
