#!/bin/bash

OE_USER=$(whoami)
OE_HOME="home/$OE_USER"
OE_PASSWORD="admin"

read -p "Enter version (integer between 12 and 18) : " version

if [[ ! $version =~ ^[0-9]+$ || $version -lt 12 || $version -gt 18 ]]; then
    echo "Enter a valid version (integer between 12 and 18)"
else
    echo "Version is odoo${version}"
fi

f_version=$(echo "$version.0" | bc)

OE_HOME_EXT="/$OE_HOME/workspace/odoo${version}"
CUSTOM="/$OE_HOME/workspace/custom_addons/odoo${version}"
sudo su $OE_USER -c "mkdir -p $OE_HOME_EXT"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"

sudo apt install libpq-dev

# Check if the float value is less than 15
if (($(echo "$version < 15" | bc -l))); then
    echo "Float value is less than 15. Proceeding with pyenv installation..."

    echo "Updating and upgrading system packages..."

    # Install dependencies
    echo "Installing required dependencies..."
    sudo apt install -y make build-essential libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
        libncurses5-dev libncursesw5-dev xz-utils tk-dev \
        libffi-dev liblzma-dev python3-openssl git

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

        # Reload shell configuration
        echo "Reloading shell configuration..."
        if [ "$0" == "bash" ]; then
            source ~/.bashrc
        fi

        if [ "$0" == "zsh" ]; then
            source ~/.zshrc
        fi
    fi
    # Check and update ~/.bashrc

    # Verify installation
    if command_exists pyenv; then
        echo "pyenv installation completed successfully!"
        pyenv --version
        if ! pyenv versions --bare | grep -q "^3.6"; then
            echo "Installing Python 3.6..."
            pyenv install 3.6
        else
            echo "Python 3.6 is already installed."
        fi
        if [ -d "$OE_HOME_EXT" ]; then
            cd "$OE_HOME_EXT" || exit # Navigate to the target directory
            echo "Switched to directory: $OE_HOME_EXT"
            pyenv local 3.6
            if [ "$(pyenv version-name)" != "3.6.15" ]; then
                echo "pyenv local version not set correctly."
                exit 1
            fi
        else
            echo "Directory $OE_HOME_EXT does not exist."
            exit 1
        fi
    else
        echo "pyenv installation failed. Please check for errors."
    fi
else
    if [ -d "$OE_HOME_EXT" ]; then
        cd "$OE_HOME_EXT" || exit # Navigate to the target directory
        echo "Switched to directory: $OE_HOME_EXT"
    else
        echo "Directory $OE_HOME_EXT does not exist."
        exit 1
    fi
fi


#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------

echo -e "\n---- Installing the default postgreSQL version based on Linux version ----"
sudo apt-get install postgresql postgresql-server-dev-all -y

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2>/dev/null || true
sudo su - postgres -c "psql -c \"ALTER ROLE \\\"$OE_USER\\\" WITH PASSWORD '$OE_PASSWORD';\""

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 --"
sudo apt-get install python3 python3-pip
sudo apt-get install git python3-cffi build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng-dev libjpeg-dev gdebi -y

echo -e "\n---- Install python packages/requirements ----"
if (($(echo "$version < 15" | bc -l))); then
    pip3 install -r https://github.com/odoo/odoo/raw/$f_version/requirements.txt
else
    pip3 install -r https://github.com/odoo/odoo/raw/$f_version/requirements.txt --break-system-packages
fi
if [ $? -ne 0 ]; then
    echo "Error: Failed to install the required Python packages."
    exit 1
else
    echo "Python packages installed successfully."
fi


#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------

wget https://github.com/odoo/wkhtmltopdf/releases/download/nightly/odoo-wkhtmltopdf-ubuntu-jammy-x86_64-0.13.0-nightly.deb 
sudo dpkg -i odoo-wkhtmltopdf-ubuntu-jammy-x86_64-0.13.0-nightly.deb
rm -rf odoo-wkhtmltopdf-ubuntu-jammy-x86_64-0.13.0-nightly.deb

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
git clone --depth 1 --branch $f_version https://www.github.com/odoo/odoo

echo -e "\n---- Create custom module directory ----"
sudo su $OE_USER -c "mkdir -p $CUSTOM"
