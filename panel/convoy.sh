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
    [ -d "/var/www/convoy" ] && status="${G}● INSTALLED${NC}"
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     C O N V O Y                              ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    Docker-based Game Panel                   ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${W}Status:${NC}  $status"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

install_convoy() {
    show_header
    st INFO "Initiating Convoy installation (Docker)..."
    sleep 0.5
    if [ -d /var/www/convoy ]; then
        st ERR "Already installed at /var/www/convoy"
        pause; return
    fi
    st WAIT "Installing Docker..."
    if ! command -v docker >/dev/null 2>&1; then
        run_live "docker-install" bash -c 'curl -fsSL https://get.docker.com/ | CHANNEL=stable sh' || { st ERR "Docker install failed."; pause; return; }
        systemctl enable --now docker 2>/dev/null || true
    fi
    echo ""
    st WAIT "Downloading Convoy (latest)..."
    mkdir -p /var/www/convoy
    cd /var/www/convoy || { st ERR "mkdir failed"; pause; return; }
    run_dl "Convoy panel.tar.gz" "https://github.com/convoypanel/panel/releases/latest/download/panel.tar.gz" panel.tar.gz || { st ERR "Download failed"; pause; return; }
    tar -xzf panel.tar.gz || { st ERR "Extract failed."; pause; return; }
    rm -f panel.tar.gz
    chmod -R o+w storage/* bootstrap/cache/
    # .env ke bina compose up boot hi nahi hota — example se banao
    [ -f .env ] || cp -f .env.example .env 2>/dev/null || true
    st WAIT "Starting containers..."
    run_live "docker-compose" docker compose up -d || { st ERR "docker compose up failed (check .env)"; pause; return; }
    echo ""
    st WAIT "Installing dependencies..."
    run_live "composer" docker compose exec -T workspace bash -c "composer install --no-dev --optimize-autoloader" || st ERR "composer install failed."
    st WAIT "Generating app key..."
    docker compose exec -T workspace bash -c "php artisan key:generate --force && php artisan optimize" || st ERR "key:generate failed."
    st WAIT "Migrating database..."
    docker compose exec -T workspace php artisan migrate --force || st ERR "migrate failed."
    echo ""
    st OK "Convoy installed."
    echo -e "  ${SL}Next:${NC} check ${W}/var/www/convoy/.env${NC} ${SL}if needed, then${NC} docker compose up -d"
    pause
}

update_panel() {
    show_header
    if [ ! -d /var/www/convoy ]; then
        st ERR "Panel not installed."
        pause; return
    fi
    st WAIT "Updating..."
    cd /var/www/convoy || return
    docker compose exec -T workspace php artisan down 2>/dev/null
    run_dl "Convoy panel.tar.gz" "https://github.com/convoypanel/panel/releases/latest/download/panel.tar.gz" panel.tar.gz || { st ERR "Download failed"; pause; return; }
    tar -xzf panel.tar.gz || { st ERR "Extract failed."; pause; return; }
    rm -f panel.tar.gz
    chmod -R o+w storage/* bootstrap/cache/
    run_live "composer" docker compose exec -T workspace bash -c "composer install --no-dev --optimize-autoloader"
    docker compose exec -T workspace php artisan migrate --force
    docker compose exec -T workspace php artisan up
    st OK "Updated."
    pause
}

uninstall_convoy() {
    show_header
    echo -e "  ${R}⚠ Delete all panel data?${NC}"
    read -rp "  Proceed? (y/N): " conf
    [[ "$conf" =~ ^[Yy]$ ]] || { st INFO "Cancelled."; pause; return; }
    cd /var/www/convoy 2>/dev/null && docker compose down -v 2>/dev/null
    rm -rf /var/www/convoy
    mysql -u root -e "DROP DATABASE IF EXISTS convoy;" 2>/dev/null
    mysql -u root -e "DROP USER IF EXISTS 'convoy_user'@'127.0.0.1';" 2>/dev/null
    st OK "Removed."
    pause
}

while true; do
    show_header
    echo -e "  ${C}◆ CONVOY MANAGEMENT${NC}"
    echo -e "     ${GR}[1]${NC} Install         ${DG}•${NC} Fresh Install (Docker)"
    echo -e "     ${GR}[2]${NC} Update          ${DG}•${NC} Latest Release"
    echo -e "     ${GR}[3]${NC} Uninstall       ${DG}•${NC} Remove Data"
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-3):${NC} "
    read -r choice || exit 0
    case $choice in
        1) install_convoy ;;
        2) update_panel ;;
        3) uninstall_convoy ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
