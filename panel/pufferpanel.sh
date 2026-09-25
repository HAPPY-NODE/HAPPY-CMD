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

# =============================
# HAPPY-CMD PufferPanel Manager
# Ports: 8080 (web) | 5657 (SFTP)
# =============================

st() {
    case $1 in
        OK)   echo -e "  ${G}✓${NC} $2" ;;
        ERR)  echo -e "  ${R}✗${NC} $2" ;;
        INFO) echo -e "  ${C}→${NC} $2" ;;
        WAIT) echo -e "  ${Y}⏳${NC} $2" ;;
        PORT) echo -e "  ${M}◆${NC} $2" ;;
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

# ---------- Status ----------
pp_status() {
    if systemctl is-active --quiet pufferpanel 2>/dev/null; then
        echo -e "${G}● RUNNING${NC}"
    elif command -v pufferpanel >/dev/null 2>&1; then
        echo -e "${Y}● INSTALLED${NC}"
    else
        echo -e "${R}● NOT INSTALLED${NC}"
    fi
}

pp_version() {
    local v
    v="$(pufferpanel version 2>/dev/null | head -1 | tr -d 'v')"
    echo "${v:-unknown}"
}

# ---------- Header ----------
show_header() {
    clear
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     P U F F E R P A N E L                    ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    Lightweight Game Panel                    ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${W}Status:${NC}  $(pp_status)  ${DG}│${NC}  ${W}Version:${NC} ${C}$(pp_version)${NC}"
    echo -e "  ${M}Ports:${NC}   ${W}8080${NC} ${SL}(web)${NC}  ${W}5657${NC} ${SL}(SFTP)${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

# ---------- Install ----------
install_pp() {
    show_header
    if command -v pufferpanel >/dev/null 2>&1; then
        st OK "Already installed ($(pp_version))."
        pause; return
    fi
    st INFO "Initiating PufferPanel installation..."
    st PORT "Ports to open: 8080 (web), 5657 (SFTP)"
    sleep 0.5
    if ! command -v apt-get >/dev/null 2>&1; then
        st ERR "Ubuntu/Debian (apt) required."
        pause; return
    fi
    st WAIT "Adding PufferPanel repository..."
    if ! run_live "pufferpanel-repo" bash -c 'curl -fsSL https://packagecloud.io/install/repositories/pufferpanel/pufferpanel/script.deb.sh | bash'; then
        st ERR "Repository setup failed. Check network."
        pause; return
    fi
    echo ""
    install_steps "PufferPanel packages" pufferpanel || { st ERR "Install failed."; pause; return; }
    echo ""
    if ! command -v pufferpanel >/dev/null 2>&1; then
        st ERR "PufferPanel not found after install."
        pause; return
    fi
    st WAIT "Enabling service..."
    run_live "systemd-enable" systemctl enable --now pufferpanel || true
    echo ""
    st OK "Installation complete. ($(pp_version))"
    echo -e "  ${SL}Panel:${NC} ${W}http://<your-ip>:8080${NC}"
    read -rp "  Create admin user now? (y/N): " conf || conf=""
    if [[ "$conf" =~ ^[Yy]$ ]]; then
        pp_add_user
    fi
    pause
}

# ---------- Admin user ----------
# PufferPanel ka survey prompt kuch terminals (TERM/tty) me input nahi leta —
# isliye plain bash prompts + CLI flags: survey bilkul run hi nahi hota.
pp_add_user() {
    local u e p adm flags
    read -rp "  Username: " u || { st ERR "No input."; return 1; }
    [ -n "$u" ] || { st ERR "Username required."; return 1; }
    read -rp "  Email: " e || { st ERR "No input."; return 1; }
    [ -n "$e" ] || { st ERR "Email required."; return 1; }
    read -rsp "  Password: " p; echo ""
    [ -n "$p" ] || { st ERR "Password required."; return 1; }
    read -rp "  Make admin? (Y/n): " adm || adm=""
    flags=(--name "$u" --email "$e" --password "$p")
    [[ "$adm" =~ ^[Nn]$ ]] || flags+=(--admin)
    if pufferpanel user add "${flags[@]}"; then
        if [[ "$adm" =~ ^[Nn]$ ]]; then
            st OK "User created: $u"
        else
            st OK "Admin created: $u"
        fi
    else
        st ERR "User creation failed."
        return 1
    fi
}

create_user() {
    show_header
    if ! command -v pufferpanel >/dev/null 2>&1; then
        st ERR "PufferPanel not installed. Use [1] first."
        pause; return
    fi
    st INFO "Adding user (non-interactive, admin by default)..."
    pp_add_user
    pause
}

# ---------- Service ----------
service_menu() {
    while true; do
        show_header
        echo -e "  ${C}◆ SERVICE${NC}"
        echo -e "     ${GR}[1]${NC} Start"
        echo -e "     ${GR}[2]${NC} Stop"
        echo -e "     ${GR}[3]${NC} Restart"
        echo -e "     ${GR}[4]${NC} Status (live)"
        echo -e "     ${R}[0]${NC} Back"
        echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
        echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-4):${NC} "
        read -r c || return
        case $c in
            1) run_live "systemd-start" systemctl start pufferpanel; pause ;;
            2) run_live "systemd-stop" systemctl stop pufferpanel; pause ;;
            3) run_live "systemd-restart" systemctl restart pufferpanel; pause ;;
            4) systemctl status pufferpanel --no-pager -l 2>/dev/null | head -20; pause ;;
            0) return ;;
            *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
        esac
    done
}

# ---------- Domain & SSL (nginx + certbot) ----------
setup_domain() {
    show_header
    st INFO "Domain setup: nginx reverse proxy + Let's Encrypt SSL"
    echo -e "  ${SL}Needs: domain A-record → this server IP${NC}"
    read -rp "  Panel domain (e.g. panel.yourdomain.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        st ERR "Domain required."
        pause; return
    fi
    st WAIT "Installing nginx + certbot..."
    install_steps "Web stack" nginx certbot python3-certbot-nginx || { st ERR "Install failed."; pause; return; }
    echo ""
    st WAIT "Writing nginx config..."
    cat > /etc/nginx/sites-available/pufferpanel.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location ~ ^/.well-known {
        root /var/www/html;
        allow all;
    }
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Nginx-Proxy true;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        client_max_body_size 100M;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/pufferpanel.conf /etc/nginx/sites-enabled/pufferpanel.conf
    nginx -t 2>/dev/null && run_live "nginx-reload" systemctl reload nginx || { st ERR "nginx config test failed."; pause; return; }
    echo ""
    st WAIT "Requesting SSL certificate..."
    run_live "certbot" certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email || st ERR "Certbot failed (DNS not pointing?)."
    echo ""
    st WAIT "Locking panel to localhost (127.0.0.1:8080)..."
    local cfg="/etc/pufferpanel/config.json"
    if [ -f "$cfg" ]; then
        if grep -q '"host"' "$cfg"; then
            sed -i 's|"host": *"[^"]*"|"host": "127.0.0.1:8080"|' "$cfg"
            run_live "pufferpanel-restart" systemctl restart pufferpanel || true
        else
            st WARN "No \"host\" key in $cfg — set it to 127.0.0.1:8080 manually"
        fi
    else
        st ERR "Config not found: $cfg"
    fi
    echo ""
    st OK "Domain ready: https://$DOMAIN"
    echo -e "  ${SL}Ports to keep open:${NC} ${W}80, 443${NC} ${SL}(web)${NC} ${W}5657${NC} ${SL}(SFTP)${NC}"
    pause
}

# ---------- Update ----------
update_pp() {
    show_header
    if ! command -v pufferpanel >/dev/null 2>&1; then
        st ERR "PufferPanel not installed."
        pause; return
    fi
    st INFO "Current: $(pp_version)"
    read -rp "  Upgrade package? (y/N): " conf
    [[ "$conf" =~ ^[Yy]$ ]] || { st INFO "Cancelled."; pause; return; }
    run_live "apt-update" apt-get update -y -q || true
    run_live "pufferpanel-upgrade" env DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade pufferpanel || st ERR "Upgrade failed."
    run_live "systemd-restart" systemctl restart pufferpanel || true
    echo ""
    st OK "Now: $(pp_version)"
    pause
}

# ---------- Uninstall ----------
uninstall_pp() {
    show_header
    echo -e "  ${R}⚠ WARNING: This will delete all panel data!${NC}"
    read -rp "  Proceed? (y/N): " conf
    [[ "$conf" =~ ^[Yy]$ ]] || { st INFO "Cancelled."; pause; return; }
    st WAIT "Stopping service..."
    run_live "systemd-stop" systemctl disable --now pufferpanel 2>/dev/null || true
    echo ""
    st WAIT "Removing package..."
    run_live "apt-remove" env DEBIAN_FRONTEND=noninteractive apt-get purge -y pufferpanel || true
    echo ""
    st WAIT "Deleting data..."
    rm -rf /etc/pufferpanel /var/lib/pufferpanel 2>/dev/null
    rm -f /etc/nginx/sites-{enabled,available}/pufferpanel.conf 2>/dev/null
    systemctl reload nginx 2>/dev/null || true
    st OK "PufferPanel removed."
    pause
}

# ---------- Main Menu ----------
while true; do
    show_header
    echo -e "  ${C}◆ PANEL MANAGEMENT${NC}"
    echo -e "     ${GR}[1]${NC} Install         ${DG}•${NC} Fresh Install (latest)"
    echo -e "     ${GR}[2]${NC} Admin User      ${DG}•${NC} Create Admin Login"
    echo -e "     ${GR}[3]${NC} Service         ${DG}•${NC} Start / Stop / Status"
    echo -e "     ${GR}[4]${NC} Domain & SSL    ${DG}•${NC} nginx + Let's Encrypt"
    echo -e "     ${GR}[5]${NC} Update          ${DG}•${NC} Upgrade Package"
    echo -e "     ${GR}[6]${NC} Uninstall       ${DG}•${NC} Remove Data"
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-6):${NC} "
    read -r choice || exit 0
    case $choice in
        1) install_pp ;;
        2) create_user ;;
        3) service_menu ;;
        4) setup_domain ;;
        5) update_pp ;;
        6) uninstall_pp ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
