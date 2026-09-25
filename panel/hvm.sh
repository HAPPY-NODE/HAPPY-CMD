#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
source "$ROOT/colors.sh"
HN_BASE_URL="https://raw.githubusercontent.com/HAPPY-NODE/HAPPY-CMD/main"

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
    echo -e "  ${CB}│${NC}  ${W}Password:${NC} ${G}admin${NC}"
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

show_header() {
    clear
    local status="${R}● NOT INSTALLED${NC}"
    systemctl is-active --quiet hvm.service 2>/dev/null && status="${G}● RUNNING${NC}"
    [ -d "/root/hvm/hvm" ] && [ ! "$(systemctl is-active hvm.service 2>/dev/null)" = "active" ] && status="${Y}● INSTALLED${NC}"
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     H V M   P A N E L                        ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    LXC VPS Manager  Port 5000                ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${W}Status:${NC}  $status  ${DG}│${NC}  ${W}Port:${NC} 5000"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

install_hvm() {
    show_header
    if [ -d "/root/hvm/hvm" ] && systemctl is-active --quiet hvm.service 2>/dev/null; then
        st OK "HVM Panel already installed & running."
        pause; return
    fi

    local virt osb critical_ok=1 warn_ok=1 reasons=()
    virt="$(systemd-detect-virt 2>/dev/null || echo unknown)"
    osb="$(uname -s 2>/dev/null || echo Linux)"
    local arch="$(uname -m 2>/dev/null || echo unknown)"
    local has_apt=0 has_py=0 has_sys=0 has_kvm=0 has_snap=0

    command -v apt-get >/dev/null 2>&1 && has_apt=1
    command -v python3 >/dev/null 2>&1 && has_py=1
    if command -v systemctl >/dev/null 2>&1 && [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then
        has_sys=1
    fi
    { [ -e /dev/kvm ] || grep -Eq 'vmx|svm' /proc/cpuinfo 2>/dev/null; } && has_kvm=1
    command -v snap >/dev/null 2>&1 && has_snap=1

    echo -e "  ${C}◆ VPS SUPPORT CHECK${NC}"
    if [ "$has_apt" = 1 ]; then st OK "OS tools (apt)"; else st ERR "No apt-get (Debian/Ubuntu required)"; critical_ok=0; reasons+=("apt-get missing"); fi
    if [ "$has_py" = 1 ]; then st OK "Python3"; else st ERR "Python3 missing"; critical_ok=0; reasons+=("python3 missing"); fi
    if [ "$has_sys" = 1 ]; then st OK "systemd (PID 1)"; else st ERR "systemd not running (OpenVZ/container?)"; critical_ok=0; reasons+=("systemd not PID 1"); fi
    if [ "$arch" = "x86_64" ] || [ "$arch" = "amd64" ]; then st OK "Arch: $arch"; else st WARN "Arch: $arch (x86_64 recommended)"; warn_ok=0; fi
    if [ "$has_kvm" = 1 ]; then st OK "KVM / virt for LXD"; else st WARN "No KVM — LXD may fail"; warn_ok=0; fi
    st INFO "Virt type: $virt"
    if [ "$has_snap" = 1 ]; then st OK "snap available"; else st INFO "snap missing (will try install)"; warn_ok=0; fi

    local free_mb; free_mb=$(awk '/MemAvailable|MemFree/{print $2; exit}' /proc/meminfo 2>/dev/null)
    if [ -n "$free_mb" ] && [ "$free_mb" -lt 500000 ] 2>/dev/null; then
        st WARN "Low RAM (~$((free_mb/1024))MB free) — 1GB+ recommended"
        warn_ok=0
    fi

    echo ""
    if [ "$critical_ok" = 0 ]; then
        st ERR "Your VPS does not support this panel."
        local r; for r in "${reasons[@]}"; do echo -e "     ${R}•${NC} $r"; done
        st INFO "Use a full KVM VPS (Ubuntu/Debian) with systemd."
        echo ""
        echo -e "  ${Y}⚠ Force install anyway? (may fail)${NC}"
        read -rp "  Install anyway? (y/N): " force
        if [[ ! "$force" =~ ^[Yy]$ ]]; then
            st INFO "Install cancelled."
            pause; return
        fi
        st WAIT "Force install selected..."
    elif [ "$warn_ok" = 0 ]; then
        st WARN "VPS may work with limits — continuing..."
        echo ""
    else
        st OK "VPS supported — all checks passed."
        echo ""
    fi

    echo -e "  ${C}◆ DOMAIN SETUP${NC}"
    read -rp "  Enter your domain (or IP) [localhost]: " DOMAIN
    DOMAIN="${DOMAIN:-localhost}"
    st INFO "Domain: $DOMAIN  →  http://$DOMAIN:5000"

    echo ""
    st WAIT "Updating packages..."
    run_live "apt-update" apt-get update -y -q || { st ERR "apt update failed"; pause; return; }

    st WAIT "Installing dependencies (unzip, snapd, python, nginx, curl)..."
    if ! run_live "apt-install" env DEBIAN_FRONTEND=noninteractive apt-get install -y unzip snapd python3 python3-pip python3-venv nginx curl ca-certificates lsb-release software-properties-common; then
        run_live "apt-fix" env DEBIAN_FRONTEND=noninteractive apt-get install -y --fix-broken unzip snapd python3-pip python3-venv nginx curl || {
            st ERR "Package install failed — VPS may not support apt deps."
            st INFO "Try: apt update && apt install unzip snapd python3-pip nginx curl"
            pause; return
        }
    fi
    st OK "Base packages installed"

    st WAIT "Starting snapd..."
    systemctl enable --now snapd.socket >/dev/null 2>&1 || true
    systemctl enable --now snapd >/dev/null 2>&1 || true
    sleep 2

    st WAIT "Installing LXD via snap..."
    if run_live "snap-lxd" snap install lxd; then
        st OK "LXD installed"
    else
        run_live "snap-refresh" snap refresh lxd || true
        if run_live "snap-lxd-retry" snap install lxd; then
            st OK "LXD installed (retry)"
        else
            st WARN "LXD snap failed — panel UI may work, VM create may not"
        fi
    fi

    grep -q '/snap/bin' /root/.bashrc 2>/dev/null || echo 'export PATH=$PATH:/snap/bin' >> /root/.bashrc
    export PATH=$PATH:/snap/bin

    mkdir -p /root/hvm
    if [ -f "$DIR/hvm.zip" ]; then
        st WAIT "Extracting HVM Panel..."
        run_live "unzip-hvm" unzip -o "$DIR/hvm.zip" -d /root/hvm || { st ERR "Unzip failed"; pause; return; }
    else
        run_dl "HVM Panel zip" "$HN_BASE_URL/panel/hvm.zip" /tmp/hvm.zip || { st ERR "Download failed"; pause; return; }
        st WAIT "Extracting HVM Panel..."
        run_live "unzip-hvm" unzip -o /tmp/hvm.zip -d /root/hvm || { st ERR "Unzip failed"; pause; return; }
    fi
    st OK "Panel files ready (/root/hvm)"

    st WAIT "Installing Python packages..."
    if ! run_live "pip-install" pip3 install --break-system-packages flask flask_login paramiko \
        flask-cors flask-socketio eventlet requests bcrypt pillow psutil \
        cryptography python-dotenv; then
        if ! run_live "pip-install" pip3 install flask flask_login paramiko \
            flask-cors flask-socketio eventlet requests bcrypt pillow psutil \
            cryptography python-dotenv; then
            st ERR "pip install failed"
            st INFO "Run: pip3 install flask flask_login flask-cors flask-socketio eventlet"
            pause; return
        fi
    fi

    if [ -f /root/hvm/hvm/requirements.txt ]; then
        st WAIT "Installing requirements.txt..."
        if ! run_live "pip-req" pip3 install --break-system-packages -r /root/hvm/hvm/requirements.txt; then
            run_live "pip-req" pip3 install -r /root/hvm/hvm/requirements.txt || \
            st WARN "requirements.txt partial fail (base pkgs OK)"
        fi
    fi
    st OK "Python packages ready"

    st WAIT "Initializing LXD..."
    if command -v lxd >/dev/null 2>&1; then
        if ! lxd init --auto >/dev/null 2>&1; then
            lxd init >/dev/null 2>&1 || st WARN "LXD init skipped (may already be initialized)"
        fi
        st OK "LXD ready"
    else
        st WARN "lxd binary not found"
    fi

    st WAIT "Writing systemd service..."
    cat > /etc/systemd/system/hvm.service <<EOF
[Unit]
Description=HVM Python Service - HAPPY NODE
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /root/hvm/hvm/hvm.py
WorkingDirectory=/root/hvm/hvm
Restart=always
RestartSec=3
User=root
Environment=PORT=5000
Environment=HOST=0.0.0.0
Environment=PANEL_NAME=HAPPY NODE
Environment=PANEL_DEVELOPER=HAPPY NODE

[Install]
WantedBy=multi-user.target
EOF

    st WAIT "Configuring Nginx → domain:5000..."
    if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "localhost" ]; then
        cat > /etc/nginx/sites-available/hvm.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
        ln -sf /etc/nginx/sites-available/hvm.conf /etc/nginx/sites-enabled/hvm.conf
        nginx -t >/dev/null 2>&1 && systemctl reload nginx 2>/dev/null
        st OK "Nginx: http://$DOMAIN → :5000"
    fi

    st WAIT "Starting service..."
    if [ "$has_sys" = 1 ]; then
        systemctl daemon-reload
        systemctl enable hvm.service >/dev/null 2>&1
        systemctl restart hvm.service
        sleep 2
        if systemctl is-active --quiet hvm.service 2>/dev/null; then
            st OK "HVM Panel installed successfully!"
            echo -e "  ${W}URL:${NC}     http://$DOMAIN:5000"
            [ "$DOMAIN" != "localhost" ] && echo -e "  ${W}Nginx:${NC}   http://$DOMAIN"
            echo -e "  ${W}Service:${NC} hvm.service (active)"
            echo -e "  ${W}Path:${NC}    /root/hvm/hvm"
            show_creds_box "HVM" "http://$DOMAIN:5000"
        else
            st ERR "Service failed. Check: journalctl -u hvm.service"
            st INFO "Fallback: nohup python3 /root/hvm/hvm/hvm.py &"
        fi
    else
        st WARN "No systemd — using nohup fallback..."
        pkill -f "/root/hvm/hvm/hvm.py" 2>/dev/null || true
        cd /root/hvm/hvm && PORT=5000 HOST=0.0.0.0 nohup python3 /root/hvm/hvm/hvm.py >/var/log/hvm.log 2>&1 &
        sleep 2
        if pgrep -f "/root/hvm/hvm/hvm.py" >/dev/null 2>&1; then
            st OK "HVM Panel running (nohup, no systemd)"
            echo -e "  ${W}URL:${NC}  http://$DOMAIN:5000"
            echo -e "  ${W}Log:${NC}   /var/log/hvm.log"
            st INFO "Note: auto-start on reboot not available without systemd"
            show_creds_box "HVM" "http://$DOMAIN:5000"
        else
            st ERR "Start failed. Check: cat /var/log/hvm.log"
        fi
    fi
    pause
}

start_service() {
    show_header
    if command -v systemctl >/dev/null 2>&1 && systemctl start hvm.service 2>/dev/null; then
        st OK "Started (systemd)"
    elif pgrep -f "/root/hvm/hvm/hvm.py" >/dev/null 2>&1; then
        st INFO "Already running (nohup)"
    else
        if [ -f /root/hvm/hvm/hvm.py ]; then
            cd /root/hvm/hvm && PORT=5000 HOST=0.0.0.0 nohup python3 /root/hvm/hvm/hvm.py >/var/log/hvm.log 2>&1 &
            sleep 2
            pgrep -f "/root/hvm/hvm/hvm.py" >/dev/null 2>&1 && st OK "Started (nohup)" || st ERR "Failed — see /var/log/hvm.log"
        else
            st ERR "Not installed"
        fi
    fi
    pause
}

stop_service() {
    show_header
    local stopped=0
    systemctl stop hvm.service 2>/dev/null && stopped=1
    pkill -f "/root/hvm/hvm/hvm.py" 2>/dev/null && stopped=1
    [ "$stopped" = 1 ] && st OK "Stopped" || st ERR "Not running / not installed"
    pause
}

restart_service() {
    show_header
    local was=0
    systemctl stop hvm.service 2>/dev/null && was=1
    pkill -f "/root/hvm/hvm/hvm.py" 2>/dev/null && was=1
    if command -v systemctl >/dev/null 2>&1 && [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ] && systemctl start hvm.service 2>/dev/null; then
        st OK "Restarted (systemd)"
    elif [ -f /root/hvm/hvm/hvm.py ]; then
        cd /root/hvm/hvm && PORT=5000 HOST=0.0.0.0 nohup python3 /root/hvm/hvm/hvm.py >/var/log/hvm.log 2>&1 &
        sleep 2
        pgrep -f "/root/hvm/hvm/hvm.py" >/dev/null 2>&1 && st OK "Restarted (nohup)" || st ERR "Failed — see /var/log/hvm.log"
    else
        st ERR "Not installed"
    fi
    pause
}

service_status() {
    show_header
    if command -v systemctl >/dev/null 2>&1 && [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then
        systemctl status hvm.service --no-pager -l 2>/dev/null | head -15
    else
        if pgrep -f "/root/hvm/hvm/hvm.py" >/dev/null 2>&1; then
            st OK "Running (nohup) PID: $(pgrep -f '/root/hvm/hvm/hvm.py' | head -1)"
        else
            st ERR "Not running"
        fi
    fi
    echo ""
    st INFO "Port check:"
    ss -tlnp 2>/dev/null | grep ':5000 ' || echo "  Port 5000 not listening"
    pause
}

view_logs() {
    show_header
    st INFO "Last 30 log lines (Ctrl+C to exit):"
    echo ""
    if journalctl -u hvm.service -n 30 --no-pager 2>/dev/null; then
        :
    elif [ -f /var/log/hvm.log ]; then
        tail -30 /var/log/hvm.log
    else
        st ERR "No logs"
    fi
    pause
}

setup_domain() {
    show_header
    read -rp "  Enter domain: " DOMAIN
    [ -z "$DOMAIN" ] && { st ERR "Empty domain"; pause; return; }
    cat > /etc/nginx/sites-available/hvm.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
    ln -sf /etc/nginx/sites-available/hvm.conf /etc/nginx/sites-enabled/hvm.conf
    nginx -t >/dev/null 2>&1 && systemctl reload nginx
    st OK "Domain set: http://$DOMAIN → :5000"
    pause
}

uninstall_hvm() {
    show_header
    echo -e "  ${R}⚠ Delete HVM Panel and all data?${NC}"
    read -rp "  Proceed? (y/N): " conf
    [[ "$conf" =~ ^[Yy]$ ]] || { st INFO "Cancelled."; pause; return; }
    systemctl stop hvm.service 2>/dev/null
    systemctl disable hvm.service 2>/dev/null
    rm -f /etc/systemd/system/hvm.service
    systemctl daemon-reload
    rm -rf /root/hvm
    rm -f /etc/nginx/sites-{available,enabled}/hvm.conf
    systemctl reload nginx 2>/dev/null
    st OK "HVM Panel removed."
    pause
}

while true; do
    show_header
    echo -e "  ${C}◆ HVM PANEL MANAGEMENT${NC}"
    echo -e "     ${GR}[1]${NC} Install         ${DG}•${NC} Full Setup + Domain"
    echo -e "     ${GR}[2]${NC} Start           ${DG}•${NC} Start Service"
    echo -e "     ${GR}[3]${NC} Stop            ${DG}•${NC} Stop Service"
    echo -e "     ${GR}[4]${NC} Restart         ${DG}•${NC} Restart Service"
    echo -e "     ${GR}[5]${NC} Status          ${DG}•${NC} Service + Port 5000"
    echo -e "     ${GR}[6]${NC} Logs            ${DG}•${NC} View Journal"
    echo -e "     ${GR}[7]${NC} Domain & SSL    ${DG}•${NC} Nginx → :5000"
    echo -e "     ${GR}[8]${NC} Uninstall       ${DG}•${NC} Remove All"
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-8):${NC} "
    read -r choice
    case $choice in
        1) install_hvm ;;
        2) start_service ;;
        3) stop_service ;;
        4) restart_service ;;
        5) service_status ;;
        6) view_logs ;;
        7) setup_domain ;;
        8) uninstall_hvm ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
