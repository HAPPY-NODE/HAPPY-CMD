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
PANEL_PORT=5001
INSTALL_DIR="/opt/akvm"

st() {
    case $1 in
        OK)   echo -e "  ${G}✓${NC} $2" ;;
        ERR)  echo -e "  ${R}✗${NC} $2" ;;
        WARN) echo -e "  ${Y}⚠${NC} $2" ;;
        INFO) echo -e "  ${C}→${NC} $2" ;;
        WAIT) echo -e "  ${Y}⏳${NC} $2" ;;
    esac
}
pause() { echo ""; read -rp "  Press Enter to continue... " _; }

show_creds_box() {
    local name="$1" url="$2"
    echo ""
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     ${name} PANEL — ADMIN LOGIN                 ${CB}│${NC}"
    echo -e "  ${CB}├──────────────────────────────────────────────┤${NC}"
    echo -e "  ${CB}│${NC}  ${W}URL:${NC}      $url"
    echo -e "  ${CB}│${NC}  ${W}Username:${NC} ${G}admin${NC}"
    echo -e "  ${CB}│${NC}  ${W}Password:${NC} ${G}admin123${NC}"
    echo -e "  ${CB}│${NC}  ${Y}⚠ Change password after first login!${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
}

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

# systemd state pehle: crash-loop ko kabhi RUNNING mat dikhao
svc_display_state() {
    # $1=unit  $2=pgrep-pattern  $3=install-dir
    local _st _nr
    if [ -f "/etc/systemd/system/$1" ]; then
        _st="$(systemctl is-active "$1" 2>/dev/null || true)"
        case "$_st" in
            active) echo "RUNNING" ;;
            activating*|reloading*)
                _nr="$(systemctl show -p NRestarts --value "$1" 2>/dev/null || echo 0)"
                if [ "${_nr:-0}" -gt 0 ] 2>/dev/null; then echo "CRASH-LOOP"; else echo "STARTING"; fi ;;
            failed) echo "FAILED" ;;
            *)
                if pgrep -f "$2" >/dev/null 2>&1; then echo "RUNNING"; else echo "STOPPED"; fi ;;
        esac
    elif pgrep -f "$2" >/dev/null 2>&1; then
        echo "RUNNING"
    elif [ -n "$3" ] && [ -d "$3" ]; then
        echo "PARTIAL"
    else
        echo "NONE"
    fi
}

show_header() {
    clear
    local status="${R}● NOT INSTALLED${NC}"
    case "$(svc_display_state akvm.service "akvm.py" "$INSTALL_DIR")" in
        RUNNING)   status="${G}● RUNNING${NC}" ;;
        CRASH-LOOP) status="${R}● CRASH-LOOP — see menu [5]/[6]${NC}" ;;
        STARTING)  status="${Y}● STARTING…${NC}" ;;
        FAILED)    status="${R}● FAILED — see menu [5]/[6]${NC}" ;;
        STOPPED)   status="${Y}● INSTALLED (stopped)${NC}" ;;
        PARTIAL)   status="${R}● PARTIAL — run Install again${NC}" ;;
    esac
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     A K V M   P A N E L                      ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    KVM Manager  Port $PANEL_PORT                    ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${W}Status:${NC}  $status  ${DG}│${NC}  ${W}Port:${NC} $PANEL_PORT"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

vps_check() {
    local has_apt=0 has_py=0 has_sys=0 has_kvm=0
    local critical_ok=1 warn_ok=1 reasons=()
    local arch virt free_mb

    command -v apt-get >/dev/null 2>&1 && has_apt=1
    command -v python3 >/dev/null 2>&1 && has_py=1
    if command -v systemctl >/dev/null 2>&1 && [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then
        has_sys=1
    fi
    { [ -e /dev/kvm ] || grep -Eq 'vmx|svm' /proc/cpuinfo 2>/dev/null; } && has_kvm=1
    arch="$(uname -m 2>/dev/null || echo unknown)"
    virt="$(systemd-detect-virt 2>/dev/null || echo unknown)"

    echo -e "  ${C}◆ VPS SUPPORT CHECK${NC}"
    if [ "$has_apt" = 1 ]; then st OK "OS tools (apt)"; else st ERR "No apt-get (Debian/Ubuntu)"; critical_ok=0; reasons+=("apt-get missing"); fi
    if [ "$has_py" = 1 ]; then st OK "Python3 $(python3 -V 2>&1 | awk '{print $2}')"; else st ERR "Python3 missing"; critical_ok=0; reasons+=("python3 missing"); fi
    if [ "$has_sys" = 1 ]; then st OK "systemd (PID 1)"; else st ERR "systemd not running"; critical_ok=0; reasons+=("systemd not PID 1"); fi
    if [ "$arch" = "x86_64" ] || [ "$arch" = "amd64" ]; then st OK "Arch: $arch"; else st WARN "Arch: $arch"; warn_ok=0; fi
    if [ "$has_kvm" = 1 ]; then st OK "KVM / virt (QEMU)"; else st WARN "No /dev/kvm — TCG fallback (slower)"; warn_ok=0; fi
    st INFO "Virt type: $virt"

    free_mb=$(awk '/^MemAvailable:/{print $2; exit}' /proc/meminfo 2>/dev/null)
    [ -z "$free_mb" ] && free_mb=$(awk '/^MemFree:/{print $2; exit}' /proc/meminfo 2>/dev/null)
    if [ -n "$free_mb" ] && [ "$free_mb" -lt 900000 ] 2>/dev/null; then
        st WARN "Low RAM (~$((free_mb/1024))MB) — 1GB+ recommended"
        warn_ok=0
    fi

    echo ""
    if [ "$critical_ok" = 0 ]; then
        st ERR "Your VPS does not support this panel."
        local r; for r in "${reasons[@]}"; do echo -e "     ${R}•${NC} $r"; done
        st INFO "Use full KVM VPS (Ubuntu/Debian) with systemd."
        echo ""
        echo -e "  ${Y}⚠ Force install anyway? (may fail)${NC}"
        read -rp "  Install anyway? (y/N): " force
        if [[ ! "$force" =~ ^[Yy]$ ]]; then
            st INFO "Install cancelled."
            return 1
        fi
        st WAIT "Force install selected..."
    elif [ "$warn_ok" = 0 ]; then
        st WARN "VPS may work with limits — continuing..."
        echo ""
    else
        st OK "VPS supported — all checks passed."
        echo ""
    fi
    return 0
}

install_akvm() {
    show_header
    # sirf tab skip jab service STABLY active ho — crash-loop me re-install hi repair hai
    local _gst=""
    [ -f /etc/systemd/system/akvm.service ] && _gst="$(systemctl is-active akvm.service 2>/dev/null || true)"
    if [ -f "$INSTALL_DIR/akvm.py" ] && { [ "$_gst" = "active" ] || { [ -z "$_gst" ] && pgrep -f "akvm.py" >/dev/null 2>&1; }; }; then
        st OK "AKVM Panel already installed & running."
        pause; return
    fi

    vps_check || { pause; return; }

    echo -e "  ${C}◆ DOMAIN SETUP${NC}"
    read -rp "  Enter your domain (or IP) [localhost]: " DOMAIN
    DOMAIN="${DOMAIN:-localhost}"
    st INFO "Domain: $DOMAIN  →  http://$DOMAIN:$PANEL_PORT"
    echo ""

    st WAIT "Updating packages..."
    run_live "apt-update" apt-get update -y -q || { st ERR "apt update failed"; pause; return; }

    st WAIT "Installing dependencies (qemu, python, nginx, curl)..."
    if ! run_live "apt-install" env DEBIAN_FRONTEND=noninteractive apt-get install -y unzip curl ca-certificates nginx python3 python3-pip python3-venv qemu-system-x86 qemu-utils cloud-image-utils wget sshpass openssh-client git cpu-checker psmisc net-tools; then
        run_live "apt-fix" env DEBIAN_FRONTEND=noninteractive apt-get install -y --fix-broken unzip curl python3-pip python3-venv nginx qemu-system-x86 || {
            st ERR "Package install failed"
            st INFO "Try: apt install qemu-system-x86 python3-pip python3-venv nginx curl unzip"
            pause; return
        }
    fi
    command -v python3 >/dev/null 2>&1 && st OK "Python3 ready" || st WARN "python3 missing"
    command -v qemu-system-x86_64 >/dev/null 2>&1 && st OK "QEMU ready" || st WARN "QEMU missing — VM create may fail"

    mkdir -p "$INSTALL_DIR"
    if [ -f "$DIR/akvm.zip" ]; then
        st WAIT "Extracting AKVM Panel..."
        run_live "unzip-akvm" unzip -o "$DIR/akvm.zip" -d "$INSTALL_DIR"
        local uz=$?
    else
        run_dl "AKVM Panel zip" "$HN_BASE_URL/panel/akvm.zip" /tmp/akvm.zip
        local dl=$?
        if [ "$dl" = 0 ]; then
            run_live "unzip-akvm" unzip -o /tmp/akvm.zip -d "$INSTALL_DIR"
            local uz=$?
        else
            local uz=1
        fi
    fi
    # asli proof = akvm.py file, unzip rc nahi (purane zip warning par rc=1 deti thi)
    if [ ! -f "$INSTALL_DIR/akvm.py" ]; then
        st ERR "Extract failed — akvm.py not found"
        st INFO "Fix: rm -rf $INSTALL_DIR  →  re-run [1] Install"
        pause; return 1
    fi
    st OK "Panel files ready ($INSTALL_DIR)"

    st WAIT "Installing Python deps..."
    if [ ! -d "$INSTALL_DIR/venv" ]; then
        python3 -m venv "$INSTALL_DIR/venv" 2>/dev/null || st WARN "venv failed — using system pip"
    fi
    local PYV="$INSTALL_DIR/venv/bin/python"
    [ -x "$PYV" ] || PYV="$(command -v python3)"
    if [ -x "$INSTALL_DIR/venv/bin/pip" ]; then
        run_live "pip-install" "$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt" || \
            run_live "pip-retry" "$PYV" -m pip install -r "$INSTALL_DIR/requirements.txt" || st WARN "pip partial fail — verifying"
    else
        run_live "pip-install" "$PYV" -m pip install -r "$INSTALL_DIR/requirements.txt" --break-system-packages || \
            run_live "pip-retry" "$PYV" -m pip install -r "$INSTALL_DIR/requirements.txt" || st WARN "pip partial fail — verifying"
    fi

    st WAIT "Verifying imports (real check)..."
    if "$PYV" -c "import flask, werkzeug, psutil, paramiko, bcrypt, cryptography, nacl, discord" 2>/tmp/akvm_imp.log; then
        st OK "All packages import OK"
        rm -f /tmp/akvm_imp.log
    else
        st ERR "Import check FAILED — panel would crash:"
        while IFS= read -r l; do echo -e "     ${R}$l${NC}"; done < <(grep -E 'ModuleNotFoundError|ImportError' /tmp/akvm_imp.log 2>/dev/null | tail -2)
        st INFO "Fix: $PYV -m pip install -r $INSTALL_DIR/requirements.txt"
        st INFO "then re-run [1] Install from this menu"
        rm -f /tmp/akvm_imp.log
        pause; return 1
    fi

    st WAIT "Writing systemd service..."
    local PY="$INSTALL_DIR/venv/bin/python"
    [ -x "$PY" ] || PY="$(command -v python3)"
    cat > /etc/systemd/system/akvm.service <<EOF
[Unit]
Description=HAPPY NODE AKVM Panel
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$PY $INSTALL_DIR/akvm.py
Restart=on-failure
RestartSec=5
User=root
Environment=PYTHONUNBUFFERED=1
Environment=PORT=$PANEL_PORT
Environment=HOST=0.0.0.0

[Install]
WantedBy=multi-user.target
EOF

    st WAIT "Configuring Nginx → domain:$PANEL_PORT..."
    if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "localhost" ]; then
        cat > /etc/nginx/sites-available/akvm.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://127.0.0.1:$PANEL_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
    }
}
EOF
        ln -sf /etc/nginx/sites-available/akvm.conf /etc/nginx/sites-enabled/akvm.conf
        nginx -t >/dev/null 2>&1 && systemctl reload nginx 2>/dev/null
        st OK "Nginx: http://$DOMAIN → :$PANEL_PORT"
    fi

    st WAIT "Starting service..."
    local has_sys=0
    if command -v systemctl >/dev/null 2>&1 && [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then
        has_sys=1
    fi

    if [ "$has_sys" = 1 ]; then
        systemctl daemon-reload
        systemctl enable akvm.service >/dev/null 2>&1
        systemctl restart akvm.service
        # state text + stability check (is-active --quiet crash-loop me bhi 0 deta hai)
        local waited=0 _st="" still=""
        while [ "$waited" -lt 15 ]; do
            _st="$(systemctl is-active akvm.service 2>/dev/null || true)"
            case "$_st" in
                failed|inactive) break ;;
                active)
                    sleep 2
                    still="$(systemctl is-active akvm.service 2>/dev/null || true)"
                    if [ "$still" = "active" ]; then _st="active"; break; fi
                    _st="$still" ;;
            esac
            sleep 1; waited=$((waited+3))
        done
        if [ "$_st" = "active" ]; then
            st OK "AKVM Panel installed successfully!"
            echo -e "  ${W}URL:${NC}     http://$DOMAIN:$PANEL_PORT"
            [ "$DOMAIN" != "localhost" ] && echo -e "  ${W}Nginx:${NC}   http://$DOMAIN"
            echo -e "  ${W}Service:${NC} akvm.service (active)"
            echo -e "  ${W}Path:${NC}    $INSTALL_DIR"
            show_creds_box "AKVM" "http://$DOMAIN:$PANEL_PORT"
        else
            st ERR "Service failed (state: ${_st:-unknown}) — last journal lines:"
            journalctl -u akvm.service -n 12 --no-pager 2>/dev/null | tail -8 | sed 's/^/  /'
            st INFO "Full log: journalctl -u akvm.service -e"
            st INFO "Manual: cd $INSTALL_DIR && PORT=$PANEL_PORT $PY akvm.py"
            st INFO "Fix the error above, then re-run [1] Install"
        fi
    else
        st WARN "No systemd — starting in background mode..."
        pkill -f "${INSTALL_DIR}/akvm.py" 2>/dev/null || true
        (cd "$INSTALL_DIR" && PORT=$PANEL_PORT HOST=0.0.0.0 nohup "$PY" akvm.py >/var/log/akvm.log 2>&1 &)
        sleep 3
        if pgrep -f "akvm.py" >/dev/null 2>&1; then
            st OK "AKVM Panel running (background mode, no systemd)"
            echo -e "  ${W}URL:${NC}  http://$DOMAIN:$PANEL_PORT"
            echo -e "  ${W}Log:${NC}   /var/log/akvm.log"
            st INFO "Note: auto-start on reboot needs systemd"
            show_creds_box "AKVM" "http://$DOMAIN:$PANEL_PORT"
        else
            st ERR "Start failed. Check: cat /var/log/akvm.log"
        fi
    fi
    pause
}

start_service() {
    show_header
    local PY="$INSTALL_DIR/venv/bin/python"
    [ -x "$PY" ] || PY="$(command -v python3)"
    if command -v systemctl >/dev/null 2>&1 && systemctl start akvm.service 2>/dev/null; then
        sleep 2
        local _st="$(systemctl is-active akvm.service 2>/dev/null || true)"
        if [ "$_st" = "active" ]; then
            st OK "Started (systemd)"
        else
            st ERR "Service crashed after start (state: ${_st:-unknown}) — last journal lines:"
            journalctl -u akvm.service -n 12 --no-pager 2>/dev/null | tail -8 | sed 's/^/  /'
        fi
    elif pgrep -f "akvm.py" >/dev/null 2>&1; then
        st INFO "Already running (background mode)"
    else
        if [ -f "$INSTALL_DIR/akvm.py" ]; then
            (cd "$INSTALL_DIR" && PORT=$PANEL_PORT HOST=0.0.0.0 nohup "$PY" akvm.py >/var/log/akvm.log 2>&1 &)
            sleep 2
            pgrep -f "akvm.py" >/dev/null 2>&1 && st OK "Started (background mode)" || st ERR "Failed — /var/log/akvm.log"
        else
            st ERR "Not installed"
        fi
    fi
    pause
}

stop_service() {
    show_header
    local stopped=0
    systemctl stop akvm.service 2>/dev/null && stopped=1
    pkill -f "${INSTALL_DIR}/akvm.py" 2>/dev/null && stopped=1
    [ "$stopped" = 1 ] && st OK "Stopped" || st ERR "Not running / not installed"
    pause
}

restart_service() {
    show_header
    local PY="$INSTALL_DIR/venv/bin/python"
    [ -x "$PY" ] || PY="$(command -v python3)"
    systemctl stop akvm.service 2>/dev/null
    pkill -f "${INSTALL_DIR}/akvm.py" 2>/dev/null
    sleep 1
    if command -v systemctl >/dev/null 2>&1 && [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ] && systemctl start akvm.service 2>/dev/null; then
        sleep 2
        local _st="$(systemctl is-active akvm.service 2>/dev/null || true)"
        if [ "$_st" = "active" ]; then
            st OK "Restarted (systemd)"
        else
            st ERR "Service crashed after restart (state: ${_st:-unknown}) — last journal lines:"
            journalctl -u akvm.service -n 12 --no-pager 2>/dev/null | tail -8 | sed 's/^/  /'
        fi
    elif [ -f "$INSTALL_DIR/akvm.py" ]; then
        (cd "$INSTALL_DIR" && PORT=$PANEL_PORT HOST=0.0.0.0 nohup "$PY" akvm.py >/var/log/akvm.log 2>&1 &)
        sleep 2
        pgrep -f "akvm.py" >/dev/null 2>&1 && st OK "Restarted (background mode)" || st ERR "Failed — /var/log/akvm.log"
    else
        st ERR "Not installed"
    fi
    pause
}

service_status() {
    show_header
    if command -v systemctl >/dev/null 2>&1 && [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then
        systemctl status akvm.service --no-pager -l 2>/dev/null | head -15
    else
        if pgrep -f "akvm.py" >/dev/null 2>&1; then
            st OK "Running (background) PID: $(pgrep -f "akvm.py" | head -1)"
        else
            st ERR "Not running"
        fi
    fi
    echo ""
    st INFO "Port check:"
    ss -tlnp 2>/dev/null | grep ":$PANEL_PORT " || echo "  Port $PANEL_PORT not listening"
    pause
}

view_logs() {
    show_header
    st INFO "Last 30 log lines (Ctrl+C to exit):"
    echo ""
    if journalctl -u akvm.service -n 30 --no-pager 2>/dev/null; then
        :
    elif [ -f /var/log/akvm.log ]; then
        tail -30 /var/log/akvm.log
    else
        st ERR "No logs"
    fi
    pause
}

setup_domain() {
    show_header
    read -rp "  Enter domain: " DOMAIN || DOMAIN=""
    [ -z "$DOMAIN" ] && { st ERR "Empty domain"; pause; return; }
    st WAIT "Installing nginx + certbot..."
    install_steps "Web stack" nginx certbot python3-certbot-nginx || { st ERR "Install failed."; pause; return; }
    echo ""
    cat > /etc/nginx/sites-available/akvm.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://127.0.0.1:$PANEL_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/akvm.conf /etc/nginx/sites-enabled/akvm.conf
    nginx -t >/dev/null 2>&1 && systemctl reload nginx
    st WAIT "Requesting SSL certificate..."
    run_live "certbot" certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email || st ERR "Certbot failed (DNS not pointing?)."
    st OK "Domain set: https://$DOMAIN → :$PANEL_PORT"
    pause
}

uninstall_akvm() {
    show_header
    echo -e "  ${R}⚠ Delete AKVM Panel and all data?${NC}"
    read -rp "  Proceed? (y/N): " conf
    [[ "$conf" =~ ^[Yy]$ ]] || { st INFO "Cancelled."; pause; return; }
    systemctl stop akvm.service 2>/dev/null
    systemctl disable akvm.service 2>/dev/null
    pkill -f "${INSTALL_DIR}/akvm.py" 2>/dev/null
    rm -f /etc/systemd/system/akvm.service
    systemctl daemon-reload 2>/dev/null
    rm -rf "$INSTALL_DIR"
    rm -f /etc/nginx/sites-available/akvm.conf /etc/nginx/sites-enabled/akvm.conf
    systemctl reload nginx 2>/dev/null
    st OK "AKVM Panel removed."
    pause
}

while true; do
    show_header
    echo -e "  ${C}◆ AKVM PANEL MANAGEMENT${NC}"
    echo -e "     ${GR}[1]${NC} Install         ${DG}•${NC} Full Setup + Domain"
    echo -e "     ${GR}[2]${NC} Start           ${DG}•${NC} Start Service"
    echo -e "     ${GR}[3]${NC} Stop            ${DG}•${NC} Stop Service"
    echo -e "     ${GR}[4]${NC} Restart         ${DG}•${NC} Restart Service"
    echo -e "     ${GR}[5]${NC} Status          ${DG}•${NC} Service + Port $PANEL_PORT"
    echo -e "     ${GR}[6]${NC} Logs            ${DG}•${NC} View Journal"
    echo -e "     ${GR}[7]${NC} Domain & SSL    ${DG}•${NC} Nginx → :$PANEL_PORT"
    echo -e "     ${GR}[8]${NC} Uninstall       ${DG}•${NC} Remove All"
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-8):${NC} "
    read -r choice || exit 0
    case $choice in
        1) install_akvm ;;
        2) start_service ;;
        3) stop_service ;;
        4) restart_service ;;
        5) service_status ;;
        6) view_logs ;;
        7) setup_domain ;;
        8) uninstall_akvm ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
