# Odoo Installation Scripts

Automated installation scripts for Odoo ERP and ZSH shell setup on Ubuntu/Debian systems.

## Scripts

### 1. `odoo_install.sh` - Odoo ERP Installer

Automates the complete installation of Odoo ERP (versions 12-19) with full configuration.

#### Features

- Supports Odoo versions 12, 13, 14, 15, 16, 17, 18, and 19
- Automatic pyenv setup for older versions (< 15) requiring Python 3.6
- PostgreSQL installation and user configuration
- wkhtmltopdf installation with OS detection
- **Auto-generates `odoo.conf` configuration file**
- Creates helper scripts (start/stop)
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

#### Configuration Prompts

During installation, you'll be prompted for:

| Setting | Default | Description |
|---------|---------|-------------|
| PostgreSQL password | `admin` | Database user password |
| Odoo version | - | Version 12-19 |
| HTTP port | `8069` | Web interface port |
| Longpolling port | `8072` | Live chat/websocket port |
| Master password | `admin` | Odoo admin password |
| Workers | `0` | Number of workers (0=disabled) |
| DB filter | `.*` | Database filter regex |
| Log level | `info` | Logging verbosity |
| Memory limit (soft) | `1024` MB | Soft memory limit per worker |
| Memory limit (hard) | `2048` MB | Hard memory limit per worker |

#### Installation Locations

| Component | Path |
|-----------|------|
| Odoo source | `~/workspace/odoo{version}/odoo` |
| Custom addons | `~/workspace/custom_addons/odoo{version}` |
| Config file | `~/workspace/odoo{version}/config/odoo{version}.conf` |
| Log file | `~/workspace/odoo{version}/logs/odoo{version}.log` |
| Data directory | `~/workspace/odoo{version}/data` |

#### Generated Configuration File

The script generates a complete `odoo.conf` with:

```ini
[options]
; Admin & Security
admin_passwd = your_master_password

; Database Configuration
db_host = localhost
db_port = 5432
db_user = your_user
db_password = your_password

; Paths
addons_path = /path/to/odoo/addons,/path/to/custom_addons

; Server Configuration
http_port = 8069
longpolling_port = 8072

; Logging
logfile = /path/to/logs/odoo.log
log_level = info

; Performance & Workers
workers = 0
limit_memory_soft = 1073741824
limit_memory_hard = 2147483648
```

#### Starting Odoo

Using helper scripts:
```bash
# Start Odoo
~/workspace/odoo{version}/start-odoo.sh

# Stop Odoo
~/workspace/odoo{version}/stop-odoo.sh

# View logs
tail -f ~/workspace/odoo{version}/logs/odoo{version}.log
```

Or manually:
```bash
cd ~/workspace/odoo{version}/odoo
python3 odoo-bin -c ../config/odoo{version}.conf
```

Access Odoo at: `http://localhost:8069`

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

## Troubleshooting

### Common Issues

1. **Port already in use**: Change HTTP port during installation
2. **Memory errors**: Increase memory limits or reduce workers
3. **Database connection failed**: Verify PostgreSQL is running

### Logs

Check logs for errors:
```bash
tail -100 ~/workspace/odoo{version}/logs/odoo{version}.log
```

## License

MIT License
