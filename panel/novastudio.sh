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
HN_BASE_URL="${HN_BASE_URL:-https://raw.githubusercontent.com/HAPPY-NODE/HAPPY-CMD/main}"

NOVA_BASE="https://raw.githubusercontent.com/nobita329/NobitaHost/refs/heads/main/panel/NovaStudio"
NOVA_RUN_URL="$NOVA_BASE/run.sh"
NOVA_REPO="https://github.com/nobita329/NobitaHost/blob/main/panel/NovaStudio/run.sh"

st() {
    case $1 in
        OK)   echo -e "  ${G}✓${NC} $2" ;;
        ERR)  echo -e "  ${R}✗${NC} $2" ;;
        INFO) echo -e "  ${C}→${NC} $2" ;;
        WAIT) echo -e "  ${Y}⏳${NC} $2" ;;
    esac
}
pause() { echo ""; read -rp "  Press Enter to continue... " _; }

dots_load() {
    local msg="$1" n="${2:-3}"
    printf "   %s" "$msg"
    for ((i=0; i<n; i++)); do printf "."; sleep 0.3; done
    printf "\r\033[K"
}

# Sub-panels ka install dir (CWD/root/home — jahan se bhi run ho)
nova_dir() {
    local d
    for d in vpanel-pro Mpanel dpanel apanel; do
        if [ -d "/root/$d" ]; then echo "/root/$d"; return; fi
        if [ -d "$HOME/$d" ]; then echo "$HOME/$d"; return; fi
        if [ -d "./$d" ]; then echo "$(pwd)/$d"; return; fi
    done
    echo ""
}

show_header() {
    clear
    local status="${R}● NOT INSTALLED${NC}"
    local d
    d="$(nova_dir)"
    [ -n "$d" ] && status="${G}● INSTALLED${NC} ${DG}($d)${NC}"
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}      N O V A   S T U D I O                   ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    Multi-Panel Hub  • V/M/D/A panels         ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${W}Status:${NC}  $status"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

run_nova() {
    show_header
    st INFO "Launching Nova Studio hub (Vpanel/Mpanel/Dpanel/Apanel inside)..."
    st INFO "Repo: $NOVA_REPO"
    sleep 0.4
    if ! run_dl "Nova Studio run.sh" "$NOVA_RUN_URL" /tmp/nova_run.sh; then
        st ERR "Download failed."
        pause; return
    fi
    bash /tmp/nova_run.sh
    st OK "Nova Studio closed."
    pause
}

direct_sub() {
    show_header
    echo -e "  ${C}◆ DIRECT SUB-PANEL${NC}"
    echo -e "     ${GR}[1]${NC} Vpanel   ${DG}•${NC} vPanel Pro"
    echo -e "     ${GR}[2]${NC} Mpanel   ${DG}•${NC} Mpanel"
    echo -e "     ${GR}[3]${NC} Dpanel   ${DG}•${NC} Dpanel"
    echo -e "     ${GR}[4]${NC} Apanel   ${DG}•${NC} Apanel"
    echo -e "     ${R}[0]${NC} Cancel"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-4):${NC} "
    read -r sub || return
    local name="" url=""
    case "$sub" in
        1) name="Vpanel"; url="$NOVA_BASE/Vpanel.sh" ;;
        2) name="Mpanel"; url="$NOVA_BASE/Mpanel.sh" ;;
        3) name="Dpanel"; url="$NOVA_BASE/Dpanel.sh" ;;
        4) name="Apanel"; url="$NOVA_BASE/Apanel.sh" ;;
        0) return ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8; return ;;
    esac
    st WAIT "Starting $name..."
    if run_dl "$name.sh" "$url" "/tmp/nova_${name}.sh"; then
        bash "/tmp/nova_${name}.sh"
    else
        st ERR "Download failed."
    fi
    pause
}

nova_info() {
    show_header
    echo -e "  ${C}◆ NOVA STUDIO — INSTALL COMMAND${NC}"
    echo ""
    echo -e "  ${W}Run command:${NC}"
    echo "    bash <(curl -s $NOVA_RUN_URL)"
    echo ""
    echo -e "  ${W}GitHub link:${NC}"
    echo "    $NOVA_REPO"
    echo ""
    echo -e "  ${W}Hub ke andar:${NC}"
    echo -e "    ${DG}[1]${NC} Vpanel  ${DG}[2]${NC} Mpanel  ${DG}[5]${NC} Dpanel  ${DG}[6]${NC} Apanel"
    echo -e "    ${DG}[3][4][7] Soon  ${DG}[8]${NC} Exit"
    echo ""
    echo -e "  ${W}Install dirs:${NC}  vpanel-pro / Mpanel / dpanel / apanel"
    local d
    d="$(nova_dir)"
    if [ -n "$d" ]; then st OK "Detected: $d"; else st INFO "Koi sub-panel abhi install nahi"; fi
    pause
}

while true; do
    show_header
    echo -e "  ${C}◆ NOVA STUDIO MANAGEMENT${NC}"
    echo -e "     ${GR}[1]${NC} Launch Hub       ${DG}•${NC} Nova Studio menu (all panels)"
    echo -e "     ${GR}[2]${NC} Direct Sub-Panel ${DG}•${NC} V / M / D / A"
    echo -e "     ${GR}[3]${NC} Command Info     ${DG}•${NC} Run command + links"
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-3):${NC} "
    read -r choice || exit 0
    case $choice in
        1) run_nova ;;
        2) direct_sub ;;
        3) nova_info ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
