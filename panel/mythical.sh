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
    esac
}
pause() { echo ""; read -rp "  Press Enter to continue... " _; }

dots_load() {
    local msg="$1" n="${2:-3}"
    printf "   %s" "$msg"
    for ((i=0; i<n; i++)); do printf "."; sleep 0.3; done
    printf "\r\033[K"
}

show_header() {
    clear
    local status="${R}● NOT INSTALLED${NC}"
    [ -d "/var/www/mythicaldash" ] && status="${G}● INSTALLED${NC}"
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     M Y T H I C A L D A S H                  ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    Dashboard Manager  v3.2.3                 ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${W}Status:${NC}  $status"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

install_myth() {
    show_header
    st INFO "Initiating MythicalDash installation..."
    sleep 0.5
    if ! run_dl "MythicalDash installer" "https://raw.githubusercontent.com/MythicalLTD/MythicalDash/refs/heads/v3-remastered/installer/install.sh" /tmp/mythical_install.sh; then
        st ERR "Download failed."
    else
        st INFO "Official Docker installer — auto-installs Docker + panel"
        bash /tmp/mythical_install.sh || st ERR "Install failed."
        st INFO "After install: reboot, then 'mythicaldash pterodactyl configure'"
    fi
    st OK "Installation complete."
    pause
}

update_myth() {
    show_header
    if [ ! -d "/var/www/mythicaldash" ]; then
        st ERR "MythicalDash not installed."
        pause; return
    fi
    st WAIT "Updating to latest..."
    cd /var/www/mythicaldash || return
    run_dl "MythicalDash.zip" "https://github.com/MythicalLTD/MythicalDash/releases/download/3.2.3/MythicalDash.zip" MythicalDash.zip || { st ERR "Download failed"; pause; return; }
    run_live "unzip" unzip -o MythicalDash.zip -d /var/www/mythicaldash
    dos2unix arch.bash 2>/dev/null
    sudo bash arch.bash
    run_live "composer" composer install --no-dev --optimize-autoloader
    ./MythicalDash -migrate
    chown -R www-data:www-data /var/www/mythicaldash/*
    st OK "Updated to v3.2.3."
    pause
}

uninstall_myth() {
    show_header
    echo -e "  ${R}⚠ Delete all MythicalDash data?${NC}"
    read -rp "  Proceed? (y/N): " conf
    [[ "$conf" =~ ^[Yy]$ ]] || { st INFO "Cancelled."; pause; return; }
    st WAIT "Removing database..."
    mariadb -u root -p <<EOF 2>/dev/null
DROP DATABASE IF EXISTS mythicaldash;
DROP USER IF EXISTS 'mythicaldash'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF
    st WAIT "Removing files..."
    rm -rf /var/www/mythicaldash
    st WAIT "Cleaning cron..."
    sudo crontab -l 2>/dev/null | grep -v 'mythicaldash' | sudo crontab - 2>/dev/null
    st WAIT "Cleaning nginx..."
    rm -f /etc/nginx/sites-{available,enabled}/MythicalDash.conf 2>/dev/null
    systemctl restart nginx 2>/dev/null
    st OK "Removed."
    pause
}

while true; do
    show_header
    echo -e "  ${C}◆ MYTHICALDASH MANAGEMENT${NC}"
    echo -e "     ${GR}[1]${NC} Install         ${DG}•${NC} Fresh Install"
    echo -e "     ${GR}[2]${NC} Update          ${DG}•${NC} v3.2.3 Latest"
    echo -e "     ${GR}[3]${NC} Uninstall       ${DG}•${NC} Remove Data"
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-3):${NC} "
    read -r choice
    case $choice in
        1) install_myth ;;
        2) update_myth ;;
        3) uninstall_myth ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
