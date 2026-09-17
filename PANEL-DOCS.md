<div align="center">

```
  ██╗  ██╗ █████╗ ██████╗ ██████╗ ██╗   ██╗      ███╗   ██╗ ██████╗ ██████╗ ███████╗
  ██║  ██║██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝      ████╗  ██║██╔═══██╗██╔══██╗██╔════╝
  ███████║███████║██████╔╝██████╔╝ ╚████╔╝ █████╗██╔██╗ ██║██║   ██║██║  ██║█████╗
  ██╔══██║██╔══██║██╔═══╝ ██╔═══╝   ╚██╔╝  ╚════╝██║╚██╗██║██║   ██║██║  ██║██╔══╝
  ██║  ██║██║  ██║██║     ██║        ██║         ██║ ╚████║╚██████╔╝██████╔╝███████╗
  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝        ╚═╝         ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝
```

# ⚡ HAPPY-NODE — Universal VPS Control Panel

### Complete Documentation & Technical Reference

[![bash](https://img.shields.io/badge/Run-Bash-orange?style=for-the-badge&logo=gnubash&logoColor=white)](https://happyff.indevs.in/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-blue?style=for-the-badge&logo=linux&logoColor=white)]()
[![Version](https://img.shields.io/badge/Version-1.0-purple?style=for-the-badge)]()

</div>

---

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Main Menu — Dashboard](#main-menu--dashboard)
- [Module 1: VPS Setup](#module-1-vps-setup)
- [Module 2: Panel Installer](#module-2-panel-installer)
- [Module 3: Wings Manager](#module-3-wings-manager)
- [Module 4: Toolbox](#module-4-toolbox)
- [Module 5: Themes & UI](#module-5-themes--ui)
- [Module 6: System Manager](#module-6-system-manager)
- [Module 7: Container (Docker)](#module-7-container-docker)
- [Module 8: Extras](#module-8-extras)
- [Theme System — Full Breakdown](#theme-system--full-breakdown)
- [Project Structure](#project-structure)
- [Security Features](#security-features)
- [Requirements](#requirements)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

**HAPPY-NODE** is a complete, modular, one-command VPS control panel designed for game server administrators. It provides a beautiful terminal UI to deploy, manage, and customize Pterodactyl-based panels, wings daemons, Docker containers, VPN tunnels, and more — all from a single bash script.

### Key Highlights

| Feature | Detail |
|---------|--------|
| **Launch Command** | `bash <(curl -fsSL https://happyff.indevs.in/)` |
| **Total Files** | 173 files |
| **Total Size** | ~179 MB |
| **Shell Scripts** | 47 `.sh` files |
| **Blueprint Themes** | 29 UI themes + 66 extensions |
| **ZIP Themes** | 11 custom themes |
| **ARIX Versions** | 4 versions (v2.1.0, v2.0.8, v1.3.1, AV1) |
| **Panel Support** | 6 different panels |
| **Supported OS** | Debian, Ubuntu, Alpine, RHEL, CentOS, Fedora |
| **License** | MIT (Free to use & modify) |

---

## Quick Start

```bash
bash <(curl -fsSL https://happyff.indevs.in/)
```

**What happens:**
1. Downloads the main `menu.sh` from GitHub via Cloudflare Worker
2. Loads shared library (`lib/common.sh`) for colors, helpers, platform detection
3. Detects your OS, architecture, and package manager
4. Shows live system metrics (CPU, RAM, Disk, Uptime)
5. Displays the main dashboard menu
6. Each option downloads and runs the relevant script on-demand

---

## Main Menu — Dashboard

The main menu (`menu.sh`) is the entry point. It shows:

```
  ┌─ Uptime: 2 days  |  Disk: 45%  |  CPU: 12%  RAM: 38%  ─┐

  ██╗  ██╗ █████╗ ██████╗ ██████╗ ██╗   ██╗      ...
                         HAPPY-NODE

────────────────────────────────────────────────────────────────────────────

 ◆ DEPLOYMENT & SERVICES
   [1] VPS Setup          [5] Themes
   [2] Panel              [6] System
   [3] Wings              [7] Container
   [4] Toolbox            [8] Extras

 ◆ MAINTENANCE & TOOLS
   [0] Exit

────────────────────────────────────────────────────────────────────────────
 ➜ Enter Option (0-8):
```

### Menu Options

| Key | Module | Script | Description |
|-----|--------|--------|-------------|
| `1` | VPS Setup | `setup vm/menu.sh` | VM management, KVM runners, RDX tool |
| `2` | Panel | `panel/1.sh` | Install game server panels |
| `3` | Wings | `wings/run.sh` | Wings daemon management |
| `4` | Toolbox | `toolbox/run.sh` | Network tools, VPN, terminal |
| `5` | Themes | `thame/run.sh` | UI themes, Blueprint, ARIX |
| `6` | System | `lib/sysmgr.sh` | System updates, info, reboot |
| `7` | Container | `Extras/docker.sh` | Docker container deployment |
| `8` | Extras | `Extras/run.sh` | Docker, LXC/LXD |
| `0` | Exit | — | Disconnect safely |

### How Scripts Are Loaded

Every module uses a **remote execution** model:
1. Script is downloaded to `/tmp/hn_XXXXXX.sh` (temp file)
2. HTTP status code is checked (must be `200`)
3. Script is executed with `bash`
4. Temp file is deleted after execution

This means **no local installation required** — everything runs from GitHub.

---

## Module 1: VPS Setup

**Path:** `setup vm/menu.sh`

```
╔══════════════════════════════════════════════════════╗
║                  HAPPY-NODE                        ║
║               VPS CONTROL PANEL                    ║
╠══════════════════════════════════════════════════════╣
║   VM MANAGEMENT                                    ║
║                                                      ║
║   [1]  RDX Tool                                    ║
║   [2]  Run VM       • KVM                         ║
║   [3]  Run VM       • No KVM                      ║
║   [4]  Run VM       • All Setup                   ║
║                                                      ║
║   [5]  Exit                                        ║
╚══════════════════════════════════════════════════════╝
```

### Sub-Modules

| Option | Script | Description |
|--------|--------|-------------|
| **RDX Tool** | `vm/menu.sh` | Creates `.idx/dev.nix` config for Nix-based VM environments with QEMU/KVM support |
| **Run VM (KVM)** | `vm/vm-1.sh` | KVM-based virtual machine setup with hardware virtualization |
| **Run VM (No KVM)** | `vm/vm-2.sh` | Software-emulated VM for VPS without KVM support |
| **Run VM (All Setup)** | `vm/vm-3.sh` | Complete VM setup with all dependencies auto-installed |

### VM Scripts Features
- Auto-install QEMU dependencies (`qemu-kvm`, `qemu-utils`, `cloud-image-utils`)
- Support for multiple architectures (amd64, arm64)
- Cloud-init support for automated VM provisioning
- Network bridge configuration

---

## Module 2: Panel Installer

**Path:** `panel/1.sh`

```
  HAPPY-NODE                                              v15.0
  SYSTEM  ● ONLINE     UPTIME 2 days     LOAD  0.5
  ─────────────────────────────────────────────────────────

  AVAILABLE MODULES

  [01] Pterodactyl        [07] Convoy
  [02] Jexactyl           [08] FeatherPanel
  [03] JexPanel           [09] MythicalDash
  [04] Reviactyl          [10] MythicalDash v3
  [05] CtrlPanel          [11] VPS Panel
  [06] Paymenter          [00] Exit
```

### Supported Panels

| # | Panel | Status | Script | Description |
|---|-------|--------|--------|-------------|
| 1 | **Pterodactyl** | ✅ Ready | `panel/pterodactyl/` | Most popular game server panel. Includes panel installer, wings setup, SSL, phpMyAdmin |
| 2 | **Jexactyl** | ✅ Ready | `panel/Jexactyl/install.sh` | Pterodactyl fork with enhanced features |
| 3 | **JexPanel** | 🔜 Coming Soon | — | — |
| 4 | **Reviactyl** | ✅ Ready | `panel/reviactyl/` | Pterodactyl fork with premium features |
| 5 | **CtrlPanel** | 🔜 Coming Soon | — | — |
| 6 | **Paymenter** | ✅ Ready | `panel/paymenter/` | Billing/payment panel for hosting businesses |
| 7 | **Convoy** | ✅ Ready | `panel/Convoy/install.sh` | Game server management panel |
| 8 | **FeatherPanel** | 🔜 Coming Soon | — | — |
| 9 | **MythicalDash** | ✅ Ready | `panel/mythical/` | Dashboard for Pterodactyl |
| 10 | **MythicalDash v3** | ✅ Ready | `panel/mythical/` | Latest version of MythicalDash |
| 11 | **VPS Panel** | 🔜 Coming Soon | — | — |

### Pterodactyl Installer Features
- **Auto-generated database password** (24-char random, `openssl rand -base64`)
- **Auto SMTP configuration** (`MAIL_MAILER=log` — no email server needed)
- **SSL certificate** setup with Let's Encrypt
- **phpMyAdmin** optional installation
- **Wings** daemon auto-configuration
- Supports MySQL/MariaDB

### All Panel Installers Share
- Automatic dependency installation
- Database creation and user setup
- `.env` file configuration
- Queue worker setup (systemd)
- Cron job configuration
- Permission fixing (`www-data:www-data`)

---

## Module 3: Wings Manager

**Path:** `wings/run.sh`

```
 ╔════════════════════════════════════════════════════════════╗
 ║   ⚡ HAPPY-NODE WINGS MANAGER v3.5 :: SERVER AUTOMATION   ║
 ╠════════════════════════════════════════════════════════════╣
 ║  OS   : Ubuntu 22.04           WAN: 1.2.3.4              ║
 ║  RAM  : 2.1G/4.0G              LAN: 192.168.1.1          ║
 ╚════════════════════════════════════════════════════════════╝

  AVAILABLE MODULES
  ──────────────────────────────────────────────────────────
  [1] SSL Configuration    :: (Certbot/Nginx)
  [2] Install Wings        :: (HAPPY-NODE)
  [3] Manager              :: (Wings Manager)
  [4] Database Manager     :: (MySQL/MariaDB)
  [5] Uninstall            :: (Remove Wings)
  ──────────────────────────────────────────────────────────
  [0] Exit System

  root@happy-node:~#
```

### Wings Sub-Modules

| Option | Script | Description |
|--------|--------|-------------|
| **SSL Configuration** | Built-in | Certbot + Nginx SSL certificate setup. Auto-detects domain, requests certificate, configures Nginx |
| **Install Wings** | `wings/install.sh` | Downloads and installs Pterodactyl Wings daemon. Auto-configures with panel token |
| **Manager** | `wings/mang.sh` | Start/Stop/Restart Wings, view logs, update Wings |
| **Database Manager** | `wings/db.sh` | MySQL/MariaDB database creation, user management, grants |
| **Uninstall** | Built-in | Complete removal: stops Wings service, removes configs, prunes Docker, optional DB cleanup |

### Wings Manager Features
- **Auto-detect system**: OS, Public IP, Local IP, RAM usage
- **Service management**: `systemctl` based Wings control
- **Log viewer**: Real-time Wings daemon logs
- **Update checker**: Compares installed vs latest version

---

## Module 4: Toolbox

**Path:** `toolbox/run.sh`

```
╔════════════════════════════════════════════════════════════╗
║   ⚡ HAPPY-NODE TOOLBOX ⚡                                ║
╠════════════════════════════════════════════════════════════╣
║ User: root     Host: my-vps                               ║
║ RAM: 2.1G/4G   CPU:  0.50                                ║
║ IP: 1.2.3.4                                            ║
╚════════════════════════════════════════════════════════════╝

  [ ACCESS & NETWORK ]
  1) Root Access         :: Enable Root/Sudo
  2) Tailscale           :: Mesh VPN Setup
  3) Zerotier            :: Wifi VPN Setup
  4) Cloudflare DNS      :: Tunnel & DNS

  [ SYSTEM OPERATIONS ]
  5) System Info         :: Specs & Status
  6) Port Forward        :: TCP/UDP

  [ GUI & TERMINAL ]
  7) Web Terminal        :: Browser Shell
  8) SSL Panel           :: SSL Setup

════════════════════════════════════════════════════════════
  0) ↩ Back / Exit
```

### Toolbox Tools

| # | Tool | Script | Description |
|---|------|--------|-------------|
| 1 | **Root Access** | `toolbox/root.sh` | Enables root login, sudo access, password-based SSH |
| 2 | **Tailscale** | `toolbox/tailscale.sh` | Installs Tailscale mesh VPN. Creates private network between VPS devices |
| 3 | **ZeroTier** | `toolbox/zerotier.sh` | Installs ZeroTier VPN. Virtual LAN across the internet |
| 4 | **Cloudflare DNS** | `toolbox/cloudflare.sh` | Cloudflare Tunnel setup for exposing local services. DNS management |
| 5 | **System Info** | `toolbox/info.sh` | Detailed system information: CPU, RAM, Disk, Network, Processes |
| 6 | **Port Forward** | `toolbox/localtonet.sh` | LocalToNet port forwarding. Expose local ports to the internet via TCP/UDP tunnels |
| 7 | **Web Terminal** | `toolbox/terminal.sh` | Installs browser-based terminal (ttyd/gotty). Access shell from web browser |
| 8 | **SSL Panel** | — | SSL certificate management for panel (Coming Soon) |

---

## Module 5: Themes & UI

**Path:** `thame/run.sh`

```
╔════════════════════════════════════╗
║     HAPPY-NODE UI MANAGER         ║
╚════════════════════════════════════╝

   [1] Blueprint         : ● ONLINE/OFFLINE
   [2] Theme             : ● INSTALLED/NOT INSTALLED
   [3] Extensions        : ● INSTALLED/NOT INSTALLED
   [4] Hyper V1          : ● INSTALLED/NOT INSTALLED
   [5] ARIX Theme        : ● INSTALLED/NOT INSTALLED

   [0] Exit
```

### Theme Manager Sub-Modules

| # | Module | Description |
|---|--------|-------------|
| 1 | **Blueprint** | Blueprint Framework — required for most themes. Install/Reinstall/Update/Info/Version/Uninstall |
| 2 | **Theme** | Main theme installer — launches `thames.sh` with 44 themes |
| 3 | **Extensions** | Blueprint extensions — 66 add-ons for Pterodactyl |
| 4 | **Hyper V1** | Hyper theme by rolexdev — premium UI for Pterodactyl |
| 5 | **ARIX Theme** | ARIX theme — 4 versions with auto-error fixing |

---

## Theme System — Full Breakdown

### The Theme Manager (`thames.sh`)

**The most comprehensive theme installer for Pterodactyl.**

```
 ╔══════════════════════════════════════════════════════════╗
 ║  HAPPY-NODE THEME MANAGER v2.0                          ║
 ║  Blueprint + ZIP + Arix - All Themes                    ║
 ╚══════════════════════════════════════════════════════════╝

 ALL THEMES:

  1 Nebula              [BP]      NOT INSTALLED
  2 Euphoria            [BP]      NOT INSTALLED
  3 BetterAdmin         [BP]      NOT INSTALLED
  ...
 30 Billing             [ZIP]     NOT INSTALLED
 31 Stellar             [ZIP]     NOT INSTALLED
 ...
 41 Arix v2.1.0         [ARIX]    NOT INSTALLED
 42 Arix v2.0.8         [ARIX]    NOT INSTALLED
 43 Arix v1.3.1         [ARIX]    NOT INSTALLED
 44 Arix AV1            [ARIX]    NOT INSTALLED
```

### Theme Types

| Type | Label | Count | Install Method |
|------|-------|-------|----------------|
| **Blueprint** | `[BP]` | 29 | Download `.blueprint` file → `blueprint -i` |
| **ZIP Theme** | `[ZIP]` | 11 | Download ZIP → Extract → Copy files → Build |
| **ARIX** | `[ARIX]` | 4 | Download ZIP → Security scan → Copy → Build → Error fix |

---

### Blueprint Themes (29)

Installed via the Blueprint Framework. Each theme is a single `.blueprint` file.

| # | Theme | File | Description |
|---|-------|------|-------------|
| 1 | Nebula | `nebula.blueprint` | Clean dark theme with neon accents |
| 2 | Euphoria | `euphoriatheme.blueprint` | Vibrant purple gradient theme |
| 3 | BetterAdmin | `BetterAdmin.blueprint` | Enhanced admin panel UI |
| 4 | Abyss Purple | `abysspurple.blueprint` | Deep purple abyss theme |
| 5 | Abyss Amber | `amberabyss.blueprint` | Amber-gold dark theme |
| 6 | Catppuccindactyl | `catppuccindactyl.blueprint` | Catppuccin Mocha color scheme |
| 7 | Abyss Crimson | `crimsonabyss.blueprint` | Red crimson dark theme |
| 8 | Abyss Emerald | `emeraldabyss.blueprint` | Green emerald dark theme |
| 9 | NightAdmin | `nightadmin.blueprint` | Night mode admin panel |
| 10 | Refresh | `refreshtheme.blueprint` | Modern refresh design |
| 11 | Slice | `slice.blueprint` | Minimalist slice design |
| 12 | Darkenate | `darkenate.blueprint` | Ultra-dark theme |
| 13 | Recolor | `recolor.blueprint` | Customizable color scheme |
| 14 | BlueTables | `bluetables.blueprint` | Blue-tinted table design |
| 15 | UltraDarkAdmin | `ultradarkadmin.blueprint` | Maximum darkness theme |
| 16 | Xlpanel | `xlpaneltheme.blueprint` | Extended panel layout |
| 17 | Lemem | `lememtheme.blueprint` | Meme-inspired design |
| 18 | Slate | `slate.blueprint` | Slate grey professional theme |
| 19 | KaelixPrime | `kaelixprime.blueprint` | Premium Kaelix design |
| 20 | M3dactyl | `m3dactyl.blueprint` | Material Design 3 inspired |
| 21 | Catppuccin V1 | `catppuccindactyl1.blueprint` | Catppuccin classic |
| 22 | Catppuccin V2 | `catppuccindactyl2.blueprint` | Catppuccin updated |
| 23 | Lu Theme | `lutheme.blueprint` | Lu custom theme |
| 24 | Navy Seals Slice | `Navy.seals.slice.blueprint` | Navy blue slice design |
| 25 | Navy Seals | `navyseals.blueprint` | Navy blue full theme |
| 26 | Nebula V1.8 | `nebula1.8.blueprint` | Nebula legacy version |
| 27 | Nebula V2.0 | `nebula2.0.blueprint` | Nebula latest version |
| 28 | Tailwind Palette | `tailwindfourpalette.blueprint` | Tailwind CSS color palette |
| 29 | Xlpanel V2.0 | `xlpaneltheme2.0.blueprint` | XL Panel updated |

---

### ZIP Themes (11)

Custom themes packaged as ZIP files. Each contains `resources/`, `public/`, and sometimes `app/`, `routes/`, `config/` directories.

| # | Theme | File | Size | Description |
|---|-------|------|------|-------------|
| 30 | Billing | `billing.zip` | 6.29 MB | Complete billing/payment theme |
| 31 | Stellar | `stellar.zip` | 0.23 MB | Space-inspired dark theme |
| 32 | Unix | `unix.zip` | 0.08 MB | Terminal/Unix aesthetic theme |
| 33 | Carbon Theme | `Carbon Theme.zip` | 0.10 MB | Carbon fiber dark theme |
| 34 | Elysium | `elysium.zip` | 0.17 MB | Elegant dark theme |
| 35 | Enigma | `enigma.zip` | 1.81 MB | Mystery-themed dark UI |
| 36 | Nightcore | `nightcore.zip` | <0.01 MB | Minimal nightcore aesthetic |
| 37 | IceMinecraft | `iceMinecraft.zip` | 0.01 MB | Minecraft ice-themed |
| 38 | Nookure | `nookure.zip` | 0.02 MB | Nookure clean design |
| 39 | NoraTheme | `NoraTheme.zip` | 22.84 MB | Full-featured Nora theme |
| 40 | Astro Theme | `astro theme.zip` | 0.48 MB | Astronomy-inspired theme |

**ZIP Theme Install Process:**
1. Download ZIP from HAPPY-NODE repo
2. Verify ZIP integrity (PK signature check)
3. Extract to temp directory
4. Auto-detect inner structure (`pterodactyl/` folder or direct `resources/`, `public/`)
5. Copy `resources/`, `public/`, `app/`, `routes/`, `config/`, `database/` to panel
6. Run `yarn install` + `yarn build:production`
7. Clear all caches
8. Create marker file for status detection

---

### ARIX Versions (4)

ARIX is a premium Pterodactyl theme with multiple versions. All stored locally in the repo.

| # | Version | Folder | Size | Description |
|---|---------|--------|------|-------------|
| 41 | Arix v2.1.0 (Latest) | `v210/` | 8.63 MB | Latest with most features |
| 42 | Arix v2.0.8 | `v208/` | 10.10 MB | Legacy stable version |
| 43 | Arix v1.3.1 | `v131/` | 9.11 MB | Classic lightweight version |
| 44 | Arix AV1 | `av1/` | 10.10 MB | Alternative build |

**ARIX Install Process (v3.0):**
1. **Dependencies** — Auto-install `unzip`, `curl`, `wget`
2. **Download** — From HAPPY-NODE repo (fallback to GitHub if needed)
3. **Verify** — ZIP integrity check
4. **Extract** — Unzip to temp directory
5. **Security Scan** — Remove backdoor files (`Arix.php`, `ins.php`, `up.php`)
6. **Copy Files** — `resources/`, `public/`, `app/`, `routes/`, `config/`, `database/`, `arix/`, `bootstrap/`
7. **Node.js** — Auto-install Node.js 22 if needed
8. **Build** — `yarn install` + `yarn build:production`
9. **Error Fix** — Migrations, storage link, cache rebuild, permissions
10. **Verify** — Confirm installation

**ARIX Security Features:**
- Scans for and removes known backdoor files
- Backup created before installation (with rollback support)
- No license server required
- All files stored in HAPPY-NODE repo (no external dependencies)

---

### Blueprint Extensions (66)

Blueprint Framework extensions for Pterodactyl. Each is a `.blueprint` file.

| # | Extension | Description |
|---|-----------|-------------|
| 1 | Activity Purges | Purge user activity logs |
| 2 | Admin Audit Logs | Track admin actions |
| 3 | Auto Backups | Automatic server backups |
| 4 | Blue Announcements | Server announcement system |
| 5 | Config Editor | Edit server configs in-browser |
| 6 | Console Logs | Enhanced console log viewer |
| 7 | Custom CSS | Apply custom CSS to panel |
| 8 | Custom Server Sort | Custom server sorting |
| 9 | Database Import/Export | MySQL database tools |
| 10 | Egg Changer | Change server eggs |
| 11 | Hux Register | Custom registration page |
| 12 | Laravel Logs | View Laravel error logs |
| 13 | Loader | Custom loading animations |
| 14 | Lyrdy Announce | Announcement system |
| 15 | MC Logs | Minecraft server log parser |
| 16 | MCP | Minecraft protocol tools |
| 17 | MC Player | Minecraft player manager |
| 18 | MC Plugins | Minecraft plugin manager |
| 19 | MC Tools | Minecraft server tools |
| 20 | Minecraft Mod Manager | Manage Minecraft mods |
| 21 | Minecraft Player Manager | Player data management |
| 22 | Minecraft Plugin Manager | Plugin install/update |
| 23 | Modrinth Browser | Browse Modrinth mods |
| 24 | Monaco Editor | Code editor in browser |
| 25 | MOTD Maker | Create server MOTDs |
| 26 | MySQL Auto Backup | Automated MySQL backups |
| 27 | Node | Node management |
| 28 | No Pagination | Remove pagination limits |
| 29 | Panel Address Override | Custom panel URL |
| 30 | Player Listing | List server players |
| 31 | PStatistics | Server statistics |
| 32 | Pterodactyl CPU Burst | CPU burst control |
| 33 | Pterodactyl Panel Ban | Ban users from panel |
| 34 | Pterodactyl RAM Burst | RAM burst control |
| 35 | Pteromonaco | Monaco editor variant |
| 36 | Pull Files | Pull files from URLs |
| 37 | Redirect | Custom redirects |
| 38 | Resource Alerts | Resource usage alerts |
| 39 | Resource Manager | Server resource management |
| 40 | Saga Auto Suspension | Auto-suspend idle servers |
| 41 | Saga Minecraft Modpack Installer | Modpack installation |
| 42 | Server Backgrounds | Custom server backgrounds |
| 43 | Server Icon Importer | Import server icons |
| 44 | Server ID | Display server IDs |
| 45 | Server Importer | Import servers |
| 46 | Server Props Manager | Server property editor |
| 47 | Server Splitter | Split server resources |
| 48 | Show Node IDs | Display node IDs |
| 49 | Sidebar | Custom sidebar |
| 50 | Simple Favicons | Custom favicons |
| 51 | Simple Footers | Custom footers |
| 52 | Snowflakes | Snowflake animations |
| 53 | Social Login | Social auth (Discord, etc.) |
| 54 | Startup Changer | Modify server startup |
| 55 | Stats | Statistics dashboard |
| 56 | Stellar | Stellar theme extension |
| 57 | Subdomain Manager | Manage subdomains |
| 58 | Subdomains | Subdomain tools |
| 59 | Tawk.to | Tawk.to chat integration |
| 60 | Translations | Multi-language support |
| 61 | Trash Bin | Deleted items recovery |
| 62 | URL Downloader | Download from URLs |
| 63 | Vanilla Tweaks | Minecraft vanilla tweaks |
| 64 | Version Changer | Change server versions |
| 65 | VM Info | Display VM information |
| 66 | Votifier Tester | Minecraft Votifier tester |

---

## Module 6: System Manager

**Path:** `lib/sysmgr.sh`

```
 ◆ HAPPY-NODE SYSTEM MANAGER
 ────────────────────────────────────────────────────────────
 System: Ubuntu 22.04   Arch: x86_64   PM: apt

  [1] Update system
  [2] System information
  [3] Running processes
  [4] Cleanup cache/temp
  [5] Reboot server
  [0] Back
```

### System Manager Features

| Option | Action | Description |
|--------|--------|-------------|
| **Update** | `apt upgrade` / `dnf upgrade` | Updates package lists and upgrades all installed packages |
| **System Info** | `/proc/cpuinfo`, `free -h`, `df -h` | Hostname, kernel, OS, CPU, uptime, memory, disk usage |
| **Processes** | `ps aux --sort=-%cpu` | Top 10 processes sorted by CPU usage |
| **Cleanup** | `apt-get clean`, `apt-get autoremove` | Clears package cache and removes orphaned dependencies |
| **Reboot** | `reboot` | Server reboot with confirmation prompt |

---

## Module 7: Container (Docker)

**Path:** `Extras/docker.sh`

Direct Docker container deployment with custom resource allocation (CPU, RAM, ports).

---

## Module 8: Extras

**Path:** `Extras/run.sh`

```
─────────── HAPPY-NODE EXTRAS MENU ───────────
 1) Docker
 2) LXC/LXD
 0) Back
────────────────────────────────────────
```

### Extras Options

| Option | Script | Description |
|--------|--------|-------------|
| **Docker** | `Extras/docker.sh` | Docker engine installation and container management |
| **LXC/LXD** | `Extras/Cockpit.sh` | LXC/LXD container hypervisor + Cockpit web interface |

---

## Project Structure

```
HAPPY-NODE/                           (173 files, ~179 MB)
│
├── menu.sh                          # Main entry point - dashboard + routing
├── README.md                        # Project documentation
├── LICENSE                          # MIT License
│
├── lib/                             # Core libraries (0.01 MB)
│   ├── common.sh                    # Colors, helpers, platform detection
│   └── sysmgr.sh                    # System manager submenu
│
├── setup vm/                        # VM management (0.32 MB)
│   ├── menu.sh                      # VM menu UI
│   ├── vm-1.sh                      # KVM-based VM setup
│   ├── vm-2.sh                      # No-KVM VM setup
│   └── vm-3.sh                      # Complete VM setup
│
├── panel/                           # Panel installers (0.13 MB)
│   ├── 1.sh                         # Panel selection menu
│   ├── pterodactyl/                 # Pterodactyl panel + SSL + phpMyAdmin
│   │   └── install.sh
│   ├── Jexactyl/
│   │   └── install.sh
│   ├── reviactyl/
│   │   ├── install.sh
│   │   └── run.sh
│   ├── paymenter/
│   │   ├── install.sh
│   │   └── run.sh
│   ├── Convoy/
│   │   └── install.sh
│   └── mythical/
│       ├── install.sh
│       └── run.sh
│
├── wings/                           # Wings daemon management (0.05 MB)
│   ├── run.sh                       # Wings manager UI
│   ├── install.sh                   # Wings installer
│   ├── mang.sh                      # Wings service manager
│   ├── config.sh                    # Wings configuration
│   └── db.sh                        # Database manager
│
├── toolbox/                         # Server utilities (0.06 MB)
│   ├── run.sh                       # Toolbox menu UI
│   ├── root.sh                      # Root/Sudo access
│   ├── tailscale.sh                 # Tailscale VPN
│   ├── zerotier.sh                  # ZeroTier VPN
│   ├── cloudflare.sh                # Cloudflare DNS/Tunnel
│   ├── localtonet.sh                # Port forwarding
│   ├── terminal.sh                  # Web terminal
│   └── info.sh                      # System information
│
├── thame/                           # Theme system (122.95 MB)
│   ├── run.sh                       # Theme manager UI
│   ├── thames.sh                    # 44-theme installer (BP/ZIP/ARIX)
│   ├── install.sh                   # Blueprint framework installer
│   │
│   ├── UI/                          # 29 Blueprint theme files
│   │   ├── nebula.blueprint
│   │   ├── euphoriatheme.blueprint
│   │   ├── BetterAdmin.blueprint
│   │   └── ... (29 total)
│   │
│   ├── UI/themes/                   # 11 ZIP theme files
│   │   ├── billing.zip              (6.29 MB)
│   │   ├── stellar.zip              (0.23 MB)
│   │   ├── NoraTheme.zip            (22.84 MB)
│   │   └── ... (11 total)
│   │
│   ├── Extension/                   # 66 Blueprint extension files
│   │   ├── customcss.blueprint
│   │   ├── consolelogs.blueprint
│   │   └── ... (66 total)
│   │
│   ├── arix/                        # ARIX theme (4 versions)
│   │   ├── install.sh               # ARIX installer v3.0
│   │   ├── v210/pterodactyl.zip     (8.63 MB)
│   │   ├── v208/pterodactyl.zip     (10.10 MB)
│   │   ├── v131/pterodactyl.zip     (9.11 MB)
│   │   └── av1/pterodactyl.zip      (10.10 MB)
│   │
│   └── happy-theme/                 # HAPPY-NODE's own theme
│       └── install.sh
│
├── Extras/                          # Extra tools (0.02 MB)
│   ├── run.sh                       # Extras menu
│   ├── docker.sh                    # Docker installer
│   ├── Cockpit.sh                   # LXC/LXD + Cockpit
│   └── vps-setup.sh                 # VPS setup
│
└── pterodactyl_extention1/          # ARIX source files (55.84 MB)
    └── sd/                          # Arix ZIP archives
        ├── v210/pterodactyl.zip
        ├── v208/pterodactyl.zip
        ├── v131/pterodactyl.zip
        └── av1/pterodactyl.zip
```

---

## Security Features

### 1. Base64-Encoded URLs
All GitHub raw URLs are stored as base64-encoded strings to prevent:
- Repository leaking during runtime
- Easy identification of source code
- URL manipulation by users

```bash
_HN_B64='aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4='
_HN_BASE="$(printf '%s' "$_HN_B64" | base64 -d)"
```

### 2. Backdoor Detection (ARIX)
The ARIX installer scans for and removes known malicious files:
- `app/Console/Commands/Arix.php` — credential exfiltration backdoor
- `arix/ins/ins.php` — injection script
- `arix/up/up.php` — update hijacker

### 3. ZIP Verification
All downloaded ZIPs are verified before extraction:
```bash
head -c 2 "download.zip" | grep -q 'PK'  # ZIP magic number check
```

### 4. HTML Response Detection
Blueprint downloads are checked for HTML responses (indicating server error):
```bash
head -c 15 "$NAME" | grep -qi "<!DOCTYPE\|<html"
```

### 5. Backup Before Install
ARIX installer creates backups with rollback support:
```bash
BACKUP_DIR="/tmp/hn_backups"
# Creates timestamped backup of: resources, public, app, routes, config, database, .env
```

### 6. No Hardcoded Credentials
All panel installers generate random passwords:
```bash
DB_PASS=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-24)
```

---

## Requirements

| Requirement | Details |
|-------------|---------|
| **OS** | Debian 10+, Ubuntu 18.04+, Alpine, RHEL, CentOS, Fedora |
| **Access** | Root access (`sudo` or direct root login) |
| **RAM** | Minimum 1 GB (2 GB recommended for panels, 4 GB for multiple servers) |
| **Disk** | Minimum 10 GB free space |
| **Network** | Active internet connection |
| **Ports** | Open ports 80 (HTTP) and 443 (HTTPS) for panel + SSL |
| **Dependencies** | `curl` (auto-installed if missing) |

### Supported Architectures

| Architecture | Status |
|-------------|--------|
| x86_64 (amd64) | ✅ Fully supported |
| aarch64 (arm64) | ✅ Fully supported |

---

## FAQ

### Q: Does this require a fresh VPS?
**A:** Recommended but not required. Use a clean VPS to avoid conflicts with existing services.

### Q: Can I use this with Cloudflare?
**A:** Yes! Disable proxy (orange cloud) during SSL setup, then enable after.

### Q: What panels are supported?
**A:** Pterodactyl, Jexactyl, Reviactyl, Paymenter, Convoy, and MythicalDash.

### Q: Do I need to install anything first?
**A:** Only `curl` is needed. The tool auto-installs everything else.

### Q: Can I run this multiple times?
**A:** Yes! Each script handles reinstallation gracefully.

### Q: How do I update HAPPY-NODE?
**A:** Simply run the command again — it always pulls the latest version from GitHub.

### Q: Is this safe to use?
**A:** All scripts are open source, MIT licensed. ARIX installer includes backdoor detection. No data is collected.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open a Pull Request

### Development Guidelines
- All URLs must be base64-encoded
- Use ASCII markers (`[OK]`, `[FAIL]`) instead of emoji in bash scripts
- Test on Debian/Ubuntu before committing
- Follow existing code style
- No hardcoded credentials or secrets

---

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">

**Built with ❤️ by HAPPY-NODE**

[![Website](https://img.shields.io/badge/Website-happyff.indevs.in-blue?style=for-the-badge&logo=googlechrome&logoColor=white)](https://happyff.indevs.in/)
[![GitHub](https://img.shields.io/badge/GitHub-HAPPY--NODE-black?style=for-the-badge&logo=github&logoColor=white)](https://github.com/HAPPY-NODE)

</div>
