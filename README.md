# Odoo Installation Scripts

Automated installation scripts for Odoo ERP and ZSH shell setup on Ubuntu/Debian systems.

## Scripts

### 1. `odoo_install.sh` - Odoo ERP Installer

Automates the complete installation of Odoo ERP (versions 12-19).

#### Features

- Supports Odoo versions 12, 13, 14, 15, 16, 17, 18, and 19
- Automatic pyenv setup for older versions (< 15) requiring Python 3.6
- PostgreSQL installation and user configuration
- wkhtmltopdf installation with OS detection
- Custom addons directory creation

#### Prerequisites

- Ubuntu/Debian based system
- sudo privileges
- Internet connection

#### Usage

```bash
chmod +x odoo_install.sh
./odoo_install.sh
```

You will be prompted for:
1. PostgreSQL password (default: `admin`)
2. Odoo version (12-19)

#### Installation Locations

| Component | Path |
|-----------|------|
| Odoo source | `~/workspace/odoo{version}/odoo` |
| Custom addons | `~/workspace/custom_addons/odoo{version}` |

#### Starting Odoo

```bash
cd ~/workspace/odoo{version}/odoo
python3 odoo-bin
```

---

### 2. `zsh_install.sh` - ZSH + Powerlevel10k Installer

Installs a complete ZSH environment with Oh-My-Zsh, Powerlevel10k theme, and plugins.

#### Features

- Oh-My-Zsh framework
- Powerlevel10k theme
- zsh-autosuggestions plugin
- MesloLGS NF fonts

#### Usage

```bash
chmod +x zsh_install.sh
./zsh_install.sh
```

#### Post-Installation

1. Set terminal font to `MesloLGS NF`
2. Run `exec zsh` or restart terminal
3. Run `p10k configure` to customize prompt

---

## Requirements

| Package | Purpose |
|---------|---------|
| git | Repository cloning |
| curl | Downloading files |
| wget | Downloading packages |
| sudo | Administrative tasks |

## Tested On

- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)

## License

MIT License
