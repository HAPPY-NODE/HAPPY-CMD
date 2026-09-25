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
    local STATUS
    if command -v zerotier-cli >/dev/null 2>&1; then
        STATUS="${G}● INSTALLED${NC}"
    else
        STATUS="${R}○ MISSING${NC}"
    fi
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     Z E R O T I E R                          ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    HAPPY NODE • SDN Control                  ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${DG}Status:${NC} ${STATUS}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

join_network() {
    st WAIT "Downloading and installing ZeroTier..."
    curl -s https://install.zerotier.com | sudo bash >/dev/null 2>&1
    if ! command -v zerotier-cli >/dev/null 2>&1; then
        st ERR "Install failed"
        pause; return
    fi
    st OK "ZeroTier installed"
    read -rp "  Enter NETWORK_ID: " NETWORK_ID
    if [ -n "$NETWORK_ID" ]; then
        sudo zerotier-cli join "$NETWORK_ID" >/dev/null 2>&1
        st OK "Joined network"
    else
        st WARN "No ID provided — skipped join"
    fi
    pause
}

remove_network() {
    st WARN "Purging ZeroTier from system..."
    read -rp "  Confirm? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sudo apt remove zerotier-one -y >/dev/null 2>&1
        sudo apt purge zerotier-one -y >/dev/null 2>&1
        sudo rm -rf /var/lib/zerotier-one
        st OK "ZeroTier completely removed"
    else
        st INFO "Cancelled"
    fi
    pause
}

list_networks() {
    if command -v zerotier-cli >/dev/null 2>&1; then
        sudo zerotier-cli listnetworks 2>/dev/null
    else
        st ERR "ZeroTier not installed"
    fi
    pause
}

while true; do
    show_header
    echo -e "  ${C}◆ OPERATIONS${NC}"
    echo -e "     ${GR}[1]${NC} Join Network       ${DG}•${NC} Install + Join"
    echo -e "     ${GR}[2]${NC} Remove             ${DG}•${NC} Purge All"
    echo -e "     ${GR}[3]${NC} List Networks      ${DG}•${NC} Show Memberships"
    echo ""
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-3):${NC} "
    read -r choice || exit 0
    case $choice in
        1) join_network ;;
        2) remove_network ;;
        3) list_networks ;;
        0) clear; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
