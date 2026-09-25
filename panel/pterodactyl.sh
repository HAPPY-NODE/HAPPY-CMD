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

# NEON accent palette
NY=$'\033[38;5;214m'   # gold
NP=$'\033[38;5;141m'   # purple
NW=$'\033[38;5;255m'   # white
NL=$'\033[38;5;51m'    # neon cyan

# ---------- Helpers ----------
st() {
    case $1 in
        OK)   echo -e "  ${G}✓${NC} $2" ;;
        ERR)  echo -e "  ${R}✗${NC} $2" ;;
        INFO) echo -e "  ${C}→${NC} $2" ;;
        WAIT) echo -e "  ${Y}⏳${NC} $2" ;;
        WARN) echo -e "  ${NY}!${NC} $2" ;;
    esac
}
pause() { echo ""; read -rp "  Press Enter to continue... " _ || true; }

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
    echo -e "  ${NL}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${NL}│${NW}   H A P P Y - N O D E  ·  P T E R O         ${NL}│${NC}"
    echo -e "  ${NL}│${SL}    Server Management Panel                   ${NL}│${NC}"
    echo -e "  ${NL}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${W}Status:${NC}  $status"
    if [ -n "$inst" ] || [ -n "$lat" ]; then
        echo -e "  ${W}Version:${NC} ${C}${inst:-—}${NC}  ${DG}│${NC}  ${W}Latest:${NC} ${G}${lat:-—}${NC}"
    fi
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

# ---------- NEON input helpers ----------
neon_ask() {
    local label="$1" default="$2" var="$3" input
    echo -ne "  ${NP}•${NC} ${NW}${label}${NC} ${SL}[${default}]${NC}\n  ${SL}╰─>${NC} "
    read -r input || input=""
    [ -z "$input" ] && input="$default"
    printf -v "$var" '%s' "$input"
}

neon_ask_timeout() {
    local label="$1" default="$2" var="$3" input=""
    echo -ne "  ${NP}•${NC} ${NW}${label}${NC} ${SL}[${default}]${NC}\n  ${SL}╰─>${NC} "
    if ! read -t 10 -r input; then
        echo ""
        echo -e "  ${NY}⌛ Timeout — using default: ${NW}${default}${NC}"
        printf -v "$var" '%s' "$default"
        return
    fi
    [ -z "$input" ] && input="$default"
    printf -v "$var" '%s' "$input"
}

# ---------- Version fetch / select (GitHub releases) ----------
fetch_ptero_versions() {
    local json
    json=$(curl -sf --max-time 20 "https://api.github.com/repos/pterodactyl/panel/releases?per_page=20" 2>/dev/null) || return 1
    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$json" | python3 -c "
import sys, json
for r in json.load(sys.stdin):
    if r.get('prerelease'): continue
    t = r.get('tag_name', '')
    if t.startswith('v'): print(t)
" 2>/dev/null
    else
        printf '%s' "$json" | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4
    fi
}

# select_ptero_version VAR_NAME  -> sets VAR to chosen tag (or "latest")
select_ptero_version() {
    local var="$1"
    echo -e "\n  ${NP}::${NC} ${NW}Available Panel Versions${NC}"
    local tags=() i=0 t
    while IFS= read -r t; do
        [ -n "$t" ] && tags+=("$t")
    done < <(fetch_ptero_versions 2>/dev/null) || true
    if [ ${#tags[@]} -eq 0 ]; then
        echo -e "  ${NY}No versions found — using latest.${NC}"
        printf -v "$var" '%s' "latest"
        return
    fi
    for t in "${tags[@]}"; do
        i=$((i + 1))
        echo -e "  ${SL}$i.${NC} ${NW}$t${NC}"
    done
    local max=${#tags[@]} choice=""
    echo -ne "\n  ${NP}•${NC} ${NW}Select version [1-${max}]${NC} ${SL}[1 = latest]${NC}\n  ${SL}╰─>${NC} "
    if ! read -t 15 -r choice; then
        choice=""
        echo ""
        echo -e "  ${NY}⌛ Timeout — using latest: ${NW}${tags[0]}${NC}"
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$max" ]; then
        printf -v "$var" '%s' "${tags[choice-1]}"
    else
        printf -v "$var" '%s' "${tags[0]}"
    fi
    echo -e "  ${G}→ ${NW}${!var}${NC}"
}

# ---------- NEON intro banner (SEMA NEON style, HAPPY-NODE branded) ----------
ptero_neon_banner() {
    local width
    width=$(tput cols 2>/dev/null || echo 80)
    if [ "$width" -ge 96 ]; then
        echo -e "${NL}"
        cat << 'EOF'
               .                                      .o8                          .               oooo
             .o8                                     "888                        .o8               `888
oo.ooooo.  .o888oo  .ooooo.  oooo d8b  .ooooo.   .oooo888   .oooo.    .ooooo.  .o888oo oooo    ooo  888
 888' `88b   888   d88' `88b `888""8P d88' `88b d88' `888  `P  )88b  d88' `"Y8   888    `88.  .8'   888
 888   888   888   888ooo888  888     888   888 888   888   .oP"888  888         888     `88..8'    888
 888   888   888 . 888    .o  888     888   888 888   888  d8(  888  888   .o8   888 .    `888'     888
 888bod8P'   "888" `Y8bod8P' d888b    `Y8bod8P' `Y8bod88P" `Y888""8o `Y8bod8P'   "888"     .8'     o888o
 888                                                                                   .o..P'
o888o                                                                                  `Y8P'
EOF
        echo -e "${NC}"
    fi
    echo -e "           ${NW}HAPPY-NODE PREMIUM PTERODACTYL INSTALLER${NC}"
    echo -e "${SL}────────────────────────────────────────────────────────────${NC}"
}

# ---------- Install ----------
install_ptero() {
    show_header
    ptero_neon_banner

    if [ -d /var/www/pterodactyl ]; then
        st ERR "Panel already exists at /var/www/pterodactyl"
        st INFO "Use [3] Update, [2] Users, or [6] Uninstall first."
        pause; return
    fi

    neon_ask "Panel Domain" "panel.yourdomain.com" DOMAIN
    neon_ask "Admin Email" "admin@gmail.com" EMAIL
    neon_ask "Admin Username" "admin" USERNAME
    neon_ask_timeout "Admin Password" "admin" PASSWORD
    select_ptero_version version_PANEL

    echo -e "\n  ${NY}┌─[ REVIEW CONFIGURATION ]${NC}"
    echo -e "  ${NY}│${NC} ${SL}Domain:${NC}   $DOMAIN"
    echo -e "  ${NY}│${NC} ${SL}Email:${NC}    $EMAIL"
    echo -e "  ${NY}│${NC} ${SL}User:${NC}     $USERNAME"
    echo -e "  ${NY}│${NC} ${SL}Version:${NC}  $version_PANEL"
    echo -e "  ${NY}└───────────────────────────${NC}"

    local conf=""
    while true; do
        echo -ne "\n  ${NL}Start Installation?${NC} ${NW}(y/n)${NC}${SL}:${NC} "
        read -n 1 -r conf || { echo ""; st ERR "Aborted."; pause; return; }
        echo ""
        case $conf in
            [Yy]*) echo -e "  ${G}Proceeding to deployment...${NC}"; break ;;
            [Nn]*) st ERR "Installation aborted by user."; pause; return ;;
            *)     echo -e "  ${SL}Invalid input. Enter ${NW}y${NC}${SL} or ${NW}n${NC}${SL}.${NC}" ;;
        esac
    done

    local PHP_VERSION="8.3"
    local panel_dir="/var/www/pterodactyl"

    # ----- Base deps -----
    install_steps "Base packages" curl ca-certificates gnupg unzip git tar sudo lsb-release openssl \
        || { st ERR "Base package install failed."; pause; return; }

    # ----- PHP repo (Ubuntu PPA / Debian SURY) -----
    local OS
    OS=$(lsb_release -is 2>/dev/null | tr '[:upper:]' '[:lower:]')
    if [ "$OS" = "ubuntu" ]; then
        st WAIT "Adding PHP PPA (ondrej)..."
        run_live "software-properties" env DEBIAN_FRONTEND=noninteractive apt-get install -y -q software-properties-common || true
        run_live "php-ppa" env LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php || st WARN "PPA add failed (may already exist)"
    elif [ "$OS" = "debian" ]; then
        st WAIT "Adding SURY PHP repo..."
        run_live "sury-key" bash -c 'curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg' || true
        echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/sury-php.list 2>/dev/null || true
    fi

    # ----- Redis repo -----
    run_live "redis-key" bash -c 'curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg' || true
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" > /etc/apt/sources.list.d/redis.list 2>/dev/null || true

    # ----- PHP + services -----
    install_steps "PHP ${PHP_VERSION} + services" \
        "php${PHP_VERSION}" "php${PHP_VERSION}-cli" "php${PHP_VERSION}-fpm" "php${PHP_VERSION}-common" \
        "php${PHP_VERSION}-mysql" "php${PHP_VERSION}-mbstring" "php${PHP_VERSION}-bcmath" "php${PHP_VERSION}-xml" \
        "php${PHP_VERSION}-zip" "php${PHP_VERSION}-curl" "php${PHP_VERSION}-gd" "php${PHP_VERSION}-tokenizer" \
        mariadb-server nginx redis-server \
        || { st ERR "PHP/service install failed — check OS support."; pause; return; }

    # ----- Composer -----
    if ! command -v composer >/dev/null 2>&1; then
        st WAIT "Installing Composer..."
        run_dl "composer-setup.php" "https://getcomposer.org/installer" /tmp/composer-setup.php \
            && run_live "composer-bin" php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer \
            && rm -f /tmp/composer-setup.php || st WARN "Composer install had issues"
    fi

    # ----- Download selected panel version -----
    st WAIT "Preparing $panel_dir..."
    mkdir -p "$panel_dir" || { st ERR "Cannot create $panel_dir"; pause; return; }
    cd "$panel_dir" || { st ERR "cd failed"; pause; return; }
    local ptero_url
    if [ "$version_PANEL" = "latest" ]; then
        ptero_url="https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz"
    else
        ptero_url="https://github.com/pterodactyl/panel/releases/download/${version_PANEL}/panel.tar.gz"
    fi
    st WAIT "Downloading ${version_PANEL}..."
    run_dl "panel.tar.gz" "$ptero_url" panel.tar.gz || { st ERR "Download failed (bad version?)."; pause; return; }
    tar -xzf panel.tar.gz || { st ERR "Extract failed."; rm -f panel.tar.gz; pause; return; }
    rm -f panel.tar.gz
    [ -f artisan ] || { st ERR "Not a panel archive — aborting."; pause; return; }
    chmod -R 755 storage/* bootstrap/cache/ 2>/dev/null || true

    # ----- MariaDB -----
    local MYSQL_BIN DB_NAME=panel DB_USER=pterodactyl DB_PASS
    MYSQL_BIN="$(command -v mariadb || command -v mysql)"
    if [ -z "$MYSQL_BIN" ]; then
        st ERR "No mariadb/mysql client found."
        pause; return
    fi
    DB_PASS="$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)"
    st OK "Auto-generated DB password."
    "$MYSQL_BIN" -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';" 2>/dev/null \
        || "$MYSQL_BIN" -e "CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';" 2>/dev/null || true
    "$MYSQL_BIN" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};" 2>/dev/null \
        || "$MYSQL_BIN" -e "CREATE DATABASE ${DB_NAME};" 2>/dev/null || true
    "$MYSQL_BIN" -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;" || { st ERR "DB grant failed."; pause; return; }
    "$MYSQL_BIN" -e "FLUSH PRIVILEGES;" || true

    # ----- .env -----
    [ -f .env.example ] || run_dl ".env.example" "https://raw.githubusercontent.com/pterodactyl/panel/develop/.env.example" .env.example || true
    if [ -f .env.example ]; then cp -f .env.example .env; else touch .env; fi
    sed -i "s|APP_URL=.*|APP_URL=https://${DOMAIN}|" .env
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|" .env
    sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|" .env
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" .env
    grep -q "^QUEUE_CONNECTION=" .env && sed -i "s|QUEUE_CONNECTION=.*|QUEUE_CONNECTION=redis|" .env || echo "QUEUE_CONNECTION=redis" >> .env
    grep -q "^APP_ENVIRONMENT_ONLY=" .env && sed -i "s|APP_ENVIRONMENT_ONLY=.*|APP_ENVIRONMENT_ONLY=false|" .env || echo "APP_ENVIRONMENT_ONLY=false" >> .env

    # ----- App deps + key + migrations -----
    st WAIT "Installing PHP dependencies (composer)..."
    local ok=1
    run_live "composer" env COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader || ok=0
    run_live "app-key" php artisan key:generate --force || ok=0
    st WAIT "Running migrations..."
    run_live "migrate" php artisan migrate --seed --force || ok=0
    if [ "$ok" = 0 ]; then
        st ERR "Composer/migrations reported errors — check output above."
        st INFO "Continuing remaining steps (you can rerun via Update)..."
    fi

    # ----- Permissions + cron -----
    chown -R www-data:www-data "$panel_dir"/* 2>/dev/null || true
    install_steps "Cron" cron || st WARN "cron install skipped"
    systemctl enable --now cron 2>/dev/null || true
    crontab -l 2>/dev/null | grep -v "pterodactyl/artisan schedule:run" > /tmp/crontab.tmp 2>/dev/null
    echo "* * * * * php $panel_dir/artisan schedule:run >> /dev/null 2>&1" >> /tmp/crontab.tmp
    crontab /tmp/crontab.tmp 2>/dev/null && st OK "Cron scheduled"
    rm -f /tmp/crontab.tmp

    # ----- Self-signed cert + nginx -----
    st WAIT "Writing nginx config + self-signed cert..."
    mkdir -p /etc/certs/panel /etc/nginx/sites-available /etc/nginx/sites-enabled 2>/dev/null || true
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -subj "/C=NA/ST=NA/L=NA/O=HAPPY-NODE/CN=${DOMAIN}" \
        -keyout /etc/certs/panel/privkey.pem -out /etc/certs/panel/fullchain.pem >/dev/null 2>&1 || st WARN "Cert generation failed"
    local PHP_SOCK
    PHP_SOCK="$(ls /run/php/php*-fpm.sock 2>/dev/null | head -1)"
    [ -z "$PHP_SOCK" ] && PHP_SOCK="/run/php/php${PHP_VERSION}-fpm.sock"
    cat > /etc/nginx/sites-available/pterodactyl.conf << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    root ${panel_dir}/public;
    index index.php;

    ssl_certificate /etc/certs/panel/fullchain.pem;
    ssl_certificate_key /etc/certs/panel/privkey.pem;

    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:${PHP_SOCK};
        fastcgi_index index.php;
        include /etc/nginx/fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize=100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    if nginx -t 2>/dev/null; then
        run_live "nginx-restart" systemctl restart nginx || st WARN "nginx restart failed"
        st OK "nginx configured"
    else
        st WARN "nginx config test failed (check PHP-FPM sock: $PHP_SOCK)"
    fi

    # ----- Queue worker -----
    cat > /etc/systemd/system/pteroq.service << 'EOF'
[Unit]
Description=HAPPY-NODE Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable --now redis-server 2>/dev/null || true
    systemctl enable --now pteroq.service 2>/dev/null && st OK "Queue worker running" || st WARN "Queue worker enable failed"

    # ----- Panel settings -----
    cd "$panel_dir" || true
    grep -q "^APP_ENVIRONMENT_ONLY=" .env && sed -i "s|APP_ENVIRONMENT_ONLY=.*|APP_ENVIRONMENT_ONLY=false|" .env || echo "APP_ENVIRONMENT_ONLY=false" >> .env
    grep -q "^RECAPTCHA_ENABLED=" .env && sed -i "s|RECAPTCHA_ENABLED=.*|RECAPTCHA_ENABLED=false|" .env || echo "RECAPTCHA_ENABLED=false" >> .env
    grep -q "^APP_NAME=" .env && sed -i 's|APP_NAME=.*|APP_NAME="HAPPY-NODE"|' .env || echo 'APP_NAME="HAPPY-NODE"' >> .env
    local TIMEZONE
    TIMEZONE=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
    grep -q "^APP_TIMEZONE=" .env && sed -i "s|APP_TIMEZONE=.*|APP_TIMEZONE=${TIMEZONE}|" .env || echo "APP_TIMEZONE=${TIMEZONE}" >> .env
    grep -q "^MAIL_MAILER=" .env && sed -i "s|MAIL_MAILER=.*|MAIL_MAILER=log|" .env || echo "MAIL_MAILER=log" >> .env
    grep -q "^MAIL_FROM_ADDRESS=" .env && sed -i "s|MAIL_FROM_ADDRESS=.*|MAIL_FROM_ADDRESS=\"noreply@${DOMAIN}\"|" .env || echo "MAIL_FROM_ADDRESS=\"noreply@${DOMAIN}\"" >> .env
    grep -q "^MAIL_FROM_NAME=" .env && sed -i 's|MAIL_FROM_NAME=.*|MAIL_FROM_NAME="HAPPY-NODE"|' .env || echo 'MAIL_FROM_NAME="HAPPY-NODE"' >> .env
    st OK "Panel settings applied (APP_NAME=HAPPY-NODE, mail=log mode)"

    php artisan p:location:make --short=IN --long="India" >/dev/null 2>&1 || true
    run_live "view-clear" php artisan view:clear || true
    run_live "config-cache" php artisan config:cache || true
    chown -R www-data:www-data "$panel_dir"/* 2>/dev/null || true
    php artisan queue:restart >/dev/null 2>&1 || true

    # ----- Admin user (non-interactive flags — no survey prompt) -----
    st WAIT "Creating admin user..."
    if php artisan p:user:make -n --email="$EMAIL" --username="$USERNAME" --password="$PASSWORD" --admin=1 --name-first=HAPPY --name-last=NODE; then
        st OK "Admin user created"
    else
        st ERR "Admin user creation failed — run [2] Users after fixing errors"
    fi

    # ----- Report -----
    echo ""
    echo -e "${SL}────────────────────────────────────────────────────────────${NC}"
    echo -e "\n  ${NL}DEPLOYMENT COMPLETE — HAPPY-NODE${NC}"
    echo -e "  ${SL}Panel URL :${NC} ${NW}https://${DOMAIN}${NC}"
    echo -e "  ${SL}Version   :${NC} ${NW}${version_PANEL}${NC}"
    echo -e "  ${SL}Username  :${NC} ${NW}${USERNAME}${NC}"
    echo -e "  ${SL}Password  :${NC} ${NW}${PASSWORD}${NC}"
    echo -e "  ${SL}Email     :${NC} ${NW}${EMAIL}${NC}"
    echo -e "\n  ${NP}SSL: self-signed — upgrade via [4] Domain & SSL (Let's Encrypt)${NC}"
    echo -e "  ${NP}Powered by HAPPY-NODE${NC}"
    echo -e "${SL}────────────────────────────────────────────────────────────${NC}"
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
    read -rp "  Choice: " choice || choice=""
    cd /var/www/pterodactyl || return
    if [ "$choice" = "1" ]; then
        st WAIT "Launching manual user creation..."
        php artisan p:user:make
    elif [ "$choice" = "2" ]; then
        st WAIT "Creating auto admin user..."
        local USERNAME="user$(openssl rand -hex 2)"
        local PASSWORD="$(openssl rand -base64 10)"
        local EMAIL="$(openssl rand -base64 4)@email.com"
        if php artisan p:user:make -n \
            --email="$EMAIL" --username="$USERNAME" \
            --password="$PASSWORD" --admin=1 \
            --name-first=Admin --name-last=User; then
            echo ""
            st OK "Auto User Created!"
            echo -e "  ${W}Username:${NC} $USERNAME"
            echo -e "  ${W}Password:${NC} $PASSWORD"
            echo -e "  ${W}Email:${NC}    $EMAIL"
        else
            st ERR "User creation failed (check panel install)."
        fi
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
    local ver=""
    select_ptero_version ver
    echo -e "  ${W}Target version:${NC} ${C}${ver}${NC}"
    read -rp "  Proceed? (y/N): " conf || conf=""
    [[ "$conf" =~ ^[Yy]$ ]] || { st INFO "Cancelled."; pause; return; }
    cd /var/www/pterodactyl || return
    st WAIT "Maintenance mode..."
    php artisan down
    local ptero_url
    if [ "$ver" = "latest" ]; then
        ptero_url="https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz"
    else
        ptero_url="https://github.com/pterodactyl/panel/releases/download/${ver}/panel.tar.gz"
    fi
    st WAIT "Downloading $ver..."
    run_dl "Pterodactyl panel.tar.gz" "$ptero_url" panel.tar.gz || { st ERR "Download failed"; php artisan up; pause; return; }
    tar -xzf panel.tar.gz || { st ERR "Extract failed."; php artisan up; pause; return; }
    rm -f panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/ 2>/dev/null || true
    st WAIT "Updating dependencies..."
    local ok=1
    run_live "composer" env COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader || ok=0
    st WAIT "Migrating..."
    php artisan migrate --seed --force || ok=0
    chown -R www-data:www-data /var/www/pterodactyl/* 2>/dev/null || true
    php artisan queue:restart
    php artisan up
    if [ "$ok" = 1 ]; then st OK "Panel updated to $ver."; else st ERR "Update finished with errors (see above)."; fi
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
    read -rp "  Panel domain (e.g. panel.yourdomain.com): " DOMAIN || DOMAIN=""
    if [ -z "$DOMAIN" ]; then
        st ERR "Domain required."
        pause; return
    fi
    st WAIT "Installing nginx + certbot..."
    install_steps "Web stack" nginx certbot python3-certbot-nginx || { st ERR "Install failed."; pause; return; }
    echo ""
    st WAIT "Writing nginx config..."
    local PHP_SOCK
    PHP_SOCK="$(ls /run/php/php*-fpm.sock 2>/dev/null | head -1)"
    [ -z "$PHP_SOCK" ] && PHP_SOCK="/run/php/php8.3-fpm.sock"
    mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled 2>/dev/null || true
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
        fastcgi_pass unix:$PHP_SOCK;
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
    [ -z "$PMA_VER" ] && PMA_VER="5.2.1"
    echo -e "  ${W}Version:${NC} $PMA_VER"
    cd /var/www || { st ERR "No /var/www"; pause; return; }
    run_dl "phpMyAdmin.tar.gz" "https://files.phpmyadmin.net/phpMyAdmin/${PMA_VER#phpMyAdmin-}/phpMyAdmin-${PMA_VER#phpMyAdmin-}-all-languages.tar.gz" pma.tar.gz || { st ERR "Download failed"; pause; return; }
    tar -xzf pma.tar.gz || { st ERR "Extract failed."; pause; return; }
    rm -f pma.tar.gz
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
    read -rp "  Proceed? (y/N): " conf || conf=""
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
    echo -e "     ${GR}[1]${NC} Install         ${DG}•${NC} Version Selector + Full Install"
    echo -e "     ${GR}[2]${NC} Users           ${DG}•${NC} Add Admin / User"
    echo -e "     ${GR}[3]${NC} Update          ${DG}•${NC} Pick Version / Latest"
    echo -e "     ${GR}[4]${NC} Domain & SSL    ${DG}•${NC} Let's Encrypt"
    echo -e "     ${GR}[5]${NC} phpMyAdmin      ${DG}•${NC} Database Manager"
    echo -e "     ${GR}[6]${NC} Uninstall       ${DG}•${NC} Remove Data"
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-6):${NC} "
    read -r choice || exit 0
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
