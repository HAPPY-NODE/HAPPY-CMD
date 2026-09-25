# HAPPY-CMD

Terminal toolkit with auto-responsive UI — adjusts to any terminal size without glitches.

## Features

- Auto-detects terminal width (3-col / 2-col / 1-col layout)
- Compact banner for small terminals
- 8 tool sections + Exit
- Boot splash on start (`HN_NO_SPLASH=1` to skip)
- Panel modules with HAPPY NODE branding

## Sections

| # | Section | Description |
|---|---------|-------------|
| 1 | VPS Setup | KVM & No KVM virtual machine manager |
| 2 | Panel Manager | HVM, HKVM, AKVM, Pterodactyl & more |
| 3 | Wings Manager | SSL, install, service control, DB, nodes |
| 4 | Toolbox | Root, VPN, Cloudflare, sysinfo, web terminal |
| 5 | Themes | Blueprint, themes, extensions, ARIX, Hyper |
| 6 | Discord VPS Bot | Docker, LXC & SSHX Discord bot installers (token → admin → env) |
| 7 | Backup | Full/DB/incremental backup, restore, cron |
| 8 | Utilities | File organizer, logs, cron, SSL, ports |

## Install

One-liner — nothing is downloaded or saved on the VPS, every script streams
straight from GitHub (only actual panel/theme installs are written to disk):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HAPPY-NODE/HAPPY-CMD/main/menu.sh)
```

Or clone the full repo (includes theme/panel assets):

```bash
git clone https://github.com/HAPPY-NODE/HAPPY-CMD.git
cd HAPPY-CMD
chmod +x menu.sh
./menu.sh
```

## Requirements

- Bash 4+
- Linux/macOS (or WSL on Windows)
