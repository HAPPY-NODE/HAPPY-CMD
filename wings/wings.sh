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

detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$PRETTY_NAME
    else
        OS_NAME=$(uname -s)
    fi
    PUBLIC_IP=$(curl -s --max-time 2 https://ipinfo.io/ip 2>/dev/null || echo "Unknown")
    LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$LOCAL_IP" ] && LOCAL_IP="N/A"
    if command -v free >/dev/null 2>&1; then
        RAM_USED=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
    else
        RAM_USED="N/A"
    fi
}

wings_status() {
    if systemctl is-active --quiet wings 2>/dev/null; then
        echo "${G}● ACTIVE${NC}"
    elif [ -f /usr/local/bin/wings ]; then
        echo "${Y}● INSTALLED${NC}"
    else
        echo "${R}● NOT INSTALLED${NC}"
    fi
}

show_header() {
    clear
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${CB}     ᴡɪɴɢꜱ ᴍᴀɴᴀɢᴇʀ                           ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    HAPPY NODE • ꜱᴇʀᴠᴇʀ ᴀᴜᴛᴏᴍᴀᴛɪᴏɴ            ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${SL}status${NC}  $(wings_status)"
    echo -e "  ${GY}────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${SL}os${NC} ${W}${OS_NAME:0:28}${NC}  ${GY}│${NC}  ${SL}wan${NC} ${W}${PUBLIC_IP}${NC}  ${GY}│${NC}  ${SL}lan${NC} ${W}${LOCAL_IP}${NC}  ${GY}│${NC}  ${SL}ram${NC} ${W}${RAM_USED}${NC}"
    echo -e "  ${GY}────────────────────────────────────────────────────────────────${NC}"
}

ssl_setup() {
    show_header
    st INFO "SSL Configuration (Certbot/Nginx)"
    echo -e "  ${DG}Auto-detected IP:${NC} ${G}$PUBLIC_IP${NC}"
    read -rp "  Enter Domain (e.g. node.host.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        st ERR "Setup aborted."
        pause; return
    fi
    st WAIT "Installing dependencies..."
    run_live "apt-update" apt-get update -y -q || true
    run_live "certbot" env DEBIAN_FRONTEND=noninteractive apt-get install -y certbot python3-certbot-nginx || {
        st ERR "Certbot install failed"; pause; return
    }
    st WAIT "Requesting certificate for $DOMAIN..."
    rm -rf "/etc/letsencrypt/live/$DOMAIN" "/etc/letsencrypt/archive/$DOMAIN" "/etc/letsencrypt/renewal/$DOMAIN.conf"
    certbot certonly --nginx -d "$DOMAIN" --non-interactive --agree-tos \
        --email "ssl$(tr -dc a-z0-9 </dev/urandom | head -c6)@$DOMAIN" || st WARN "Certbot may need nginx running"
    st OK "SSL setup complete"
    pause
}

uninstall_wings() {
    show_header
    echo -e "  ${R}⚠ DANGER ZONE: UNINSTALL${NC}"
    echo -e "  ${W}This will remove Wings, Docker, and configs.${NC}"
    echo -e "  ${W}Panel files remain safe.${NC}"
    read -rp "  Proceed? (y/N): " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || { st INFO "Cancelled."; pause; return; }
    st WAIT "Stopping Wings..."
    systemctl disable --now wings 2>/dev/null
    rm -f /etc/systemd/system/wings.service
    rm -rf /etc/pterodactyl /var/lib/pterodactyl /usr/local/bin/wings /usr/local/bin/wing
    systemctl daemon-reload 2>/dev/null
    st WAIT "Pruning Docker..."
    docker system prune -a -f 2>/dev/null || true
    read -rp "  Delete Database? (y/N): " DEL_DB
    if [[ "$DEL_DB" =~ ^[Yy]$ ]]; then
        read -rp "  DB Name: " DBN
        read -rp "  DB User: " DBU
        mysql -e "DROP DATABASE IF EXISTS $DBN; DROP USER IF EXISTS '$DBU'@'127.0.0.1';" 2>/dev/null
        st OK "Database cleared"
    fi
    st OK "Uninstallation finished"
    pause
}

echo -e "  ${C}→${NC} Detecting system info..."
detect_system

while true; do
    show_header
    echo -e "  ${FC}◆ ᴡɪɴɢꜱ ᴍᴏᴅᴜʟᴇꜱ${NC}"
    echo -e "     ${GR}[1]${NC} ${GR}ꜱꜱʟ ꜱᴇᴛᴜᴘ${NC}          ${DG}•${NC} Certbot / Nginx"
    echo -e "     ${GR}[2]${NC} ${GR}ɪɴꜱᴛᴀʟʟ ᴡɪɴɢꜱ${NC}      ${DG}•${NC} Docker + Daemon"
    echo -e "     ${GR}[3]${NC} ${GR}ᴡɪɴɢꜱ ᴍᴀɴᴀɢᴇʀ${NC}      ${DG}•${NC} Start / Logs / Nodes"
    echo -e "     ${GR}[4]${NC} ${GR}ᴅᴀᴛᴀʙᴀꜱᴇ ᴍᴀɴᴀɢᴇʀ${NC}   ${DG}•${NC} MySQL / MariaDB"
    echo -e "     ${GR}[5]${NC} ${GR}ᴜɴɪɴꜱᴛᴀʟʟ${NC}          ${DG}•${NC} Remove Wings"
    echo -e "     ${FR}[0]${NC} ${FR}ʙᴀᴄᴋ${NC}"
    echo -e "  ${GY}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${FC}➜${NC} ${FW}Enter Option${NC} ${SL}(0-5):${NC} "
    read -r opt
    case $opt in
        1) ssl_setup ;;
        2)
            st WAIT "Launching Wings installer..."
            hn_run "wings/install.sh"
            pause
            ;;
        3) hn_run "wings/manager.sh" ;;
        4) hn_run "wings/db.sh"; pause ;;
        5) uninstall_wings ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
