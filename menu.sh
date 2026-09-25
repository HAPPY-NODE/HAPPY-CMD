#!/bin/bash
# ---------- HAPPY-CMD entry: local clone OR straight stream from GitHub ----------
# Kuch bhi download/save nahi hota — har script GitHub se stream hoti hai.
HN_BASE_URL="${HN_BASE_URL:-https://raw.githubusercontent.com/HAPPY-NODE/HAPPY-CMD/main}"

_src="${BASH_SOURCE[0]:-$0}"
if [ -f "$_src" ]; then
    DIR="$(cd "$(dirname "$_src")" 2>/dev/null && pwd)"
else
    DIR=""
fi

if [ -n "$DIR" ] && [ -f "$DIR/colors.sh" ]; then
    # local clone mode
    HN_ROOT="$DIR"
    source "$DIR/colors.sh"
    source "$DIR/banner.sh"
else
    # streaming mode: bash <(curl ...) — temp file name nahi, pipe hai, kuch save nahi
    DIR=""
    source <(curl -fsSL --max-time 30 "$HN_BASE_URL/colors.sh")
    [ -n "${NC:-}" ] || { echo "x cannot reach GitHub for HAPPY-CMD"; exit 1; }
    source <(curl -fsSL --max-time 30 "$HN_BASE_URL/banner.sh")
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
        printf "\r   ${CB}%s${NC} ${CB}%s${NC}" "${frames[i]}" "$msg"
        i=$(( (i+1) % ${#frames[@]} ))
        sleep 0.1
    done
}

# ---------- Metrics ----------
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

get_width() { tput cols 2>/dev/null || echo 80; }

# ---------- Metric pill helper ----------
metric_pill() {
    local label="$1" value="$2"
    printf " ${CB}│${NC} ${SL}%s${NC} ${CB}%s${NC}" "$label" "$value"
}

# ---------- Header ----------
show_header() {
    clear
    get_metrics
    # status bar
    printf "  ${CB}┌─${NC}"
    printf " ${SL}UP${NC} ${CB}${HN_UPT}${NC}"
    metric_pill "DSK" "${HN_DISK}"
    metric_pill "CPU" "${HN_CPU}%"
    metric_pill "RAM" "${HN_RAM}%"
    printf " ${CB}─┐${NC}\n"
    banner
    echo -e "  ${CB}────────────────────────────────────────────────────────────────${NC}"
    printf "  ${SL}sys${NC}  ${CB}$(uname -s) ${SL}$(uname -r)${NC}   ${SL}arch${NC} ${GR}$(uname -m)${NC}   ${SL}sh${NC} ${FY}bash${NC}   ${SL}ver${NC} ${M}1.0.0${NC}\n"
    echo -e "  ${CB}────────────────────────────────────────────────────────────────${NC}"
}

# ---------- Menu cell (padded column, own color) ----------
# 8 distinct glow colors (256-palette, no aliases)
M1=$'\033[1;96m'   # cyan
M2=$'\033[38;5;141m'  # light purple
M3=$'\033[1;93m'   # yellow
M4=$'\033[38;5;43m'   # teal
M5=$'\033[38;5;201m'  # pink
M6=$'\033[1;92m'   # green
M7=$'\033[38;5;208m'  # orange
M8=$'\033[38;5;75m'   # soft blue

mk_cell() {
    local n=$1 label=$2 color=$3 cw=${4:-26}
    local plain="[$n] $label"
    local pad=$(( cw - ${#plain} ))
    [ "$pad" -lt 1 ] && pad=1
    printf "%s[%s]%s %s%s%*s%s" "${FW}" "$n" "${NC}" "$color" "$label" "$pad" "" "${NC}"
}

# ---------- Menu ----------
show_menu() {
    local width=$(get_width)
    echo ""
    echo -e "  ${FC}◆${NC} ${FW}TOOLS${NC} ${SL}· pick a module${NC}"
    echo ""
    if [ "$width" -ge 86 ]; then
        echo -e "     $(mk_cell 1 'VPS Setup' "$M1")$(mk_cell 2 'Panel Manager' "$M2")$(mk_cell 3 'Wings Manager' "$M3")"
        echo -e "     $(mk_cell 4 'Toolbox' "$M4")$(mk_cell 5 'Themes' "$M5")$(mk_cell 6 'Discord VPS Bot' "$M6")"
        echo -e "     $(mk_cell 7 'Backup' "$M7")$(mk_cell 8 'Utilities' "$M8")"
    elif [ "$width" -ge 66 ]; then
        echo -e "     $(mk_cell 1 'VPS Setup' "$M1" 30)$(mk_cell 2 'Panel Manager' "$M2" 30)"
        echo -e "     $(mk_cell 3 'Wings Manager' "$M3" 30)$(mk_cell 4 'Toolbox' "$M4" 30)"
        echo -e "     $(mk_cell 5 'Themes' "$M5" 30)$(mk_cell 6 'Discord VPS Bot' "$M6" 30)"
        echo -e "     $(mk_cell 7 'Backup' "$M7" 30)$(mk_cell 8 'Utilities' "$M8" 30)"
    else
        echo -e "     ${FW}[1]${NC} ${M1}VPS Setup${NC}"
        echo -e "     ${FW}[2]${NC} ${M2}Panel Manager${NC}"
        echo -e "     ${FW}[3]${NC} ${M3}Wings Manager${NC}"
        echo -e "     ${FW}[4]${NC} ${M4}Toolbox${NC}"
        echo -e "     ${FW}[5]${NC} ${M5}Themes${NC}"
        echo -e "     ${FW}[6]${NC} ${M6}Discord VPS Bot${NC}"
        echo -e "     ${FW}[7]${NC} ${M7}Backup${NC}"
        echo -e "     ${FW}[8]${NC} ${M8}Utilities${NC}"
    fi
    echo ""
    echo -e "     ${FW}[0]${NC} ${FR}Exit${NC}"
    echo ""
    echo -e "  ${GY}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${FC}❯${NC} ${FW}Enter Option${NC} ${SL}(0-8):${NC} "
}

# ---------- Section transition ----------
section_enter() {
    local name="$1"
    clear
    spinner "Loading $name" &
    local spid=$!
    sleep 0.7
    kill $spid 2>/dev/null
    wait $spid 2>/dev/null
    printf "\r\033[K"
    echo -e "  ${FG}✓${NC} ${CB}$name${NC} ${SL}loaded${NC}"
    sleep 0.25
    clear
}

# ---------- Handle ----------
handle_choice() {
    case "$1" in
        1) section_enter "VPS Setup"; hn_run "vps-setup/vps.sh" ;;
        2) section_enter "Panel Manager"; hn_run "panel/panel.sh" ;;
        3) section_enter "Wings Manager"; hn_run "wings/wings.sh" ;;
        4) section_enter "Toolbox"; hn_run "toolbox/toolbox.sh" ;;
        5) section_enter "Themes"; hn_run "themes/themes.sh" ;;
        6) section_enter "Discord VPS Bot"; hn_run "bots/bots.sh" ;;
        7) section_enter "Backup"; echo "   ${TE}Backup${NC} ${SL}- coming soon${NC}"; sleep 1 ;;
        8) section_enter "Utilities"; echo "   ${FB}Utilities${NC} ${SL}- coming soon${NC}"; sleep 1 ;;
        0)
            clear
            dots_load "Disconnecting" 3
            echo ""
            echo -e "  ${VI}Disconnected.${NC} ${SL}Goodbye from${NC} ${FC}HAPPY-CMD${NC}${SL}.${NC}"
            echo ""
            sleep 0.5
            exit 0
            ;;
        *) echo -e "  ${FR}✗${NC} ${FW}Invalid option${NC}"; sleep 0.8 ;;
    esac
}

# ---------- Boot Splash ----------
boot_splash() {
    [ -n "$HN_NO_SPLASH" ] && return 0
    clear

    local i ch
    # 1. soft glow line
    printf "  ${CB}"
    for ((i=0; i<56; i++)); do printf "─"; done
    printf "${NC}\n"
    sleep 0.1

    # 2. HAPPY NODE typing with per-letter color
    printf "  "
    local brand="HAPPY-NODE"
    local cols=(${FC} ${VI} ${TE} ${FC} ${VI})
    for ((i=0; i<${#brand}; i++)); do
        ch="${brand:i:1}"
        if [ "$ch" = "-" ]; then
            printf "${SL}-%s${NC}"
        else
            printf "${cols[i%5]}%s${NC}" "$ch"
        fi
        sleep 0.05
    done
    printf "  ${SL}•${NC} ${FW}terminal toolkit${NC}\n"
    sleep 0.12

    # 3. wave dots
    local wave=('·' '○' '●' '○' '·' ' ')
    bar=""
    for ((i=0; i<30; i++)); do
        bar+="${wave[i%6]}"
        printf "\r  ${VI}%s${NC}" "$bar"
        sleep 0.025
    done
    printf "\r\033[K"

    # 4. slim progress with gradient color shift
    local pct filled cell line
    for ((pct=0; pct<=100; pct+=4)); do
        filled=$((pct * 32 / 100))
        line=""
        for ((i=0; i<32; i++)); do
            if [ $i -lt $filled ]; then line+="━"; else line+="─"; fi
        done
        # color shifts cyan → violet → teal as it fills
        local pc
        if [ $pct -lt 40 ]; then pc="${FC}"; elif [ $pct -lt 75 ]; then pc="${VI}"; else pc="${TE}"; fi
        printf "\r  ${SL}[${NC}%s${SL}]${NC} ${pc}%3d%%${NC}" "$line" "$pct"
        sleep 0.025
    done
    printf "\r\033[K"

    # 5. module checks
    local mods=("colors" "banner" "menu" "sections" "ready")
    for line in "${mods[@]}"; do
        printf "  ${GR}✓${NC} ${CB}%s${NC}\n" "$line"
        sleep 0.06
    done
    sleep 0.15
    clear
}

# ---------- Main ----------
boot_splash
while true; do
    show_header
    show_menu
    read -r choice || exit 0
    handle_choice "$choice"
done
