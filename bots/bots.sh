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
    local unit="$1" s
    s=$(systemctl is-active "$unit" 2>/dev/null)
    case "$s" in
        active)      echo -e "${FG}●${NC}" ;;
        activating|reloading|deactivating) echo -e "${FY}●${NC}" ;;
        failed)      echo -e "${FR}●${NC}" ;;
        *)           if [ -f "/etc/systemd/system/$unit" ]; then echo -e "${FY}●${NC}"; else echo -e "${DG}●${NC}"; fi ;;
    esac
}

show_header() {
    clear
    echo ""
    printf "  ${CB}┌──────────────────────────────────────────────────────────┐${NC}\n"
    printf "  ${CB}│${NC}  ${M}◆${NC} ${FW}HAPPY NODE${NC} ${VI}ᴅɪꜱᴄᴏʀᴅ ᴠᴘꜱ ʙᴏᴛ${NC}                         ${CB}│${NC}\n"
    printf "  ${CB}│${NC}  ${TE}docker + lxc bot installers${NC}                          ${CB}│${NC}\n"
    printf "  ${CB}└──────────────────────────────────────────────────────────┘${NC}\n"
    echo ""
    printf "  ${SL}order${NC}  ${CB}token → admin id (baaki defaults)${NC}\n"
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
    printf "   ${GR}5${NC}  ${GR}sᴛᴀᴛᴜs & ᴅᴇʙᴜɢ${NC}      ${SL}live state + last errors${NC}\n"
    echo ""
    echo -e "  ${CY}────────────────────────────────────────────────────────────────${NC}"
    printf "  ${FR}[0]${NC} ${FR}ʙᴀᴄᴋ${NC}          ${SL}pick a bot number to install${NC}\n"
    echo -e "  ${CY}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${FC}❯${NC} ${FW}Select${NC} ${SL}(0-5):${NC} "
}

bot_status() {
    local u s first=1 has_sysd=1
    command -v systemctl >/dev/null 2>&1 || has_sysd=0
    for u in happy-docker-bot happy-lxc-bot happy-svm-bot happy-sshx-bot; do
        [ "$first" = 1 ] && echo "" && first=0
        if [ "$has_sysd" = 0 ]; then
            if [ -f "/etc/systemd/system/$u.service" ]; then
                echo -e "  ${FY}●${NC} ${W}$u${NC}  ${FY}unit written (no systemctl here)${NC}"
            else
                echo -e "  ${DG}●${NC} ${W}$u${NC}  ${DG}not installed${NC}"
            fi
            continue
        fi
        s=$(systemctl is-active "$u.service" 2>/dev/null)
        [ -z "$s" ] && s="unknown"
        case "$s" in
            active)          echo -e "  ${FG}●${NC} ${W}$u${NC}  ${FG}$s${NC}" ;;
            failed)          echo -e "  ${FR}●${NC} ${W}$u${NC}  ${FR}$s${NC}" ;;
            activating)      echo -e "  ${FY}●${NC} ${W}$u${NC}  ${FY}$s (crash-restarting?)${NC}" ;;
            *)               if [ -f "/etc/systemd/system/$u.service" ]; then
                                 echo -e "  ${FY}●${NC} ${W}$u${NC}  ${FY}$s${NC}"
                             else
                                 echo -e "  ${DG}●${NC} ${W}$u${NC}  ${DG}$s (not installed)${NC}"
                             fi ;;
        esac
        if [ "$s" = "failed" ] || [ "$s" = "activating" ]; then
            journalctl -u "$u.service" -n 8 --no-pager 2>/dev/null | sed 's/^/      /' | tail -6
            echo -e "      ${SL}fix: edit /root/happy-*/.env then systemctl restart $u${NC}"
        fi
    done
    echo ""
    echo -e "  ${SL}dots:${NC} ${FG}● active${NC} ${FY}● starting/stopped${NC} ${FR}● failed${NC} ${DG}● not installed${NC}"
}

run_card() {
    local name="$1" script="$2"
    section_enter "$name"
    hn_run "$script"
}

while true; do
    show_header
    show_menu
    read -r opt || exit 0
    case $opt in
        1) run_card "Docker VPS Bot" "bots/docker.sh" ;;
        2) run_card "LXC VPS Bot" "bots/lxc.sh" ;;
        3) run_card "SVM V9 Bot" "bots/svm.sh" ;;
        4) run_card "Docker SSHX Bot" "bots/sshx.sh" ;;
        5) section_enter "Bot Status"; bot_status; pause ;;
        0) dots_load "Closing bots" 2; exit 0 ;;
        *) echo -e "  ${FR}✗${NC} ${FW}Invalid option${NC}"; sleep 0.7 ;;
    esac
done
