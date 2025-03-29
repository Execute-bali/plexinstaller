Collecting workspace information# PlexDev Installer

An unofficial installer utility for PlexDevelopment products that simplifies the setup process on Linux servers.

## Overview

This project provides an automated installation solution for various PlexDevelopment products, handling the complete setup process including:

- Linux distribution detection
- Dependency installation
- Nginx configuration
- SSL certificate setup
- Systemd service creation
- Firewall configuration

## Supported Products

The installer supports the following PlexDevelopment products:

- PlexTickets (with optional dashboard)
- PlexStaff
- PlexStatus
- PlexStore
- PlexForms

## Features

- ✅ Automatic system detection
- ✅ Dependency management
- ✅ Domain DNS validation
- ✅ Nginx configuration with SSL
- ✅ Systemd service setup
- ✅ Firewall port configuration
- ✅ Interactive installation process
- ✅ Error handling and validation

## Installation

### Quick Install

```bash
curl -sSL https://plexdev.live/install.sh | bash
```

### Manual Install

```bash
# Download the script
curl -sSL -o install.sh https://plexdev.live/install.sh

# Make it executable
chmod +x install.sh

# Run the installer
./install.sh
```

## Web Interface

The project includes a web interface (plexdev.live.js) that provides an easy way to access the installation script.

To start the web server:

```bash
node plexdev.live.js
```

## Requirements

- Linux server (Ubuntu, Debian, CentOS, RHEL, Fedora, Arch, or openSUSE)
- Root/sudo access
- Node.js 20+
- Internet connection
- Domain name (for SSL setup)

## Disclaimer

This is an **unofficial** installer and is not affiliated with or endorsed by PlexDevelopment. The official PlexDevelopment website is [plexdevelopment.net](https://plexdevelopment.net).

## License

This project is provided as-is without any warranty. Use at your own risk.

## Author

Created by bali0531
