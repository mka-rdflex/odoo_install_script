# Odoo Installation Scripts

Automated installation scripts for Odoo ERP and ZSH shell setup on Ubuntu/Debian systems.

## Scripts

### 1. `odoo_install.sh` - Odoo ERP Installer

Full-featured Odoo installer with interactive TUI menu.

#### Features

- **Interactive TUI Menu** - User-friendly whiptail-based interface
- **Native or Docker Installation** - Choose your preferred method
- **SMTP Email Configuration** - Optional email setup
- **UFW Firewall Configuration** - Automatic firewall rules
- Supports Odoo versions 12-19
- Auto-generates configuration files
- Creates helper scripts (start/stop/restart/logs)

#### Prerequisites

- Ubuntu/Debian based system
- sudo privileges
- Internet connection

#### Usage

```bash
chmod +x odoo_install.sh
./odoo_install.sh
```

#### Interactive Menu Options

| Screen | Options |
|--------|---------|
| Installation Type | Native / Docker |
| Odoo Version | 12, 13, 14, 15, 16, 17, 18, 19 |
| Basic Settings | PostgreSQL password, ports, master password |
| Performance | Workers, log level, memory limits |
| Email (Optional) | SMTP server, port, credentials |
| Firewall (Optional) | UFW configuration |

#### Installation Types

##### Native Installation
- Installs directly on the system
- PostgreSQL installed locally
- Python dependencies via pip
- Best for development/single server

##### Docker Installation
- Uses official Odoo Docker images
- PostgreSQL in separate container
- Easy to manage and update
- Best for production/isolation

#### Generated Files

```
~/workspace/odoo{version}/
├── odoo/                    # Odoo source (native only)
├── docker-compose.yml       # Docker config (docker only)
├── config/
│   └── odoo{version}.conf   # Configuration file
├── logs/
│   └── odoo{version}.log    # Log file
├── data/                    # Filestore/sessions
├── start-odoo.sh            # Start script
├── stop-odoo.sh             # Stop script
├── restart-odoo.sh          # Restart script
├── logs-odoo.sh             # View logs script
└── shell-odoo.sh            # Docker shell (docker only)
```

#### SMTP Configuration

When enabled, configures:
- SMTP Server (e.g., smtp.gmail.com)
- SMTP Port (587/465/25)
- SSL/TLS settings
- Authentication credentials
- From email address

#### UFW Firewall Rules

When enabled, automatically:
- Allows SSH (prevents lockout)
- Opens Odoo HTTP port
- Opens Longpolling port
- Enables UFW if not active

#### Commands

```bash
# Start Odoo
~/workspace/odoo{version}/start-odoo.sh

# Stop Odoo
~/workspace/odoo{version}/stop-odoo.sh

# Restart Odoo
~/workspace/odoo{version}/restart-odoo.sh

# View logs
~/workspace/odoo{version}/logs-odoo.sh

# Docker shell (docker only)
~/workspace/odoo{version}/shell-odoo.sh
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
| whiptail | Interactive menus (auto-installed) |
| docker | Docker installation (auto-installed) |

## Tested On

- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)

## Troubleshooting

### Common Issues

1. **Port already in use**: Change HTTP port during installation
2. **Memory errors**: Increase memory limits or reduce workers
3. **Docker permission denied**: Log out and back in after install
4. **UFW blocks connection**: Check `sudo ufw status`

### View Logs

```bash
# Native
tail -100 ~/workspace/odoo{version}/logs/odoo{version}.log

# Docker
docker compose logs -f odoo
```

## License

MIT License
