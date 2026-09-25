#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
source "$ROOT/colors.sh"
HN_BASE_URL="https://raw.githubusercontent.com/HAPPY-NODE/HAPPY-CMD/main"

# ---------- Helpers ----------
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

# ---------- Header ----------
ptero_latest() {
    curl -s --max-time 5 "https://api.github.com/repos/pterodactyl/panel/releases/latest" 2>/dev/null | grep '"tag_name"' | cut -d'"' -f4
}

ptero_installed() {
    grep -oP '"version":\s*"\K[^"]+' /var/www/pterodactyl/config/app.php 2>/dev/null | head -1
}

show_header() {
    clear
    local status="${R}● NOT INSTALLED${NC}"
    [ -d "/var/www/pterodactyl" ] && status="${G}● INSTALLED${NC}"
    local inst lat
    inst="$(ptero_installed)"; lat="$(ptero_latest)"
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     P T E R O D A C T Y L                    ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    Server Management Panel                   ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${W}Status:${NC}  $status"
    if [ -n "$inst" ] || [ -n "$lat" ]; then
        echo -e "  ${W}Version:${NC} ${C}${inst:-—}${NC}  ${DG}│${NC}  ${W}Latest:${NC} ${G}${lat:-—}${NC}"
    fi
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

# ---------- Install ----------
install_ptero() {
    show_header
    st INFO "Initiating Pterodactyl installation..."
    st INFO "Official installer — choose 'Install the panel'"
    sleep 0.5
    if ! run_dl "Pterodactyl installer" "https://pterodactyl-installer.se" /tmp/ptero_install.sh; then
        st ERR "Download failed. Check network."
        pause; return
    fi
    bash /tmp/ptero_install.sh || st ERR "Install failed."
    st OK "Installation complete."
    pause
}

# ---------- Users ----------
create_user() {
    show_header
    if [ ! -d /var/www/pterodactyl ]; then
        st ERR "Panel not installed."
        st INFO "Install panel first [1]."
        pause; return
    fi
    echo -e "  ${GR}[1]${NC} Custom User Create"
    echo -e "  ${GR}[2]${NC} Auto Create Admin User"
    read -rp "  Choice: " choice
    cd /var/www/pterodactyl || return
    if [ "$choice" = "1" ]; then
        st WAIT "Launching manual user creation..."
        php artisan p:user:make
    elif [ "$choice" = "2" ]; then
        st WAIT "Creating auto admin user..."
        local USERNAME="user$(openssl rand -hex 2)"
        local PASSWORD="$(openssl rand -base64 10)"
        local EMAIL="$(openssl rand -base64 4)@email.com"
        php artisan p:user:make -n \
            --email="$EMAIL" --username="$USERNAME" \
            --password="$PASSWORD" --admin=1 \
            --name-first=Admin --name-last=User
        echo ""
        st OK "Auto User Created!"
        echo -e "  ${W}Username:${NC} $USERNAME"
        echo -e "  ${W}Password:${NC} $PASSWORD"
        echo -e "  ${W}Email:${NC}    $EMAIL"
    else
        st ERR "Invalid option."
    fi
    pause
}

# ---------- Update ----------
update_panel() {
    show_header
    if [ ! -d /var/www/pterodactyl ]; then
        st ERR "Panel not installed."
        pause; return
    fi
    st WAIT "Fetching latest version..."
    local ver latest
    latest=$(curl -s "https://api.github.com/repos/pterodactyl/panel/releases/latest" 2>/dev/null | grep '"tag_name"' | cut -d'"' -f4)
    ver="$latest"
    [ -z "$ver" ] && ver="latest"
    echo -e "  ${W}Latest release:${NC} ${C}${latest:-unknown}${NC}"
    read -rp "  Proceed? (y/N): " conf
    [[ "$conf" =~ ^[Yy]$ ]] || { st INFO "Cancelled."; pause; return; }
    cd /var/www/pterodactyl || return
    st WAIT "Maintenance mode..."
    php artisan down
    st WAIT "Downloading $ver..."
    local ptero_url
    if [ "$ver" = "latest" ]; then
        ptero_url="https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz"
    else
        ptero_url="https://github.com/pterodactyl/panel/releases/download/${ver}/panel.tar.gz"
    fi
    run_dl "Pterodactyl panel.tar.gz" "$ptero_url" panel.tar.gz || { st ERR "Download failed"; pause; return; }
    tar -xzf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    st WAIT "Updating dependencies..."
    run_live "composer" env COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
    st WAIT "Migrating..."
    php artisan migrate --seed --force
    chown -R www-data:www-data /var/www/pterodactyl/*
    php artisan queue:restart
    php artisan up
    st OK "Panel updated to $ver."
    pause
}

# ---------- SSL ----------
setup_ssl() {
    show_header
    st INFO "SSL/Domain setup: nginx + Let's Encrypt"
    if [ ! -d /var/www/pterodactyl ]; then
        st ERR "Panel not installed."
        pause; return
    fi
    read -rp "  Panel domain (e.g. panel.yourdomain.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        st ERR "Domain required."
        pause; return
    fi
    st WAIT "Installing nginx + certbot..."
    install_steps "Web stack" nginx certbot python3-certbot-nginx || { st ERR "Install failed."; pause; return; }
    echo ""
    st WAIT "Writing nginx config..."
    cat > /etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/pterodactyl/public;
    index index.html index.htm index.php;
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }
    location ~ /\.well-known {
        allow all;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    nginx -t 2>/dev/null && run_live "nginx-reload" systemctl reload nginx || { st ERR "nginx config test failed (check PHP version in config)."; pause; return; }
    echo ""
    st WAIT "Requesting SSL certificate..."
    run_live "certbot" certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email || st ERR "Certbot failed (DNS not pointing?)."
    echo ""
    st OK "Domain ready: https://$DOMAIN"
    pause
}

# ---------- phpMyAdmin ----------
install_phpmyadmin() {
    show_header
    st INFO "Installing phpMyAdmin..."
    if [ ! -d /var/www/pterodactyl ]; then
        st ERR "Panel not installed."
        pause; return
    fi
    st WAIT "Downloading phpMyAdmin..."
    local PMA_VER
    PMA_VER=$(curl -s "https://api.github.com/repos/phpmyadmin/phpmyadmin/releases/latest" 2>/dev/null | grep '"tag_name"' | cut -d'"' -f4)
    [ -z "$PMA_VER" ] && PMA_VER="latest"
    echo -e "  ${W}Version:${NC} $PMA_VER"
    cd /var/www || { st ERR "No /var/www"; pause; return; }
    run_dl "phpMyAdmin.tar.gz" "https://files.phpmyadmin.net/phpMyAdmin/${PMA_VER#phpMyAdmin-}/phpMyAdmin-${PMA_VER#phpMyAdmin-}-all-languages.tar.gz" pma.tar.gz || { st ERR "Download failed"; pause; return; }
    tar -xzf pma.tar.gz && rm -f pma.tar.gz
    rm -rf phpmyadmin
    mv "phpMyAdmin-${PMA_VER#phpMyAdmin-}-all-languages" phpmyadmin 2>/dev/null || mv phpMyAdmin-*-all-languages phpmyadmin 2>/dev/null
    chown -R www-data:www-data /var/www/phpmyadmin
    st OK "phpMyAdmin: /var/www/phpmyadmin (open via your panel domain /phpmyadmin)"
    pause
}

# ---------- Uninstall ----------
uninstall_ptero() {
    show_header
    echo -e "  ${R}⚠ WARNING: This will delete all panel data!${NC}"
    read -rp "  Proceed? (y/N): " conf
    [[ "$conf" =~ ^[Yy]$ ]] || { st INFO "Cancelled."; pause; return; }
    st WAIT "Stopping services..."
    systemctl stop pteroq.service 2>/dev/null
    systemctl disable pteroq.service 2>/dev/null
    rm -f /etc/systemd/system/pteroq.service
    systemctl daemon-reload
    st WAIT "Removing cronjobs..."
    crontab -l 2>/dev/null | grep -v 'php /var/www/pterodactyl/artisan schedule:run' | crontab - 2>/dev/null
    st WAIT "Deleting files..."
    rm -rf /var/www/pterodactyl
    st WAIT "Dropping database..."
    mysql -u root -e "DROP DATABASE IF EXISTS panel;" 2>/dev/null
    mysql -u root -e "DROP USER IF EXISTS 'pterodactyl'@'127.0.0.1';" 2>/dev/null
    mysql -u root -e "FLUSH PRIVILEGES;" 2>/dev/null
    st WAIT "Cleaning Nginx..."
    rm -f /etc/nginx/sites-{enabled,available}/pterodactyl.conf 2>/dev/null
    systemctl reload nginx 2>/dev/null
    st OK "Panel removed."
    pause
}

# ---------- Main Menu ----------
while true; do
    show_header
    echo -e "  ${C}◆ PANEL MANAGEMENT${NC}"
    echo -e "     ${GR}[1]${NC} Install         ${DG}•${NC} Fresh Install"
    echo -e "     ${GR}[2]${NC} Users           ${DG}•${NC} Add Admin / User"
    echo -e "     ${GR}[3]${NC} Update          ${DG}•${NC} Latest Release"
    echo -e "     ${GR}[4]${NC} Domain & SSL    ${DG}•${NC} SSL Setup"
    echo -e "     ${GR}[5]${NC} phpMyAdmin      ${DG}•${NC} Database Manager"
    echo -e "     ${GR}[6]${NC} Uninstall       ${DG}•${NC} Remove Data"
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-6):${NC} "
    read -r choice
    case $choice in
        1) install_ptero ;;
        2) create_user ;;
        3) update_panel ;;
        4) setup_ssl ;;
        5) install_phpmyadmin ;;
        6) uninstall_ptero ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
