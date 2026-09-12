#!/usr/bin/env bash

# ============================================================
#  HAPPY-NODE  |  Universal VPS Control Panel  (v1.0)
# ============================================================

HN_BASE_URL="$(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 --decode)"

# ---------- Pre-check ----------
if ! command -v curl >/dev/null 2>&1; then
    echo "[FAIL] curl is required. Install it first."
    echo "  Debian/Ubuntu: apt install curl"
    echo "  CentOS/RHEL:   yum install curl"
    exit 1
fi

# ---------- Colors ----------
if [ -t 1 ]; then
    R='\033[1;38;5;196m'
    G='\033[1;38;5;82m'
    Y='\033[1;38;5;220m'
    C='\033[1;38;5;51m'
    P='\033[1;38;5;201m'
    V='\033[1;38;5;135m'
    W='\033[1;38;5;255m'
    DG='\033[0;38;5;244m'
    NC='\033[0m'
else
    R=''; G=''; Y=''; C=''; P=''; V=''; W=''; DG=''; NC=''
fi

hn_info()  { echo -e "${C}[INFO]${NC}  $*"; }
hn_ok()    { echo -e "${G}[ OK ]${NC}  $*"; }
hn_warn()  { echo -e "${Y}[WARN]${NC}  $*"; }
hn_err()   { echo -e "${R}[FAIL]${NC}  $*"; }
hn_line()  { echo -e "${DG}------------------------------------------------------------${NC}"; }
hn_pause() { echo ""; read -rp "$(echo -e "${DG}Press Enter to continue...${NC}")" _; }
hn_clear() { clear 2>/dev/null || printf '\033c'; }

# ---------- Platform detection ----------
ARCH="$(uname -m)"
case "$ARCH" in x86_64|amd64) ARCH_ALT="amd64" ;; aarch64|arm64) ARCH_ALT="arm64" ;; *) ARCH_ALT="$ARCH" ;; esac
OS_NAME="Linux"; OS_VER=""
[ -f /etc/os-release ] && . /etc/os-release && OS_NAME="${NAME:-Linux}" && OS_VER="${VERSION_ID:-}"
if command -v apt-get >/dev/null 2>&1; then PM="apt"; PM_INSTALL="apt-get install -y"
elif command -v apk >/dev/null 2>&1; then PM="apk"; PM_INSTALL="apk add"
elif command -v dnf >/dev/null 2>&1; then PM="dnf"; PM_INSTALL="dnf install -y"
elif command -v yum >/dev/null 2>&1; then PM="yum"; PM_INSTALL="yum install -y"
else PM="unknown"; PM_INSTALL=""; fi

# ---------- Live metrics ----------
hn_metrics() {
    HN_CPU="$(awk -F'[ ,]+' '/cpu / {u=$2+$4; t=$2+$3+$4+$5; if(t>0) printf "%.0f", u*100/t}' /proc/stat 2>/dev/null)"
    [ -z "$HN_CPU" ] && HN_CPU="??"
    HN_RAM="$(free -m 2>/dev/null | awk '/^Mem:/ {if($2>0) printf "%.0f", $3*100/$2}')"
    [ -z "$HN_RAM" ] && HN_RAM="??"
    HN_UPT="$(uptime 2>/dev/null | sed 's/.*up[[:space:]]*//; s/,[[:space:]]*[0-9]* user.*//')"
    [ -z "$HN_UPT" ] && HN_UPT="Unknown"
    HN_DISK="$(df -h / 2>/dev/null | awk 'NR==2 {print $5}')"
    [ -z "$HN_DISK" ] && HN_DISK="??"
}

# ---------- Banner ----------
hn_banner() {
    echo -e "${C}  ██╗  ██╗ █████╗ ██████╗ ██████╗ ██╗   ██╗      ███╗   ██╗ ██████╗ ██████╗ ███████╗${NC}"
    echo -e "${C}  ██║  ██║██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝      ████╗  ██║██╔═══██╗██╔══██╗██╔════╝${NC}"
    echo -e "${P}  ███████║███████║██████╔╝██████╔╝ ╚████╔╝ █████╗██╔██╗ ██║██║   ██║██║  ██║█████╗  ${NC}"
    echo -e "${P}  ██╔══██║██╔══██║██╔═══╝ ██╔═══╝   ╚██╔╝  ╚════╝██║╚██╗██║██║   ██║██║  ██║██╔══╝  ${NC}"
    echo -e "${Y}  ██║  ██║██║  ██║██║     ██║        ██║         ██║ ╚████║╚██████╔╝██████╔╝███████╗${NC}"
    echo -e "${Y}  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝        ╚═╝         ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝${NC}"
    echo -e "                         ${DG}HAPPY-NODE${NC}"
}

# ---------- Header ----------
hn_header() {
    hn_clear
    hn_metrics
    echo -e " ${V}┌─${NC} ${C}Uptime:${NC} ${W}${HN_UPT}${NC}  ${DG}|${NC} ${C}Disk:${NC} ${W}${HN_DISK}${NC}  ${DG}|${NC} ${C}CPU:${NC} ${W}${HN_CPU}%${NC} ${C}RAM:${NC} ${W}${HN_RAM}%${NC} ${V}─┐${NC}"
    hn_banner
    echo -e " ${DG}────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e " ${W}System:${NC} ${G}${OS_NAME} ${OS_VER}${NC}   ${W}Arch:${NC} ${G}${ARCH}${NC}   ${W}Package Manager:${NC} ${G}${PM}${NC}"
    echo -e " ${DG}────────────────────────────────────────────────────────────────────────────${NC}"
}

# ---------- Menu ----------
hn_menu() {
    hn_header
    echo -e " ${C}◆ DEPLOYMENT & SERVICES${NC}"
    echo -e "   ${G}[1]${NC} VPS Setup          ${G}[5]${NC} Themes"
    echo -e "   ${G}[2]${NC} Panel              ${G}[6]${NC} System"
    echo -e "   ${G}[3]${NC} Wings              ${G}[7]${NC} Container"
    echo -e "   ${G}[4]${NC} Toolbox            ${G}[8]${NC} Extras"
    echo ""
    echo -e " ${P}◆ MAINTENANCE & TOOLS${NC}"
    echo -e "   ${R}[0]${NC} Exit"
    echo -e " ${DG}────────────────────────────────────────────────────────────────────────────${NC}"
    echo -ne " ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-8):${NC} "
}

# ---------- Launch: download + run ----------
hn_launch() {
    local rel_path="$1"
    local label="$2"
    local tmp_f
    tmp_f="$(mktemp /tmp/hn_XXXXXX.sh)"

    local url_path="${rel_path// /%20}"
    local full_url="$HN_BASE_URL/$url_path"

    hn_info "Launching ${label}..."
    local http_code
    http_code=$(curl -w '%{http_code}' -fsSL "$full_url" -o "$tmp_f" 2>/dev/null)

    if [ "$http_code" = "200" ] && [ -s "$tmp_f" ]; then
        chmod +x "$tmp_f"
        bash "$tmp_f"
        rm -f "$tmp_f"
    else
        rm -f "$tmp_f"
        hn_err "Cannot load: $label (HTTP $http_code)"
        sleep 1.5
    fi
}

# ---------- Main ----------
hn_main() {
    while true; do
        hn_menu
        read -r opt
        case "$opt" in
            1) hn_launch "setup%20vm/menu.sh" "VPS Setup" ;;
            2) hn_launch "panel/1.sh" "Panel" ;;
            3) hn_launch "wings/run.sh" "Wings" ;;
            4) hn_launch "toolbox/run.sh" "Toolbox" ;;
            5) hn_launch "thame/run.sh" "Themes" ;;
            6) hn_launch "lib/sysmgr.sh" "System" ;;
            7) hn_launch "Extras/docker.sh" "Container" ;;
            8) hn_launch "Extras/run.sh" "Extras" ;;
            0|exit|quit)
                hn_clear
                echo -e "${P}${BOLD:-}Disconnected.${NC} Goodbye from ${C}HAPPY-NODE${NC}."
                exit 0 ;;
            *) hn_err "Invalid option. Try again."; sleep 0.8 ;;
        esac
    done
}

hn_main
