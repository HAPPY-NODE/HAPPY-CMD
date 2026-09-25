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
msg_info() { echo -e "  ${C}➜${NC} $1"; }
msg_ok()   { echo -e "  ${G}✔${NC} $1"; }
msg_warn() { echo -e "  ${Y}⚠${NC} $1"; }
msg_err()  { echo -e "  ${R}✖${NC} $1"; }

get_hostname() {
    if command -v hostname >/dev/null 2>&1; then hostname
    elif [ -f /etc/hostname ]; then head -n 1 /etc/hostname
    else echo "Unknown-Host"; fi
}

show_header() {
    clear
    local host_name os_info ts_status ts_ip exit_node health_check
    host_name=$(get_hostname)
    if [ -f /etc/os-release ]; then
        os_info=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    else
        os_info=$(uname -s)
    fi
    ts_status="${R}NOT INSTALLED${NC}"
    ts_ip="${DG}---${NC}"
    exit_node="${DG}OFF${NC}"
    health_check="${R}DISCONNECTED${NC}"

    if command -v tailscale >/dev/null 2>&1; then
        if systemctl is-active --quiet tailscaled 2>/dev/null; then
            ts_status="${G}ACTIVE${NC}"
            local ip_fetch
            ip_fetch=$(tailscale ip -4 2>/dev/null)
            if [ -n "$ip_fetch" ]; then
                ts_ip="${C}$ip_fetch${NC}"
                health_check="${G}CONNECTED${NC}"
            else
                ts_ip="${Y}Needs Auth${NC}"
            fi
            if tailscale status --self 2>/dev/null | grep -q "exit node"; then
                exit_node="${P}ACTIVE${NC}"
            fi
        else
            ts_status="${R}STOPPED${NC}"
        fi
    fi

    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     T A I L S C A L E                        ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    HAPPY NODE • Mesh VPN                     ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${DG}Device:${NC} ${W}${host_name}${NC}  ${DG}│${NC}  ${DG}System:${NC} ${W}${os_info:0:30}${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${DG}Mesh:${NC}     ${ts_status}"
    echo -e "  ${DG}VPN IP:${NC}   ${ts_ip}"
    echo -e "  ${DG}Exit Node:${NC} ${exit_node}"
    echo -e "  ${DG}Health:${NC}   ${health_check}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

install_tailscale() {
    st INFO "Initializing setup sequence..."
    echo -ne "  ${C}[1/3]${NC} Downloading core binaries... "
    if curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1; then
        echo -e "${G}DONE${NC}"
    else
        echo -e "${R}FAIL${NC}"
        pause; return
    fi
    echo -ne "  ${C}[2/3]${NC} Configuring systemd service... "
    if sudo systemctl enable --now tailscaled >/dev/null 2>&1; then
        echo -e "${G}DONE${NC}"
    else
        echo -e "${Y}SKIP${NC}"
    fi
    echo -e "  ${C}[3/3]${NC} Authentication required"
    echo ""
    echo -e "  ${Y}┌──────────────────────────────────────────────┐${NC}"
    echo -e "  ${Y}│  Click the link below to join your mesh      │${NC}"
    echo -e "  ${Y}└──────────────────────────────────────────────┘${NC}"
    echo ""
    tailscale up
    echo ""
    msg_ok "Device joined the mesh"
    pause
}

uninstall_tailscale() {
    st WARN "UNINSTALL — will leave private network"
    read -rp "  Confirm removal? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        st WAIT "Stopping services..."
        systemctl stop tailscaled 2>/dev/null
        systemctl disable tailscaled 2>/dev/null
        st WAIT "Removing packages..."
        if command -v apt >/dev/null 2>&1; then sudo apt purge tailscale -y -qq >/dev/null 2>&1
        elif command -v dnf >/dev/null 2>&1; then sudo dnf remove tailscale -y -q >/dev/null 2>&1
        elif command -v apk >/dev/null 2>&1; then sudo apk del tailscale >/dev/null 2>&1; fi
        st WAIT "Wiping configuration..."
        sudo rm -rf /var/lib/tailscale /etc/tailscale
        st OK "Tailscale completely removed"
    else
        st INFO "Cancelled"
    fi
    pause
}

network_map() {
    st INFO "Scanning mesh network..."
    echo ""
    if command -v tailscale >/dev/null 2>&1; then
        tailscale status 2>/dev/null
    else
        msg_err "Tailscale not installed"
    fi
    echo ""
    pause
}

while true; do
    show_header
    echo -e "  ${C}◆ CORE OPERATIONS${NC}"
    echo -e "     ${GR}[1]${NC} Install            ${DG}•${NC} Join Mesh"
    echo -e "     ${GR}[2]${NC} Uninstall          ${DG}•${NC} Leave Mesh"
    echo ""
    echo -e "  ${Y}◆ DIAGNOSTICS${NC}"
    echo -e "     ${GR}[3]${NC} Network Map        ${DG}•${NC} List Peers"
    echo -e "     ${GR}[4]${NC} Troubleshooting    ${DG}•${NC} netcheck"
    echo ""
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-4):${NC} "
    read -r option
    case $option in
        1) install_tailscale ;;
        2) uninstall_tailscale ;;
        3) network_map ;;
        4) echo ""; tailscale netcheck 2>/dev/null; pause ;;
        0) clear; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
