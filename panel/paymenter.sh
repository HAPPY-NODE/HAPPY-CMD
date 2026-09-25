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
    [ -d "/var/www/paymenter" ] && status="${G}● INSTALLED${NC}"
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     P A Y M E N T E R                        ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    Billing & Payment Panel                   ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${W}Status:${NC}  $status"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

install_pay() {
    show_header
    st INFO "Initiating Paymenter installation..."
    sleep 0.5
    if [ -d /var/www/paymenter ]; then
        st ERR "Already installed at /var/www/paymenter"
        pause; return
    fi
    st WAIT "Installing dependencies (PHP 8.3, MariaDB, nginx, redis)..."
    install_steps "Paymenter deps" software-properties-common curl apt-transport-https ca-certificates gnupg || true
    if command -v add-apt-repository >/dev/null 2>&1; then
        run_live "php-ppa" env LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php || true
    fi
    run_live "apt-update" apt-get update -y -q || true
    install_steps "Web stack" php8.3 php8.3-common php8.3-cli php8.3-gd php8.3-mysql php8.3-mbstring php8.3-bcmath php8.3-xml php8.3-fpm php8.3-curl php8.3-zip php8.3-intl php8.3-redis mariadb-server nginx tar unzip git redis-server || { st ERR "Dependency install failed."; pause; return; }
    echo ""
    st WAIT "Downloading Paymenter (latest)..."
    mkdir -p /var/www/paymenter
    cd /var/www/paymenter || { st ERR "mkdir failed"; pause; return; }
    run_dl "paymenter.tar.gz" "https://github.com/paymenter/paymenter/releases/latest/download/paymenter.tar.gz" /tmp/paymenter.tar.gz || { st ERR "Download failed"; pause; return; }
    tar -xzf /tmp/paymenter.tar.gz || { st ERR "Extract failed."; pause; return; }
    rm -f /tmp/paymenter.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    echo ""
    st WAIT "Creating database..."
    local DB_PASS="$(openssl rand -base64 12)"
    mysql -u root <<SQL
CREATE USER IF NOT EXISTS 'paymenter'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
CREATE DATABASE IF NOT EXISTS paymenter;
GRANT ALL PRIVILEGES ON paymenter.* TO 'paymenter'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
    if [ $? -ne 0 ]; then st ERR "Database creation failed."; pause; return; fi
    st WAIT "Configuring .env..."
    cp -f .env.example .env
    sed -i "s/^DB_DATABASE=.*/DB_DATABASE=paymenter/" .env
    sed -i "s/^DB_USERNAME=.*/DB_USERNAME=paymenter/" .env
    sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|" .env
    run_live "key:generate" php artisan key:generate --force
    php artisan storage:link 2>/dev/null
    st WAIT "Migrating database (this takes a while)..."
    run_live "migrate" php artisan migrate --force --seed || { st ERR "Migration failed."; pause; return; }
    php artisan db:seed --class=CustomPropertySeeder 2>/dev/null
    echo ""
    st WAIT "Setting up cron + queue service..."
    (crontab -l 2>/dev/null | grep -v 'paymenter/artisan schedule:run'; echo "* * * * * php /var/www/paymenter/artisan schedule:run >> /dev/null 2>&1") | crontab - 2>/dev/null
    cat > /etc/systemd/system/paymenter.service <<'EOF'
[Unit]
Description=Paymenter Queue Worker
[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/paymenter/artisan queue:work
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    run_live "systemd-enable" systemctl enable --now paymenter.service || true
    systemctl enable --now redis-server 2>/dev/null || true
    chown -R www-data:www-data /var/www/paymenter/*
    echo ""
    st OK "Paymenter installed."
    echo -e "  ${SL}Next:${NC} ${W}php artisan app:init${NC} ${SL}(URL + name)${NC} ${W}→${NC} ${W}php artisan app:user:create${NC} ${SL}(admin)${NC}"
    read -rp "  Run app:init now? (y/N): " conf
    if [[ "$conf" =~ ^[Yy]$ ]]; then php artisan app:init; fi
    pause
}

create_user() {
    show_header
    if [ ! -d /var/www/paymenter ]; then
        st ERR "Panel not installed."
        pause; return
    fi
    cd /var/www/paymenter || return
    st WAIT "Creating admin user..."
    local PASSWORD="$(openssl rand -base64 10)"
    local EMAIL="admin@example.com"
    php artisan tinker --execute="\App\Models\User::create(['first_name'=>'Admin','last_name'=>'User','email'=>'$EMAIL','password'=>bcrypt('$PASSWORD'),'role_id'=>1,'is_admin'=>1]);"
    st OK "Password: $PASSWORD"
    pause
}

update_panel() {
    show_header
    if [ ! -d /var/www/paymenter ]; then
        st ERR "Panel not installed."
        pause; return
    fi
    st WAIT "Updating..."
    cd /var/www/paymenter || return
    php artisan down
    run_dl "paymenter.tar.gz" "https://github.com/paymenter/paymenter/releases/latest/download/paymenter.tar.gz" /tmp/paymenter.tar.gz && tar -xzf /tmp/paymenter.tar.gz || { st ERR "Download failed"; pause; return; }
    chmod -R 755 storage/* bootstrap/cache/
    php artisan migrate --force --seed
    run_live "composer" env COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
    chown -R www-data:www-data /var/www/paymenter/*
    php artisan up
    st OK "Updated."
    pause
}

setup_domain() {
    show_header
    st INFO "Domain/SSL setup: nginx + Let's Encrypt"
    if [ ! -d /var/www/paymenter ]; then
        st ERR "Panel not installed."
        pause; return
    fi
    read -rp "  Panel domain (e.g. pay.yourdomain.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then st ERR "Domain required."; pause; return; fi
    st WAIT "Installing nginx + certbot..."
    install_steps "Web stack" nginx certbot python3-certbot-nginx || { st ERR "Install failed."; pause; return; }
    echo ""
    st WAIT "Writing nginx config..."
    local PHP_SOCK
    PHP_SOCK="$(ls /run/php/php*-fpm.sock 2>/dev/null | head -1)"
    [ -z "$PHP_SOCK" ] && PHP_SOCK="/run/php/php8.3-fpm.sock"
    cat > /etc/nginx/sites-available/paymenter.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/paymenter/public;
    index index.php;
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \.php\$ {
        fastcgi_pass unix:$PHP_SOCK;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/paymenter.conf /etc/nginx/sites-enabled/paymenter.conf
    nginx -t 2>/dev/null && run_live "nginx-reload" systemctl reload nginx || { st ERR "nginx config test failed."; pause; return; }
    echo ""
    st WAIT "Requesting SSL certificate..."
    run_live "certbot" certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email || st ERR "Certbot failed (DNS not pointing?)."
    echo ""
    st OK "Domain ready: https://$DOMAIN"
    pause
}

uninstall_pay() {
    show_header
    echo -e "  ${R}⚠ Delete all panel data?${NC}"
    read -rp "  Proceed? (y/N): " conf
    [[ "$conf" =~ ^[Yy]$ ]] || { st INFO "Cancelled."; pause; return; }
    systemctl stop paymenter.service 2>/dev/null
    systemctl disable paymenter.service 2>/dev/null
    rm -rf /var/www/paymenter
    mysql -u root -e "DROP DATABASE IF EXISTS paymenter;" 2>/dev/null
    mysql -u root -e "DROP USER IF EXISTS 'paymenter'@'127.0.0.1';" 2>/dev/null
    rm -f /etc/nginx/sites-{enabled,available}/paymenter.conf 2>/dev/null
    systemctl reload nginx 2>/dev/null
    st OK "Removed."
    pause
}

while true; do
    show_header
    echo -e "  ${C}◆ PAYMENTER MANAGEMENT${NC}"
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
        1) install_pay ;;
        2) create_user ;;
        3) update_panel ;;
        4) setup_domain ;;
        5) uninstall_pay ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
