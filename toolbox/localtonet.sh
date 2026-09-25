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
    local installed="MISSING"
    command -v localtonet >/dev/null 2>&1 && installed="INSTALLED"
    local st_color="${R}"
    [ "$installed" = "INSTALLED" ] && st_color="${G}"
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     P O R T   F O R W A R D                  ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    HAPPY NODE • Localtonet Tunnel            ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${DG}Status:${NC} ${st_color}${installed}${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

install_lt() {
    st WAIT "Installing Localtonet..."
    curl -fsSL https://localtonet.com/install.sh | sh
    if command -v localtonet >/dev/null 2>&1; then
        st OK "Installation complete"
    else
        st ERR "Installation failed"
    fi
    pause
}

uninstall_lt() {
    st WARN "Uninstalling Localtonet..."
    read -rp "  Confirm? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf ~/.localtonet
        rm -f /usr/local/bin/localtonet
        st OK "Uninstalled successfully"
    else
        st INFO "Cancelled"
    fi
    pause
}

run_lt() {
    if ! command -v localtonet >/dev/null 2>&1; then
        st ERR "Localtonet not found — install first"
        pause; return
    fi
    read -rp "  Auth-Token: " USER_TOKEN
    if [ -z "$USER_TOKEN" ]; then
        st ERR "Token missing"
        pause; return
    fi
    st WAIT "Setting token..."
    localtonet authtoken "$USER_TOKEN"
    read -rp "  Port (default 8080): " PORT
    PORT=${PORT:-8080}
    st INFO "Starting tunnel on port ${PORT}..."
    localtonet tcp --port "$PORT"
}

while true; do
    show_header
    echo -e "  ${C}◆ OPERATIONS${NC}"
    echo -e "     ${GR}[1]${NC} Install            ${DG}•${NC} Download Client"
    echo -e "     ${GR}[2]${NC} Uninstall          ${DG}•${NC} Remove All"
    echo -e "     ${GR}[3]${NC} Run Tunnel         ${DG}•${NC} TCP / UDP Forward"
    echo ""
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-3):${NC} "
    read -r choice || exit 0
    case $choice in
        1) install_lt ;;
        2) uninstall_lt ;;
        3) run_lt ;;
        0) clear; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
