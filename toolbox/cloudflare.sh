#!/bin/bash
DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
ROOT="$(dirname "$DIR")"
if [ -f "$ROOT/colors.sh" ]; then
    HN_ROOT="$ROOT"
    source "$ROOT/colors.sh"
else
    HN_BASE_URL="${HN_BASE_URL:-https://raw.githubusercontent.com/HAPPY-NODE/HAPPY-CMD/main}"
    source <(curl -fsSL --max-time 30 "$HN_BASE_URL/colors.sh")
    [ -n "${NC:-}" ] || { echo "x cannot fetch colors.sh from GitHub"; exit 1; }
fi

st() {
    case $1 in
        OK)   echo -e "  ${G}✓${NC} $2" ;;
        ERR)  echo -e "  ${R}✗${NC} $2" ;;
        INFO) echo -e "  ${C}→${NC} $2" ;;
        WAIT) echo -e "  ${Y}⏳${NC} $2" ;;
        WARN) echo -e "  ${Y}!${NC} $2" ;;
    esac
}
pause() { echo ""; read -rp "  Press Enter to continue... " _; }

show_header() {
    clear
    local s_status s_pid s_started arch
    s_status="${R}NOT INSTALLED${NC}"
    s_pid="${DG}---${NC}"
    s_started="${DG}---${NC}"
    arch=$(dpkg --print-architecture 2>/dev/null || uname -m)

    if command -v cloudflared >/dev/null 2>&1; then
        if systemctl is-active --quiet cloudflared 2>/dev/null; then
            s_status="${G}ACTIVE${NC}"
            s_pid="${W}$(pgrep -x cloudflared 2>/dev/null)${NC}"
            s_started="$(systemctl show -p ActiveEnterTimestamp cloudflared 2>/dev/null | cut -d= -f2 | cut -d' ' -f2-3)"
            [ -z "$s_started" ] && s_started="N/A"
        else
            s_status="${R}STOPPED${NC}"
        fi
    fi

    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     C L O U D F L A R E                      ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    HAPPY NODE • Tunnel Manager               ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${DG}Arch:${NC}     ${W}${arch}${NC}"
    echo -e "  ${DG}Service:${NC}  ${s_status}"
    echo -e "  ${DG}PID:${NC}      ${s_pid}"
    echo -e "  ${DG}Started:${NC}  ${C}${s_started}${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

install_cf() {
    st WAIT "Configuring Cloudflare repository..."
    sudo mkdir -p --mode=0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
    st OK "Repository added"

    st WAIT "Installing cloudflared binary..."
    sudo apt-get update -qq >/dev/null 2>&1
    sudo apt-get install -y cloudflared -qq >/dev/null 2>&1
    if command -v cloudflared >/dev/null 2>&1; then
        st OK "Cloudflared installed"
    else
        st ERR "Binary installation failed"
        pause; return
    fi

    if systemctl list-units --type=service 2>/dev/null | grep -q cloudflared; then
        st WAIT "Removing conflicting services..."
        sudo cloudflared service uninstall >/dev/null 2>&1
        st OK "Cleaned old service"
    fi

    echo ""
    echo -e "  ${Y}┌──────────────────────────────────────────────┐${NC}"
    echo -e "  ${Y}│  Paste your Tunnel Token below               │${NC}"
    echo -e "  ${Y}│  (full 'sudo cloudflared service install…')  │${NC}"
    echo -e "  ${Y}└──────────────────────────────────────────────┘${NC}"
    echo ""
    read -rp "  Token: " USER_TOKEN
    CLEAN_TOKEN=$(echo "$USER_TOKEN" | sed 's/sudo cloudflared service install //g' | sed 's/cloudflared service install //g' | xargs)
    if [ -z "$CLEAN_TOKEN" ]; then
        st ERR "Token cannot be empty"
        pause; return
    fi

    st WAIT "Registering tunnel service..."
    sudo cloudflared service uninstall >/dev/null 2>&1
    sudo cloudflared service install "$CLEAN_TOKEN"
    st INFO "Waiting for service to initialize..."
    local i
    for i in $(seq 1 15); do printf "▓"; sleep 0.12; done
    echo ""
    if systemctl is-active --quiet cloudflared; then
        st OK "Tunnel is online and stable"
    else
        st ERR "Service failed to start"
        echo -e "  ${DG}Debug: sudo journalctl -u cloudflared -f${NC}"
    fi
    pause
}

uninstall_cf() {
    st WARN "DESTRUCTIVE — remove tunnel + binary"
    read -rp "  Proceed? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        st WAIT "Stopping service..."
        sudo cloudflared service uninstall >/dev/null 2>&1
        st WAIT "Removing binary..."
        sudo apt-get remove -y cloudflared -qq >/dev/null 2>&1
        st WAIT "Cleaning configuration..."
        sudo rm -f /etc/apt/sources.list.d/cloudflared.list
        sudo rm -f /usr/share/keyrings/cloudflare-main.gpg
        st OK "Cloudflared completely removed"
    else
        st INFO "Cancelled"
    fi
    pause
}

while true; do
    show_header
    echo -e "  ${C}◆ OPERATIONS${NC}"
    echo -e "     ${GR}[1]${NC} Install Tunnel     ${DG}•${NC} Token + Service"
    echo -e "     ${GR}[2]${NC} Uninstall          ${DG}•${NC} Remove All"
    echo ""
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-2):${NC} "
    read -r choice || exit 0
    case $choice in
        1) install_cf ;;
        2) uninstall_cf ;;
        0) clear; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
