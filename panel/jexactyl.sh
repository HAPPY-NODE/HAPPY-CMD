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
    [ -d "/var/www/jexactyl" ] && status="${G}● INSTALLED${NC}"
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     J E X A C T Y L                          ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    Server Management Panel                   ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${W}Status:${NC}  $status"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

install_jex() {
    show_header
    st INFO "Initiating Jexactyl installation..."
    sleep 0.5
    if ! run_dl "Jexactyl installer" "https://raw.githubusercontent.com/WhiteDreamDev/Jexactyl-Installer/main/install.sh" /tmp/jexactyl_install.sh; then
        st ERR "Download failed."
    else
        bash /tmp/jexactyl_install.sh || st ERR "Install failed."
    fi
    st OK "Installation complete."
    pause
}

create_user() {
    show_header
    if [ ! -d /var/www/jexactyl ]; then
        st ERR "Panel not installed."
        pause; return
    fi
    cd /var/www/jexactyl || return
    st WAIT "Creating admin user..."
    php artisan p:user:make -n \
        --email=admin@example.com --username=admin \
        --password=admin --admin=1 \
        --name-first=Admin --name-last=User
    st OK "User created: admin / admin"
    pause
}

update_panel() {
    show_header
    if [ ! -d /var/www/jexactyl ]; then
        st ERR "Panel not installed."
        pause; return
    fi
    st WAIT "Updating..."
    cd /var/www/jexactyl || return
    php artisan down
    rm -rf /var/www/jexactyl/*
    run_dl "Jexactyl panel.tar.gz" "https://github.com/jexactyl/jexactyl/releases/latest/download/panel.tar.gz" panel.tar.gz || { st ERR "Download failed"; pause; return; }
    tar -xzf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    run_live "composer" env COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
    php artisan migrate --seed --force
    chown -R www-data:www-data /var/www/jexactyl/*
    php artisan up
    st OK "Updated."
    pause
}

uninstall_jex() {
    show_header
    echo -e "  ${R}⚠ Delete all panel data?${NC}"
    read -rp "  Proceed? (y/N): " conf
    [[ "$conf" =~ ^[Yy]$ ]] || { st INFO "Cancelled."; pause; return; }
    systemctl stop panel.service 2>/dev/null
    systemctl disable panel.service 2>/dev/null
    rm -rf /var/www/jexactyl
    mysql -u root -e "DROP DATABASE IF EXISTS jexactyl;" 2>/dev/null
    mysql -u root -e "DROP USER IF EXISTS 'jexactyl'@'127.0.0.1';" 2>/dev/null
    rm -f /etc/nginx/sites-{enabled,available}/panel.conf 2>/dev/null
    systemctl reload nginx 2>/dev/null
    st OK "Removed."
    pause
}

while true; do
    show_header
    echo -e "  ${C}◆ JEXACTYL MANAGEMENT${NC}"
    echo -e "     ${GR}[1]${NC} Install         ${DG}•${NC} Fresh Install"
    echo -e "     ${GR}[2]${NC} Users           ${DG}•${NC} Add Admin"
    echo -e "     ${GR}[3]${NC} Update          ${DG}•${NC} Latest Release"
    echo -e "     ${GR}[4]${NC} Uninstall       ${DG}•${NC} Remove Data"
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-4):${NC} "
    read -r choice
    case $choice in
        1) install_jex ;;
        2) create_user ;;
        3) update_panel ;;
        4) uninstall_jex ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
