# HAPPY-NODE · HAPPY-CMD

<p align="center"><b>One command. Zero downloads. Full server toolkit.</b></p>

```bash
bash <(curl -fsSL https://happyff.indevs.in)
```

Nothing is saved on your VPS — every script streams live from GitHub and
self-deletes the moment it finishes. Only real installs (panels, themes,
bots) are written to disk.

<details>
<summary>Alternative entry (raw GitHub)</summary>

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HAPPY-NODE/HAPPY-CMD/main/menu.sh)
```

</details>

## What's inside

| # | Section | Description |
|---|---------|-------------|
| 1 | **VPS Setup** | KVM & No-KVM virtual machine manager |
| 2 | **Panel Manager** | Pterodactyl (version selector), PufferPanel, Paymenter, Convoy, MythicalDash, Jexactyl, Reviactyl, HVM, HKVM, AKVM |
| 3 | **Wings Manager** | Wings install, SSL, service control, DB, nodes |
| 4 | **Toolbox** | Root tools, VPN (Tailscale/ZeroTier/Cloudflare), sysinfo, web terminal |
| 5 | **Themes** | Blueprint, themes & extensions, ARIX, Hyper |
| 6 | **Discord VPS Bot** | Docker / LXC / SSHX bot installers (token → admin → env) |
| 7 | **Backup** | Full / DB / incremental backup & restore, cron |
| 8 | **Utilities** | File organizer, logs, cron, SSL, ports |

## Highlights

- **Streaming architecture** — no clone, no temp dir, no residue (`hn_run` fetches → runs → deletes)
- **Responsive UI** — auto 3-col / 2-col / 1-col layout for any terminal width
- **Pterodactyl installer with version selector** — lists all GitHub releases, install any panel version non-interactively (HAPPY-NODE branded)
- **Non-interactive everywhere** — PufferPanel admin creation uses CLI flags (no stuck survey prompts), EOF-safe menus (no infinite loops)
- **Boot splash** — skip with `HN_NO_SPLASH=1`
- **Dashboard header** — live uptime / disk / CPU / RAM pill + HAPPY-NODE banner

## Requirements

- Linux VPS (Ubuntu / Debian), Bash 4+, `curl`
- Root access

## Local development

```bash
git clone https://github.com/HAPPY-NODE/HAPPY-CMD.git
cd HAPPY-CMD
./menu.sh          # runs straight from the clone
```

Validate before pushing:

```bash
for f in $(find . -name '*.sh'); do bash -n "$f" || echo "FAIL $f"; done
```

---

<p align="center">Powered by <b>HAPPY-NODE</b> · github.com/HAPPY-NODE</p>
