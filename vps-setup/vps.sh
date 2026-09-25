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

section_enter() {
    local name="$1"
    clear
    spinner "Loading $name" &
    local spid=$!
    sleep 0.7
    kill $spid 2>/dev/null
    wait $spid 2>/dev/null
    printf "\r\033[K"
    echo -e "  ${G}✓${NC} ${W}$name${NC} loaded"
    sleep 0.25
    clear
}

get_metrics() {
    HN_CPU="$(awk -F'[ ,]+' '/cpu / {u=$2+$4; t=$2+$3+$4+$5; if(t>0) printf "%.0f", u*100/t}' /proc/stat 2>/dev/null)"
    [ -z "$HN_CPU" ] && HN_CPU="??"
    HN_RAM="$(free -m 2>/dev/null | awk '/^Mem:/ {if($2>0) printf "%.0f", $3*100/$2}')"
    [ -z "$HN_RAM" ] && HN_RAM="??"
    HN_UPT="$(uptime 2>/dev/null | sed 's/.*up[[:space:]]*//; s/,[[:space:]]*[0-9]* user.*//')"
    [ -z "$HN_UPT" ] && HN_UPT="Unknown"
    HN_DISK="$(df -h / 2>/dev/null | awk 'NR==2 {print $5}')"
    [ -z "$HN_DISK" ] && HN_DISK="??"
}

# ---------- Menu ----------
show_vps_menu() {
    clear
    get_metrics
    echo -e "  ${V}┌─${NC} ${C}Uptime:${NC} ${W}${HN_UPT}${NC}  ${DG}│${NC} ${C}Disk:${NC} ${W}${HN_DISK}${NC}  ${DG}│${NC} ${C}CPU:${NC} ${W}${HN_CPU}%${NC}  ${DG}│${NC} ${C}RAM:${NC} ${W}${HN_RAM}%${NC}  ${V}─┐${NC}"
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${CB}       ᴠᴘꜱ ꜱᴇᴛᴜᴘ                              ${CB}│${NC}"
    echo -e "  ${CB}│${DG}      ᴠɪʀᴛᴜᴀʟ ᴍᴀᴄʜɪɴᴇ ᴍᴀɴᴀɢᴇʀ                 ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${FC}◆ ᴠɪʀᴛᴜᴀʟ ᴍᴀᴄʜɪɴᴇꜱ${NC}"
    echo -e "     ${GR}[1]${NC} ${GR}ᴋᴠᴍ ꜱᴇᴛᴜᴘ${NC}         ${DG}•${NC} Hardware Accelerated"
    echo -e "     ${GR}[2]${NC} ${GR}ɴᴏ ᴋᴠᴍ ꜱᴇᴛᴜᴘ${NC}      ${DG}•${NC} Software Emulation"
    echo -e "     ${GR}[3]${NC} ${GR}ᴘʀᴏᴏᴛ ꜱᴇᴛᴜᴘ${NC}       ${DG}•${NC} No-root Ubuntu/Debian"
    echo -e "     ${GR}[4]${NC} ${GR}ʟxᴄ ꜱᴇᴛᴜᴘ${NC}          ${DG}•${NC} Linux Containers"
    echo -e "     ${GR}[5]${NC} ${GR}ᴅᴏᴄᴋᴇʀ ꜱᴇᴛᴜᴘ${NC}       ${DG}•${NC} Docker Containers"
    echo -e "     ${GR}[6]${NC} ${GR}ɴꜱᴘᴀᴡɴ ꜱᴇᴛᴜᴘ${NC}       ${DG}•${NC} systemd-nspawn"
    echo -e "     ${FR}[0]${NC} ${FR}ʙᴀᴄᴋ${NC}"
    echo -e "  ${GY}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${FC}➜${NC} ${FW}Enter Option${NC} ${SL}(0-6):${NC} "
}

# ---------- Main ----------
while true; do
    show_vps_menu
    read -r opt
    case "$opt" in
        1)
            if [ -e /dev/kvm ] && [ -r /dev/kvm ]; then
                section_enter "KVM Setup"
                hn_run "vps-setup/vps-kvm.sh"
            else
                clear
                echo -e "  ${Y}⚠ KVM not available on this system${NC}"
                echo -e "  ${DG}Use No KVM Setup [2] instead${NC}"
                read -rp "  Press Enter to continue..." _
            fi
            ;;
        2) section_enter "No KVM Setup"; hn_run "vps-setup/vps-nokvm.sh" ;;
        3) section_enter "proot Setup"; hn_run "vps-setup/vps-proot.sh" ;;
        4) section_enter "LXC Setup"; hn_run "vps-setup/vps-lxc.sh" ;;
        5) section_enter "Docker Setup"; hn_run "vps-setup/vps-docker.sh" ;;
        6) section_enter "nspawn Setup"; hn_run "vps-setup/vps-nspawn.sh" ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
