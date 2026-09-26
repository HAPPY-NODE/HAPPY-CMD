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

JTG_INSTALL_URL="https://raw.githubusercontent.com/JishnuTheGamer/Jtg/refs/heads/main/install.sh"
JTG_REPO_URL="https://github.com/JishnuTheGamer/Jtg"
JTG_MAIN_PORT=6767
JTG_DEV_PORT=3000

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

jtg_dir() {
    if [ -f "/root/Jtg/package.json" ]; then echo "/root/Jtg"
    elif [ -f "$HOME/Jtg/package.json" ]; then echo "$HOME/Jtg"
    elif [ -f "./Jtg/package.json" ]; then echo "$(pwd)/Jtg"
    else echo ""
    fi
}

jtg_up() {
    curl -s -m 3 "http://127.0.0.1:$JTG_MAIN_PORT/api/health" 2>/dev/null | grep -qi "jtg" && return 0
    curl -s -m 3 -o /dev/null -w "%{http_code}" "http://127.0.0.1:$JTG_MAIN_PORT/" 2>/dev/null | grep -q "200"
}

jtg_installed() {
    [ -n "$(jtg_dir)" ] || return 1
    command -v pm2 >/dev/null 2>&1 && pm2 jtg-main >/dev/null 2>&1 && return 0
    command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^jtg-main$" && return 0
    [ -n "$(jtg_dir)" ]
}

show_header() {
    clear
    local status="${R}● NOT INSTALLED${NC}"
    if jtg_up; then status="${G}● RUNNING${NC}"
    elif jtg_installed; then status="${Y}● INSTALLED (stopped)${NC}"
    fi
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}       J T G   P A N E L                      ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    Minecraft Server Panel  • port $JTG_MAIN_PORT        ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${W}Status:${NC}  $status"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

install_jtg() {
    show_header
    st INFO "Official installer: $JTG_REPO_URL"
    st INFO "One-liner: bash <(curl -s $JTG_INSTALL_URL)"
    sleep 0.4
    if ! run_dl "JTG installer" "$JTG_INSTALL_URL" /tmp/jtg_install.sh; then
        st ERR "Download failed."
        pause; return
    fi
    st WAIT "Starting official installer menu (1=Main Panel, 3=Update, 4=Owner, 5=Uninstall)..."
    if bash /tmp/jtg_install.sh; then
        st OK "Installer finished."
        if jtg_up; then
            local IP
            IP=$(curl -s -m 3 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')
            st OK "Panel live → http://${IP:-<IP>}:$JTG_MAIN_PORT"
        fi
    else
        st ERR "Installer exited with error."
    fi
    pause
}

access_info() {
    show_header
    local IP D DIR_
    IP=$(curl -s -m 3 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "<IP>")
    D="$(jtg_dir)"
    DIR_="${D:-not-installed}"
    echo -e "  ${C}◆ JTG PANEL ACCESS${NC}"
    echo -e "     ${W}Main Panel :${NC}  http://${IP}:$JTG_MAIN_PORT"
    echo -e "     ${W}Dev Panel  :${NC}  http://${IP}:$JTG_DEV_PORT"
    echo -e "     ${W}SFTP       :${NC}  port 2022"
    echo -e "     ${W}Install dir:${NC}  $DIR_"
    echo ""
    if jtg_up; then
        st OK "Health check: main panel ONLINE (port $JTG_MAIN_PORT)"
    else
        st ERR "Health check: port $JTG_MAIN_PORT not responding (start the panel)"
    fi
    if command -v pm2 >/dev/null 2>&1; then
        pm2 jtg-main >/dev/null 2>&1 && st OK "PM2: jtg-main online" || st INFO "PM2: jtg-main not online"
    fi
    echo -e "  ${SL}Manual install command:${NC}"
    echo "    bash <(curl -s $JTG_INSTALL_URL)"
    pause
}

setup_domain() {
    show_header
    st INFO "Domain/SSL setup: nginx + Let's Encrypt → port $JTG_MAIN_PORT"
    if ! jtg_installed; then
        st ERR "Panel not installed."
        pause; return
    fi
    read -rp "  Panel domain (e.g. jtg.yourdomain.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then st ERR "Domain required."; pause; return; fi
    st WAIT "Installing nginx + certbot..."
    install_steps "Web stack" nginx certbot python3-certbot-nginx || { st ERR "Install failed."; pause; return; }
    echo ""
    st WAIT "Writing nginx config (proxy → 127.0.0.1:$JTG_MAIN_PORT)..."
    cat > /etc/nginx/sites-available/jtg.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://127.0.0.1:$JTG_MAIN_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 90s;
        proxy_send_timeout 90s;
    }
    location ~ /\.well-known { allow all; }
}
EOF
    ln -sf /etc/nginx/sites-available/jtg.conf /etc/nginx/sites-enabled/jtg.conf
    nginx -t 2>/dev/null && run_live "nginx-reload" systemctl reload nginx || { st ERR "nginx config test failed."; pause; return; }
    echo ""
    st WAIT "Requesting SSL certificate..."
    run_live "certbot" certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email || st ERR "Certbot failed (DNS not pointing?)."
    echo ""
    st OK "Domain ready: https://$DOMAIN"
    pause
}

uninstall_jtg() {
    show_header
    echo -e "  ${R}⚠ Delete all JTG Panel data?${NC}"
    read -rp "  Proceed? (y/N): " conf
    [[ "$conf" =~ ^[Yy]$ ]] || { st INFO "Cancelled."; pause; return; }
    local D
    D="$(jtg_dir)"
    if [ -n "$D" ] && [ -f "$D/uninstall.sh" ]; then
        st WAIT "Running official uninstall..."
        (cd "$D" && bash uninstall.sh) || st INFO "Official uninstall had errors — cleaning manually..."
    fi
    st WAIT "Cleaning services + files..."
    command -v pm2 >/dev/null 2>&1 && {
        pm2 delete jtg-main >/dev/null 2>&1
        pm2 delete jtg-admin >/dev/null 2>&1
        pm2 save --force >/dev/null 2>&1
    }
    command -v docker >/dev/null 2>&1 && {
        docker rm -f jtg-main jtg-admin jtg-panel >/dev/null 2>&1
        docker compose down -v >/dev/null 2>&1
    }
    [ -n "$D" ] && rm -rf "$D"
    rm -rf "$HOME/Jtg" ./Jtg 2>/dev/null
    rm -f /etc/nginx/sites-{enabled,available}/jtg.conf 2>/dev/null
    systemctl reload nginx 2>/dev/null
    rm -f /tmp/jtg_install.sh 2>/dev/null
    st OK "Removed."
    pause
}

while true; do
    show_header
    echo -e "  ${C}◆ JTG PANEL MANAGEMENT${NC}"
    echo -e "     ${GR}[1]${NC} Install         ${DG}•${NC} Official installer (port $JTG_MAIN_PORT)"
    echo -e "     ${GR}[2]${NC} Access Info     ${DG}•${NC} URL, ports, health"
    echo -e "     ${GR}[3]${NC} Domain & SSL    ${DG}•${NC} nginx + Let's Encrypt"
    echo -e "     ${GR}[4]${NC} Uninstall       ${DG}•${NC} Remove Data"
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-4):${NC} "
    read -r choice || exit 0
    case $choice in
        1) install_jtg ;;
        2) access_info ;;
        3) setup_domain ;;
        4) uninstall_jtg ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
