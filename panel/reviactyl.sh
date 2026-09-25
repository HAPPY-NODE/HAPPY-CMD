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
    [ -d "/var/www/reviactyl" ] && status="${G}● INSTALLED${NC}"
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     R E V I A C T Y L                        ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    Server Management Panel                   ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${W}Status:${NC}  $status"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

install_revi() {
    show_header
    st INFO "Initiating Reviactyl installation..."
    sleep 0.5
    if ! run_dl "Reviactyl installer" "https://raw.githubusercontent.com/reviactyl/installer/main/reviactyl.sh" /tmp/reviactyl_install.sh; then
        st ERR "Download failed."
        pause; return
    fi
    if bash /tmp/reviactyl_install.sh; then
        st OK "Installation complete."
    else
        st ERR "Install failed."
    fi
    pause
}

create_user() {
    show_header
    if [ ! -d /var/www/reviactyl ]; then
        st ERR "Panel not installed."
        pause; return
    fi
    cd /var/www/reviactyl || return
    st WAIT "Creating admin user..."
    local USERNAME="user$(openssl rand -hex 2)"
    local PASSWORD="$(openssl rand -base64 10)"
    php artisan p:user:make -n \
        --email="admin@example.com" --username="$USERNAME" \
        --password="$PASSWORD" --admin=1 \
        --name-first=Admin --name-last=User
    st OK "User: $USERNAME / $PASSWORD"
    pause
}

update_panel() {
    show_header
    if [ ! -d /var/www/reviactyl ]; then
        st ERR "Panel not installed."
        pause; return
    fi
    st WAIT "Updating..."
    cd /var/www/reviactyl || return
    php artisan down
    run_dl "Reviactyl panel.tar.gz" "https://github.com/reviactyl/panel/releases/latest/download/panel.tar.gz" /tmp/reviactyl_panel.tar.gz || { st ERR "Download failed — panel NOT wiped"; php artisan up; pause; return; }
    rm -rf /var/www/reviactyl/*
    tar -xzf /tmp/reviactyl_panel.tar.gz || { st ERR "Extract failed."; php artisan up; pause; return; }
    rm -f /tmp/reviactyl_panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/ 2>/dev/null || true
    local ok=1
    run_live "composer" env COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader || ok=0
    php artisan migrate --seed --force || ok=0
    chown -R www-data:www-data /var/www/reviactyl/* 2>/dev/null || true
    php artisan up
    if [ "$ok" = 1 ]; then st OK "Updated."; else st ERR "Update finished with errors (see above)."; fi
    pause
}

setup_domain() {
    show_header
    st INFO "Domain/SSL setup: nginx + Let's Encrypt"
    if [ ! -d /var/www/reviactyl ]; then
        st ERR "Panel not installed."
        pause; return
    fi
    read -rp "  Panel domain (e.g. revi.yourdomain.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then st ERR "Domain required."; pause; return; fi
    st WAIT "Installing nginx + certbot..."
    install_steps "Web stack" nginx certbot python3-certbot-nginx || { st ERR "Install failed."; pause; return; }
    echo ""
    st WAIT "Writing nginx config..."
    local PHP_SOCK
    PHP_SOCK="$(ls /run/php/php*-fpm.sock 2>/dev/null | head -1)"
    [ -z "$PHP_SOCK" ] && PHP_SOCK="/run/php/php8.3-fpm.sock"
    cat > /etc/nginx/sites-available/reviactyl.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/reviactyl/public;
    index index.php;
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \.php\$ {
        fastcgi_pass unix:$PHP_SOCK;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
    location ~ /\.well-known { allow all; }
}
EOF
    ln -sf /etc/nginx/sites-available/reviactyl.conf /etc/nginx/sites-enabled/reviactyl.conf
    nginx -t 2>/dev/null && run_live "nginx-reload" systemctl reload nginx || { st ERR "nginx config test failed."; pause; return; }
    echo ""
    st WAIT "Requesting SSL certificate..."
    run_live "certbot" certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email || st ERR "Certbot failed (DNS not pointing?)."
    echo ""
    st OK "Domain ready: https://$DOMAIN"
    pause
}

uninstall_revi() {
    show_header
    echo -e "  ${R}⚠ Delete all panel data?${NC}"
    read -rp "  Proceed? (y/N): " conf
    [[ "$conf" =~ ^[Yy]$ ]] || { st INFO "Cancelled."; pause; return; }
    systemctl stop reviq.service 2>/dev/null
    systemctl disable reviq.service 2>/dev/null
    rm -rf /var/www/reviactyl
    mysql -u root -e "DROP DATABASE IF EXISTS reviactyl;" 2>/dev/null
    mysql -u root -e "DROP USER IF EXISTS 'reviactyl'@'127.0.0.1';" 2>/dev/null
    rm -f /etc/nginx/sites-{enabled,available}/reviactyl.conf 2>/dev/null
    systemctl reload nginx 2>/dev/null
    st OK "Removed."
    pause
}

while true; do
    show_header
    echo -e "  ${C}◆ REVIACTYL MANAGEMENT${NC}"
    echo -e "     ${GR}[1]${NC} Install         ${DG}•${NC} Fresh Install"
    echo -e "     ${GR}[2]${NC} Users           ${DG}•${NC} Add Admin"
    echo -e "     ${GR}[3]${NC} Update          ${DG}•${NC} Latest Release"
    echo -e "     ${GR}[4]${NC} Domain & SSL    ${DG}•${NC} SSL Setup"
    echo -e "     ${GR}[5]${NC} Uninstall       ${DG}•${NC} Remove Data"
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-5):${NC} "
    read -r choice || exit 0
    case $choice in
        1) install_revi ;;
        2) create_user ;;
        3) update_panel ;;
        4) setup_domain ;;
        5) uninstall_revi ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
