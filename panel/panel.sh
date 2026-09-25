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

# ---------- Animations ----------
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
        printf "\r   ${C}%s${NC} %s" "${frames[i]}" "$msg"
        i=$(( (i+1) % ${#frames[@]} ))
        sleep 0.1
    done
}

fade_line() {
    local line="$1" delay="${2:-0.015}" i
    for ((i=0; i<${#line}; i++)); do
        printf "%s" "${line:i:1}"
        sleep "$delay"
    done
    printf "\n"
}

panel_intro() {
    clear
    local frames=('▁' '▃' '▄' '▅' '▆' '▇' '█' '▇' '▆' '▅' '▄' '▃' '▁')
    local i bar=""
    for ((i=0; i<18; i++)); do
        bar+="${frames[i%${#frames[@]}]}"
        printf "\r  ${FC}◆${NC} ${CB}ᴘᴀɴᴇʟ ᴍᴀɴᴀɢᴇʀ${NC} ${DG}${bar}${NC}"
        sleep 0.04
    done
    printf "\r\033[K"
    echo -e "  ${GR}✓${NC} ${CB}ᴘᴀɴᴇʟ ᴍᴀɴᴀɢᴇʀ${NC} ${SL}ready${NC}"
    sleep 0.18
}

section_enter() {
    local name="$1"
    clear
    # smooth title type-in
    printf "  "
    local i
    for ((i=0; i<${#name}; i++)); do
        printf "${C}%s${NC}" "${name:i:1}"
        sleep 0.03
    done
    printf "\n"
    spinner "Loading $name" &
    local spid=$!
    sleep 0.65
    kill $spid 2>/dev/null
    wait $spid 2>/dev/null
    printf "\r\033[K"
    echo -e "  ${G}✓${NC} ${W}$name${NC} loaded"
    # soft wipe
    local n
    for n in 1 2; do printf "\r  ${DG}· · ·${NC}"; sleep 0.12; printf "\r\033[K"; done
    clear
}

# ---------- Status check ----------
panel_status() {
    local dir="$1"
    if [ -d "$dir" ]; then
        echo -e "${G}● INSTALLED${NC}"
    else
        echo -e "${R}● NOT INSTALLED${NC}"
    fi
}

hkvm_status() {
    if pgrep -f "/root/hkvm/hkvm/app.js" >/dev/null 2>&1; then
        echo -e "${G}● RUNNING${NC}"
    elif [ -d "/root/hkvm/hkvm" ]; then
        echo -e "${Y}● INSTALLED${NC}"
    else
        echo -e "${R}● NOT INSTALLED${NC}"
    fi
}

hvm_status() {
    if pgrep -f "/root/hvm/hvm/hvm.py" >/dev/null 2>&1; then
        echo -e "${G}● RUNNING${NC}"
    elif [ -d "/root/hvm/hvm" ]; then
        echo -e "${Y}● INSTALLED${NC}"
    else
        echo -e "${R}● NOT INSTALLED${NC}"
    fi
}

akvm_status() {
    if pgrep -f "/opt/akvm/akvm.py" >/dev/null 2>&1; then
        echo -e "${G}● RUNNING${NC}"
    elif [ -d "/opt/akvm" ]; then
        echo -e "${Y}● INSTALLED${NC}"
    else
        echo -e "${R}● NOT INSTALLED${NC}"
    fi
}

pp_status() {
    if systemctl is-active --quiet pufferpanel 2>/dev/null; then
        echo -e "${G}● RUNNING${NC}"
    elif command -v pufferpanel >/dev/null 2>&1; then
        echo -e "${Y}● INSTALLED${NC}"
    else
        echo -e "${R}● NOT INSTALLED${NC}"
    fi
}

# ---------- Header ----------
show_header() {
    clear
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${CB}       ᴘᴀɴᴇʟ ᴍᴀɴᴀɢᴇʀ                          ${CB}│${NC}"
    echo -e "  ${CB}│${DG}      ꜱᴇʀᴠᴇʀ ᴄᴏɴᴛʀᴏʟ ᴘᴀɴᴇʟꜱ                   ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${FC}◆ ᴀᴠᴀɪʟᴀʙʟᴇ ᴘᴀɴᴇʟꜱ${NC}"
    echo -e "     ${GR}[1]${NC} ${GR}ʜᴠᴍ ᴘᴀɴᴇʟ${NC}        ${DG}•${NC} $(hvm_status)"
    echo -e "     ${GR}[2]${NC} ${GR}ʜᴋᴠᴍ ᴘᴀɴᴇʟ${NC}       ${DG}•${NC} $(hkvm_status)"
    echo -e "     ${GR}[3]${NC} ${GR}ᴀᴋᴠᴍ ᴘᴀɴᴇʟ${NC}       ${DG}•${NC} $(akvm_status)"
    echo -e "     ${GR}[4]${NC} ${GR}ᴘᴛᴇʀᴏᴅᴀᴄᴛʏʟ${NC}      ${DG}•${NC} $(panel_status /var/www/pterodactyl)"
    echo -e "     ${GR}[5]${NC} ${GR}ᴊᴇxᴀᴄᴛʏʟ${NC}         ${DG}•${NC} $(panel_status /var/www/jexactyl)"
    echo -e "     ${GR}[6]${NC} ${GR}ʀᴇᴠɪᴀᴄᴛʏʟ${NC}        ${DG}•${NC} $(panel_status /var/www/reviactyl)"
    echo -e "     ${GR}[7]${NC} ${GR}ᴘᴀʏᴍᴇɴᴛᴇʀ${NC}        ${DG}•${NC} $(panel_status /var/www/paymenter)"
    echo -e "     ${GR}[8]${NC} ${GR}ᴄᴏɴᴠᴏʏ${NC}           ${DG}•${NC} $(panel_status /var/www/convoy)"
    echo -e "     ${GR}[9]${NC} ${GR}ᴍʏᴛʜɪᴄᴀʟᴅᴀꜱʜ${NC}    ${DG}•${NC} $(panel_status /var/www/mythicaldash)"
    echo -e "     ${GR}[10]${NC} ${GR}PufferPanel${NC}      ${DG}•${NC} $(pp_status)"
    echo -e "     ${FR}[0]${NC} ${FR}ʙᴀᴄᴋ${NC}"
    echo -e "  ${GY}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${FC}➜${NC} ${FW}Enter Option${NC} ${SL}(0-10):${NC} "
}

# ---------- Run panel script ----------
run_panel() {
    local name="$1"
    local script="$2"
    section_enter "$name"
    hn_run "$script"
}

# ---------- Main ----------
panel_intro
while true; do
    show_header
    read -r opt || exit 0
    case "$opt" in
        1) run_panel "HVM Panel" "panel/hvm.sh" ;;
        2) run_panel "HKVM Panel" "panel/hkvm.sh" ;;
        3) run_panel "AKVM Panel" "panel/akvm.sh" ;;
        4) run_panel "Pterodactyl" "panel/pterodactyl.sh" ;;
        5) run_panel "Jexactyl" "panel/jexactyl.sh" ;;
        6) run_panel "Reviactyl" "panel/reviactyl.sh" ;;
        7) run_panel "Paymenter" "panel/paymenter.sh" ;;
        8) run_panel "Convoy" "panel/convoy.sh" ;;
        9) run_panel "MythicalDash" "panel/mythical.sh" ;;
        10) run_panel "PufferPanel" "panel/pufferpanel.sh" ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
