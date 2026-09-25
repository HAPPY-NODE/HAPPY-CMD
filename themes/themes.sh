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
PANEL_DIR="/var/www/pterodactyl"

st() {
    case $1 in
        OK)   echo -e "  ${FG}✓${NC} $2" ;;
        ERR)  echo -e "  ${FR}✗${NC} $2" ;;
        INFO) echo -e "  ${FC}→${NC} $2" ;;
        WAIT) echo -e "  ${FY}⏳${NC} $2" ;;
        WARN) echo -e "  ${FY}!${NC} $2" ;;
    esac
}
pause() { echo ""; read -rp "  Press Enter to continue... " _; }

dots_load() {
    local msg="$1" n="${2:-3}"
    printf "   %s" "$msg"
    for ((i=0; i<n; i++)); do printf "."; sleep 0.3; done
    printf "\r\033[K"
}

spinner() {
    local msg="$1"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while true; do
        printf "\r   ${FC}%s${NC} %s" "${frames[i]}" "$msg"
        i=$(( (i+1) % ${#frames[@]} ))
        sleep 0.1
    done
}

section_enter() {
    local name="$1"
    clear
    spinner "Opening $name" &
    local spid=$!
    sleep 0.55
    kill $spid 2>/dev/null
    wait $spid 2>/dev/null
    printf "\r\033[K"
    st OK "$name ready"
    sleep 0.18
    clear
}

# ---------- Status ----------
bp_status() {
    if command -v blueprint >/dev/null 2>&1; then echo -e "${FG}●${NC}"; else echo -e "${FR}●${NC}"; fi
}
theme_status() {
    if [ -d "$PANEL_DIR/resources/views/vendor/blueprint" ]; then echo -e "${FG}●${NC}"; else echo -e "${FR}●${NC}"; fi
}
ext_status() {
    if [ -d "$PANEL_DIR/extensions" ] && [ -n "$(ls -A "$PANEL_DIR/extensions" 2>/dev/null)" ]; then
        echo -e "${FG}●${NC}"
    else
        echo -e "${FR}●${NC}"
    fi
}
arix_status() {
    if [ -d "$PANEL_DIR/arix" ]; then echo -e "${FG}●${NC}"; else echo -e "${FR}●${NC}"; fi
}
hyper_status() {
    if [ -d "$PANEL_DIR/resources/views/vendor/hyper" ]; then echo -e "${FG}●${NC}"; else echo -e "${FR}●${NC}"; fi
}
panel_ok() {
    [ -d "$PANEL_DIR" ] && [ -f "$PANEL_DIR/artisan" ]
}

panel_clear() {
    cd "$PANEL_DIR" 2>/dev/null || return
    php artisan view:clear 2>/dev/null
    php artisan config:clear 2>/dev/null
    php artisan cache:clear 2>/dev/null
    php artisan route:clear 2>/dev/null
    php artisan optimize:clear 2>/dev/null
    chown -R www-data:www-data "$PANEL_DIR"/* 2>/dev/null
    php artisan queue:restart 2>/dev/null
}

# ---------- Header ----------
show_header() {
    clear
    local pstate="${FR}NO PANEL${NC}"
    panel_ok && pstate="${GR}PANEL OK${NC}"
    echo ""
    printf "  ${CB}┌──────────────────────────────────────────────────────────┐${NC}\n"
    printf "  ${CB}│${NC}  ${M}◆${NC} ${FW}HAPPY NODE${NC} ${VI}ᴛʜᴇᴍᴇ ꜱᴛᴜᴅɪᴏ${NC}                          ${CB}│${NC}\n"
    printf "  ${CB}│${NC}  ${TE}visual customization • panel modules${NC}              ${CB}│${NC}\n"
    printf "  ${CB}└──────────────────────────────────────────────────────────┘${NC}\n"
    echo ""
    printf "  ${SL}panel${NC}  ${CB}${PANEL_DIR}${NC}\n"
    printf "  ${SL}state${NC}  ${pstate}\n"
    echo ""
}

# ---------- Menu ----------
show_menu() {
    echo -e "  ${FC}◆${NC} ${FW}MODULES${NC}"
    echo ""

    # row items helper via printf lines
    printf "   ${GR}1${NC}  ${GR}ʙʟᴜᴇᴘʀɪɴᴛ ꜰʀᴀᴍᴇᴡᴏʀᴋ${NC}  %s  ${SL}core installer for .blueprint themes${NC}\n" "$(bp_status)"
    printf "   ${GR}2${NC}  ${GR}ᴛʜᴇᴍᴇ ʟɪʙʀᴀʀʏ${NC}       %s  ${SL}blueprint + zip + arix looks${NC}\n" "$(theme_status)"
    printf "   ${GR}3${NC}  ${GR}ᴇxᴛᴇɴꜱɪᴏɴꜱ${NC}          %s  ${SL}mod packs & panel add-ons${NC}\n" "$(ext_status)"
    printf "   ${GR}4${NC}  ${GR}ᴀʀɪx ᴛʜᴇᴍᴇ${NC}          %s  ${SL}premium multi-version UI${NC}\n" "$(arix_status)"
    printf "   ${GR}5${NC}  ${GR}ʜʏᴘᴇʀ ᴠ1${NC}            %s  ${SL}admin revamp theme${NC}\n" "$(hyper_status)"
    printf "   ${GR}6${NC}  ${GR}ᴘᴀɴᴇʟ ᴄᴀᴄʜᴇ${NC}         ${FY}●${NC}  ${SL}clear view / config / cache${NC}\n"

    echo ""
    echo -e "  ${CY}────────────────────────────────────────────────────────────────${NC}"
    printf "  ${FR}[0]${NC} ${FR}ʙᴀᴄᴋ${NC}          ${SL}pick a module number to open${NC}\n"
    echo -e "  ${CY}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${FC}❯${NC} ${FW}Select${NC} ${SL}(0-6):${NC} "
}

run_card() {
    local name="$1" script="$2"
    section_enter "$name"
    hn_run "$script"
}

# ---------- Main ----------
while true; do
    show_header
    if ! panel_ok; then
        st WARN "Pterodactyl not found at $PANEL_DIR"
        st INFO "Install panel first — Panel Manager ${SL}→${NC} ${FW}[4]${NC} Pterodactyl"
        echo ""
    fi
    show_menu
    read -r opt
    case $opt in
        1) run_card "Blueprint" "themes/blueprint.sh" ;;
        2) run_card "Theme Library" "themes/manager.sh" ;;
        3) run_card "Extensions" "themes/extensions.sh" ;;
        4) run_card "ARIX Theme" "themes/arix.sh" ;;
        5) run_card "Hyper V1" "themes/hyper.sh" ;;
        6)
            section_enter "Panel Cache"
            panel_clear
            st OK "Cache cleared + queue restarted"
            pause
            ;;
        0) dots_load "Closing studio" 2; exit 0 ;;
        *) echo -e "  ${FR}✗${NC} ${FW}Invalid option${NC}"; sleep 0.7 ;;
    esac
done
