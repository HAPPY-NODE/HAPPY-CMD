<div align="center">

```
  ██╗  ██╗ █████╗ ██████╗ ██████╗ ██╗   ██╗      ███╗   ██╗ ██████╗ ██████╗ ███████╗
  ██║  ██║██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝      ████╗  ██║██╔═══██╗██╔══██╗██╔════╝
  ███████║███████║██████╔╝██████╔╝ ╚████╔╝ █████╗██╔██╗ ██║██║   ██║██║  ██║█████╗
  ██╔══██║██╔══██║██╔═══╝ ██╔═══╝   ╚██╔╝  ╚════╝██║╚██╗██║██║   ██║██║  ██║██╔══╝
  ██║  ██║██║  ██║██║     ██║        ██║         ██║ ╚████║╚██████╔╝██████╔╝███████╗
  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝        ╚═╝         ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝
```

# ⚡ HAPPY-NODE

### Universal VPS Control Panel

A clean, modular, one-command toolkit to deploy and manage game server panels,
wings daemons, system utilities, themes, and infrastructure — all from a single terminal UI.

[![bash](https://img.shields.io/badge/Run-Bash-orange?style=for-the-badge&logo=gnubash&logoColor=white)](https://happyff.indevs.in/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-blue?style=for-the-badge&logo=linux&logoColor=white)]()

</div>

---

## 🚀 Quick Start

```bash
bash <(curl -fsSL https://happyff.indevs.in/)
```

That's it. One command. Full control.

---

## ✨ What's Inside

<table>
<tr>
<td width="50%">

### 🖥️ Deployment & Services

| # | Module | Description |
|---|--------|-------------|
| 1 | **VPS Setup** | RDX tool, KVM / No-KVM VM runners |
| 2 | **Panel** | Pterodactyl, Jexactyl, Reviactyl, Paymenter, Convoy |
| 3 | **Wings** | Install, manager, config, database |
| 4 | **Toolbox** | Tailscale, ZeroTier, Cloudflare, Terminal, Root |
| 5 | **Themes** | Blueprint, 20 UI themes, 66 extensions, ARIX |

</td>
<td width="50%">

### ⚙️ Maintenance & Tools

| # | Module | Description |
|---|--------|-------------|
| 6 | **System** | Update, info, processes, cleanup, reboot |
| 7 | **Container** | Docker containers with custom resources |
| 8 | **Extras** | Docker, LXC/LXD, LXDE/RDP, PufferPanel |
| 0 | **Exit** | Disconnect safely |

</td>
</tr>
</table>

---

## 📁 Project Structure

```
HAPPY-NODE/
├── menu.sh                  # Main entry — dashboard + routing
├── lib/
│   └── common.sh            # Colors, helpers, platform detection
├── setup vm/
│   └── menu.sh              # VPS / VM management UI
├── panel/
│   ├── 1.sh                 # Panel selector
│   ├── pterodactyl/         # Pterodactyl + SSL + phpMyAdmin
│   ├── Jexactyl/
│   ├── reviactyl/
│   ├── paymenter/
│   ├── Convoy/
│   └── mythical/
├── wings/
│   ├── run.sh               # Wings manager
│   ├── install.sh
│   ├── mang.sh
│   ├── config.sh
│   └── db.sh
├── toolbox/
│   ├── run.sh               # Tools menu
│   ├── tailscale.sh
│   ├── zerotier.sh
│   ├── cloudflare.sh
│   ├── localtonet.sh
│   ├── terminal.sh
│   ├── root.sh
│   └── info.sh
├── thame/
│   ├── run.sh               # Theme / extension hub
│   ├── thames.sh            # 20 UI themes
│   ├── Extension2.sh        # 66 extensions
│   ├── install.sh           # Blueprint framework
│   └── arix/                # ARIX theme (v1.3.1)
├── Extras/
│   ├── run.sh               # Extras menu
│   ├── docker.sh
│   ├── Cockpit.sh
│   └── vps-setup.sh
└── lib/
    ├── common.sh            # Shared library (colors, helpers)
    └── sysmgr.sh            # System manager submenu
```

---

## 🧱 Requirements

| Requirement | Details |
|-------------|---------|
| **OS** | Debian / Ubuntu / Alpine / RHEL / CentOS / Fedora |
| **Access** | Root access recommended |
| **RAM** | Minimum 2 GB (4 GB recommended for panels) |
| **Network** | Active internet connection |
| **Ports** | Open ports **80** & **443** for panel + SSL |

---

## 🛡️ Notes

- Use a **clean VPS** to avoid conflicts with existing services
- SSL certificates require a **domain** pointed at your server IP
- For Cloudflare users: disable proxy (orange cloud) during SSL setup, enable after

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">

**Built with ❤️ by HAPPY-NODE**

[![Website](https://img.shields.io/badge/Website-happyff.indevs.in-blue?style=for-the-badge&logo=googlechrome&logoColor=white)](https://happyff.indevs.in/)
[![GitHub](https://img.shields.io/badge/GitHub-HAPPY--NODE-black?style=for-the-badge&logo=github&logoColor=white)](https://github.com/HAPPY-NODE)

</div>
