#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
source "$ROOT/colors.sh"

HN_BASE_URL="https://raw.githubusercontent.com/HAPPY-NODE/HAPPY-CMD/main"
IMG_URL="https://i.postimg.cc/jdbphsXP/Chat-GPT-Image-Sep-23-2026-05-48-16-PM.png"

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
        printf "\r   ${TE}%s${NC} %s" "${frames[i]}" "$msg"
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

svc_dot() {
    local unit="$1"
    if systemctl is-active --quiet "$unit" 2>/dev/null; then
        echo -e "${FG}●${NC}"
    elif [ -f "/etc/systemd/system/$unit" ]; then
        echo -e "${FY}●${NC}"
    else
        echo -e "${FR}●${NC}"
    fi
}

show_header() {
    clear
    echo ""
    printf "  ${CB}┌──────────────────────────────────────────────────────────┐${NC}\n"
    printf "  ${CB}│${NC}  ${M}◆${NC} ${FW}HAPPY NODE${NC} ${VI}ᴅɪꜱᴄᴏʀᴅ ᴠᴘꜱ ʙᴏᴛ${NC}                         ${CB}│${NC}\n"
    printf "  ${CB}│${NC}  ${TE}docker + lxc bot installers${NC}                          ${CB}│${NC}\n"
    printf "  ${CB}└──────────────────────────────────────────────────────────┘${NC}\n"
    echo ""
    printf "  ${SL}order${NC}  ${CB}token → admin id → optional vars${NC}\n"
    printf "  ${SL}brand${NC}  ${GR}HAPPY-NODE${NC} ${SL}github.com/HAPPY-NODE${NC}\n"
    echo ""
}

show_menu() {
    echo -e "  ${FC}◆${NC} ${FW}BOTS${NC}"
    echo ""
    printf "   ${GR}1${NC}  ${GR}ᴅᴏᴄᴋᴇʀ ᴠᴘꜱ ʙᴏᴛ${NC}      %s  ${SL}slash cmds • docker containers${NC}\n" "$(svc_dot happy-docker-bot.service)"
    printf "   ${GR}2${NC}  ${GR}ʟxᴄ ᴠᴘꜱ ʙᴏᴛ${NC}         %s  ${SL}prefix cmds • lxc • economy${NC}\n" "$(svc_dot happy-lxc-bot.service)"
    printf "   ${GR}3${NC}  ${GR}ꜱᴠᴍ ᴠ9 ʟxᴄ ʙᴏᴛ${NC}      %s  ${SL}multi-node • ports • admins${NC}\n" "$(svc_dot happy-svm-bot.service)"
    printf "   ${GR}4${NC}  ${GR}ᴅᴏᴄᴋᴇʀ ꜱꜱʜx ʙᴏᴛ${NC}    %s  ${SL}docker • browser sshx link${NC}\n" "$(svc_dot happy-sshx-bot.service)"
    echo ""
    echo -e "  ${CY}────────────────────────────────────────────────────────────────${NC}"
    printf "  ${FR}[0]${NC} ${FR}ʙᴀᴄᴋ${NC}          ${SL}pick a bot number to install${NC}\n"
    echo -e "  ${CY}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${FC}❯${NC} ${FW}Select${NC} ${SL}(0-4):${NC} "
}

run_card() {
    local name="$1" script="$2"
    if [ -f "$script" ]; then
        section_enter "$name"
        bash "$script"
    else
        st ERR "Missing: $script"
        sleep 1
    fi
}

while true; do
    show_header
    show_menu
    read -r opt
    case $opt in
        1) run_card "Docker VPS Bot" "$DIR/docker.sh" ;;
        2) run_card "LXC VPS Bot" "$DIR/lxc.sh" ;;
        3) run_card "SVM V9 Bot" "$DIR/svm.sh" ;;
        4) run_card "Docker SSHX Bot" "$DIR/sshx.sh" ;;
        0) dots_load "Closing bots" 2; exit 0 ;;
        *) echo -e "  ${FR}✗${NC} ${FW}Invalid option${NC}"; sleep 0.7 ;;
    esac
done
