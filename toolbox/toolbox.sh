#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
source "$ROOT/colors.sh"

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

section_enter() {
    local name="$1"
    clear
    printf "  "
    local i
    for ((i=0; i<${#name}; i++)); do
        printf "${C}%s${NC}" "${name:i:1}"
        sleep 0.03
    done
    printf "\n"
    spinner "Loading $name" &
    local spid=$!
    sleep 0.55
    kill $spid 2>/dev/null
    wait $spid 2>/dev/null
    printf "\r\033[K"
    st OK "$name loaded"
    sleep 0.2
    clear
}

detect_system() {
    HN_USER="$(whoami)"
    HN_HOST="$(hostname)"
    if command -v free >/dev/null 2>&1; then
        HN_RAM="$(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
    else
        HN_RAM="N/A"
    fi
    if command -v uptime >/dev/null 2>&1; then
        HN_LOAD="$(uptime | awk -F'load average:' '{print $2}' | xargs 2>/dev/null)"
    else
        HN_LOAD="N/A"
    fi
    HN_IP="$(curl -s --max-time 2 ifconfig.me 2>/dev/null || echo "Unavailable")"
}

show_header() {
    clear
    detect_system
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${CB}     ᴛᴏᴏʟʙᴏx                                  ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    HAPPY NODE • ꜱᴇʀᴠᴇʀ ᴜᴛɪʟɪᴛɪᴇꜱ             ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${SL}user${NC} ${W}${HN_USER}${NC}  ${GY}│${NC}  ${SL}host${NC} ${W}${HN_HOST:0:20}${NC}  ${GY}│${NC}  ${SL}ip${NC} ${W}${HN_IP:0:15}${NC}"
    echo -e "  ${SL}ram${NC}  ${W}${HN_RAM}${NC}  ${GY}│${NC}  ${SL}load${NC} ${W}${HN_LOAD:0:22}${NC}"
    echo -e "  ${GY}────────────────────────────────────────────────────────────────${NC}"
}

run_tool() {
    local name="$1"
    local script="$2"
    if [ -f "$script" ]; then
        section_enter "$name"
        bash "$script"
    else
        st ERR "Script not found: $script"
        sleep 1
    fi
}

echo -e "  ${C}→${NC} Detecting system info..."
sleep 0.4

while true; do
    show_header
    echo -e "  ${FC}◆ ᴀᴄᴄᴇꜱꜱ & ɴᴇᴛᴡᴏʀᴋ${NC}"
    echo -e "     ${GR}[1]${NC} ${GR}ʀᴏᴏᴛ ᴀᴄᴄᴇꜱꜱ${NC}        ${DG}•${NC} SSH / Password Control"
    echo -e "     ${GR}[2]${NC} ${GR}ᴛᴀɪʟꜱᴄᴀʟᴇ${NC}          ${DG}•${NC} Mesh VPN"
    echo -e "     ${GR}[3]${NC} ${GR}ᴢᴇʀᴏᴛɪᴇʀ${NC}           ${DG}•${NC} SDN Network"
    echo -e "     ${GR}[4]${NC} ${GR}ᴄʟᴏᴜᴅꜰʟᴀʀᴇ${NC}         ${DG}•${NC} Tunnel / DNS"
    echo ""
    echo -e "  ${M}◆ ꜱʏꜱᴛᴇᴍ & ɢᴜɪ${NC}"
    echo -e "     ${GR}[5]${NC} ${GR}ꜱʏꜱᴛᴇᴍ ɪɴꜰᴏ${NC}        ${DG}•${NC} Specs / 100 Tools"
    echo -e "     ${GR}[6]${NC} ${GR}ᴘᴏʀᴛ ꜰᴏʀᴡᴀʀᴅ${NC}       ${DG}•${NC} Localtonet TCP/UDP"
    echo -e "     ${GR}[7]${NC} ${GR}ᴡᴇʙ ᴛᴇʀᴍɪɴᴀʟ${NC}       ${DG}•${NC} Browser / Share Shell"
    echo -e "     ${GR}[8]${NC} ${GR}ꜱꜱʟ ᴘᴀɴᴇʟ${NC}          ${DG}•${NC} Certbot / Nginx"
    echo ""
    echo -e "     ${FR}[0]${NC} ${FR}ʙᴀᴄᴋ${NC}"
    echo -e "  ${GY}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${FC}➜${NC} ${FW}Enter Option${NC} ${SL}(0-8):${NC} "
    read -r opt
    case $opt in
        1) run_tool "Root Access" "$DIR/root.sh" ;;
        2) run_tool "Tailscale" "$DIR/tailscale.sh" ;;
        3) run_tool "ZeroTier" "$DIR/zerotier.sh" ;;
        4) run_tool "Cloudflare" "$DIR/cloudflare.sh" ;;
        5) run_tool "System Info" "$DIR/info.sh" ;;
        6) run_tool "Port Forward" "$DIR/localtonet.sh" ;;
        7) run_tool "Web Terminal" "$DIR/terminal.sh" ;;
        8)
            if [ -f "$ROOT/wings/wings.sh" ]; then
                section_enter "SSL Panel"
                bash "$ROOT/wings/wings.sh"
            else
                st ERR "SSL module not found"
                sleep 1
            fi
            ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
