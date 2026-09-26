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

OMG_ZIP="$HN_BASE_URL/panel/Omega-Panel-V3-main.zip"
PDIR=/root/omega-panel/Omega-Panel-V3-main
UNIT=omega-panel.service
OMG_PORT=5000
NODE_PORT=5001

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

dots_load() {
    local msg="$1" n="${2:-3}"
    printf "   %s" "$msg"
    for ((i=0; i<n; i++)); do printf "."; sleep 0.3; done
    printf "\r\033[K"
}

# systemd state pehle: crash-loop ko kabhi RUNNING mat dikhao + container noise skip
svc_display_state() {
    # $1=unit  $2=pgrep-pattern  $3=install-dir
    local _st _nr
    if [ -f "/etc/systemd/system/$1" ] && [ -d /run/systemd/system ]; then
        _st="$(systemctl is-active "$1" 2>/dev/null | grep -m1 -E '^(active|activating|reloading|failed|inactive|dead|static|masked)' || true)"
        case "$_st" in
            active) echo "RUNNING" ;;
            activating*|reloading*)
                _nr="$(systemctl show -p NRestarts --value "$1" 2>/dev/null | grep -m1 -E '^[0-9]+' || echo 0)"
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

omega_up() {
    local code
    code=$(curl -s -m 3 -o /dev/null -w "%{http_code}" "http://127.0.0.1:$OMG_PORT/" 2>/dev/null)
    [ -n "$code" ] && [ "$code" != "000" ]
}

show_creds_box() {
    local url="$1"
    echo ""
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     OMEGA PANEL — ADMIN LOGIN                ${CB}│${NC}"
    echo -e "  ${CB}├──────────────────────────────────────────────┤${NC}"
    echo -e "  ${CB}│${NC}  ${W}URL:${NC}      $url"
    echo -e "  ${CB}│${NC}  ${W}Username:${NC} ${G}admin${NC}"
    echo -e "  ${CB}│${NC}  ${W}Password:${NC} ${G}admin123${NC}"
    echo -e "  ${CB}│${NC}  ${Y}⚠ Change password after first login!${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
}

show_header() {
    clear
    local status="${R}● NOT INSTALLED${NC}"
    case "$(svc_display_state "$UNIT" "$PDIR/app.py" "$PDIR")" in
        RUNNING)    if omega_up; then status="${G}● RUNNING${NC}"; else status="${Y}● RUNNING (port $OMG_PORT not answering yet)${NC}"; fi ;;
        CRASH-LOOP) status="${R}● CRASH-LOOP — run Install again${NC}" ;;
        STARTING)   status="${Y}● STARTING…${NC}" ;;
        FAILED)     status="${R}● FAILED — run Install again${NC}" ;;
        STOPPED)    status="${Y}● INSTALLED (stopped)${NC}" ;;
        PARTIAL)    status="${R}● PARTIAL — run Install again${NC}" ;;
    esac
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}    O M E G A   P A N E L   V 3               ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    LXC VPS Manager  Port $OMG_PORT               ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${W}Status:${NC}  $status  ${DG}│${NC}  ${W}Port:${NC} $OMG_PORT"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

install_omega() {
    show_header
    if [ -f "$PDIR/app.py" ] && [ "$(systemctl is-active "$UNIT" 2>/dev/null | grep -m1 -E '^(active|inactive|failed|activating)' || true)" = "active" ]; then
        st OK "Omega Panel already installed & running."
        pause; return
    fi

    local virt osb critical_ok=1 warn_ok=1 reasons=()

    # Pahle domain lo — install ke baad yahi URL milega (baaki sab panels jaisa)
    echo -e "  ${C}◆ DOMAIN SETUP${NC}"
    read -rp "  Enter your domain (or IP) [localhost]: " DOMAIN
    DOMAIN="${DOMAIN:-localhost}"
    st INFO "Domain: $DOMAIN  →  URL: http://$DOMAIN:$OMG_PORT"

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
    if [ "$has_kvm" = 1 ]; then st OK "KVM / virt for LXD"; else st WARN "No KVM — LXC may fail"; warn_ok=0; fi
    st INFO "Virt type: $virt"
    if [ "$has_snap" = 1 ]; then st OK "snap available"; else st INFO "snap missing (setup.sh will install)"; warn_ok=0; fi

    local free_mb; free_mb=$(awk '/^MemAvailable:/{print $2; exit}' /proc/meminfo 2>/dev/null)
    [ -z "$free_mb" ] && free_mb=$(awk '/^MemFree:/{print $2; exit}' /proc/meminfo 2>/dev/null)
    if [ -n "$free_mb" ] && [ "$free_mb" -lt 900000 ] 2>/dev/null; then
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

    st WAIT "Repairing apt state (if a previous install failed)..."
    run_live "dpkg-configure" dpkg --configure -a || true
    run_live "apt-fix" env DEBIAN_FRONTEND=noninteractive apt-get -f install -y || true

    st WAIT "Updating packages..."
    run_live "apt-update" apt-get update -y -q || { st ERR "apt update failed"; pause; return; }

    st WAIT "Installing base packages (unzip, snapd, python, nginx, curl, jq)..."
    if ! run_live "apt-install" env DEBIAN_FRONTEND=noninteractive apt-get install -y unzip snapd python3 python3-pip python3-venv nginx curl ca-certificates lsb-release software-properties-common jq wget socat gnupg2; then
        run_live "apt-fix" env DEBIAN_FRONTEND=noninteractive apt-get install -y --fix-broken unzip snapd python3-pip python3-venv nginx curl || {
            st ERR "Package install failed — VPS may not support apt deps."
            pause; return
        }
    fi
    st OK "Base packages installed"

    mkdir -p /root/omega-panel
    if [ -f "$DIR/Omega-Panel-V3-main.zip" ]; then
        st WAIT "Extracting Omega Panel V3..."
        run_live "unzip-omega" unzip -o "$DIR/Omega-Panel-V3-main.zip" -d /root/omega-panel || true
    else
        run_dl "Omega Panel V3 zip" "$OMG_ZIP" /tmp/omega.zip || { st ERR "Download failed"; pause; return; }
        st WAIT "Extracting Omega Panel V3..."
        run_live "unzip-omega" unzip -o /tmp/omega.zip -d /root/omega-panel || true
        rm -f /tmp/omega.zip
    fi
    if [ ! -f "$PDIR/app.py" ] || [ ! -f "$PDIR/setup.sh" ]; then
        st ERR "Extract failed — app.py/setup.sh not found"
        st INFO "Fix: rm -rf /root/omega-panel  →  re-run [1] Install"
        pause; return 1
    fi
    st OK "Panel files ready ($PDIR)"

    echo -e "  ${C}◆ OFFICIAL SETUP (LXD + Python 3.10 + venv + deps + database)${NC}"
    st WAIT "Running setup.sh — this takes a few minutes (LXD snap + Ubuntu images)..."
    chmod +x "$PDIR/setup.sh" 2>/dev/null || true
    if run_live "omega-setup" bash "$PDIR/setup.sh"; then
        st OK "Official setup complete"
    else
        st WARN "setup.sh reported errors — auto-repair will fill the gaps next"
    fi

    # ---- Auto-repair: jo bhi missing hai wo khud download/load karke panel chala do ----
    st WAIT "Verifying / repairing dependencies (auto-download)..."

    # 1) python3.10 (panel obfuscated hai = 3.10 hi chahiye)
    if ! command -v python3.10 >/dev/null 2>&1; then
        st INFO "python3.10 missing — installing (deadsnakes)..."
        run_live "deadsnakes" add-apt-repository -y ppa:deadsnakes/ppa || true
        run_live "apt-update2" env DEBIAN_FRONTEND=noninteractive apt-get update -y -q || true
        run_live "py310" env DEBIAN_FRONTEND=noninteractive apt-get install -y python3.10 python3.10-venv python3.10-distutils python3-pip-whl python3-setuptools-whl || true
        if ! command -v python3.10 >/dev/null 2>&1; then
            st ERR "python3.10 unavailable — panel cannot run (needs Python 3.10)"
            st INFO "Fix: add-apt-repository ppa:deadsnakes/ppa -y && apt install python3.10 python3.10-venv"
            pause; return 1
        fi
    fi
    st OK "python3.10 ready"

    # 2) venv (na ho to banao, toota ho to phir se banao)
    if [ ! -x "$PDIR/venv/bin/python" ]; then
        st INFO "venv missing — creating..."
        rm -rf "$PDIR/venv"
        run_live "venv-create" python3.10 -m venv "$PDIR/venv" || true
    fi
    if [ ! -x "$PDIR/venv/bin/python" ]; then
        st ERR "venv creation failed"
        st INFO "Fix: python3.10 -m venv $PDIR/venv"
        pause; return 1
    fi
    st OK "venv ready"

    # 3) pip + python packages (requirements dono) — import check ke saath
    if ! "$PDIR/venv/bin/python" -c "import flask" 2>/dev/null; then
        st INFO "Flask missing — installing requirements..."
        "$PDIR/venv/bin/python" -m pip install --upgrade pip >/dev/null 2>&1 || true
        run_live "pip-req" "$PDIR/venv/bin/python" -m pip install -r "$PDIR/requirements.txt" -r "$PDIR/node_requirements.txt" || true
        if ! "$PDIR/venv/bin/python" -c "import flask" 2>/dev/null; then
            st ERR "Python packages failed to install — panel would crash"
            st INFO "Fix: $PDIR/venv/bin/python -m pip install -r $PDIR/requirements.txt"
            pause; return 1
        fi
    fi
    st OK "Python packages OK (flask import verified)"

    # 4) database (na ho to init karo)
    if [ ! -f "$PDIR/data.db" ]; then
        st INFO "data.db missing — initializing..."
        (cd "$PDIR" && "$PDIR/venv/bin/python" -c "import app; app.init_db()" >/dev/null 2>&1) || true
    fi
    [ -f "$PDIR/data.db" ] && st OK "Database ready" || st WARN "data.db still missing — will try on first run"

    # 5) LXD (VPS create ke liye) — snap se lekar storage pool tak auto-fix
    export PATH="/snap/bin:$PATH"
    if ! command -v lxc >/dev/null 2>&1 && ! [ -x /snap/bin/lxc ]; then
        st INFO "LXD missing — installing snap..."
        run_live "snapd-install" env DEBIAN_FRONTEND=noninteractive apt-get install -y snapd || true
        systemctl enable --now snapd.socket snapd >/dev/null 2>&1 || true
        sleep 3
        run_live "snap-lxd" snap install lxd || run_live "snap-lxd-retry" snap install lxd || st WARN "LXD snap failed — VPS create won't work"
        export PATH="/snap/bin:$PATH"
    fi
    if command -v lxc >/dev/null 2>&1 || [ -x /snap/bin/lxc ]; then
        local i
        for i in $(seq 1 15); do
            lxc version >/dev/null 2>&1 && break
            sleep 2
        done
        if ! lxc storage show default >/dev/null 2>&1; then
            run_live "lxd-init" lxd init --auto || true
            sleep 2
        fi
        lxc storage show default >/dev/null 2>&1 && st OK "LXD storage pool ready" || st WARN "LXD pool missing (run: lxd init --auto)"
        lxc network show lxdbr0 >/dev/null 2>&1 || run_live "lxdbr0" lxc network create lxdbr0 --type=bridge ipv4.address=10.132.115.1/24 ipv4.nat=true ipv6.address=none || true
        lxc remote show images >/dev/null 2>&1 || lxc remote add images https://images.linuxcontainers.org --protocol=simplestreams --public >/dev/null 2>&1 || true
    else
        st WARN "LXD not available — panel chalega but VPS create nahi hoga"
    fi

    st WAIT "Writing systemd service..."
    cat > /etc/systemd/system/$UNIT <<EOF
[Unit]
Description=Omega Panel V3 (LXC VPS Manager) - HAPPY NODE
After=network.target

[Service]
Type=simple
ExecStart=$PDIR/venv/bin/python $PDIR/app.py
WorkingDirectory=$PDIR
Restart=always
RestartSec=3
User=root
Environment=PORT=$OMG_PORT
Environment=HOST=0.0.0.0

[Install]
WantedBy=multi-user.target
EOF

    st WAIT "Configuring Nginx → domain:$OMG_PORT..."
    if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "localhost" ]; then
        cat > /etc/nginx/sites-available/omega-panel.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://127.0.0.1:$OMG_PORT;
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
        ln -sf /etc/nginx/sites-available/omega-panel.conf /etc/nginx/sites-enabled/omega-panel.conf
        nginx -t >/dev/null 2>&1 && systemctl reload nginx 2>/dev/null
        st OK "Nginx: http://$DOMAIN → :$OMG_PORT"
    fi

    st WAIT "Starting service..."
    if [ "$has_sys" = 1 ]; then
        if pgrep -f "$PDIR/app.py" >/dev/null 2>&1; then
            st INFO "Stopping manual app.py process (port $OMG_PORT)..."
            pkill -f "$PDIR/app.py" 2>/dev/null || true
            sleep 1
        fi
        systemctl daemon-reload
        systemctl enable "$UNIT" >/dev/null 2>&1
        systemctl restart "$UNIT"
        local waited=0 _st="" still=""
        while [ "$waited" -lt 15 ]; do
            _st="$(systemctl is-active "$UNIT" 2>/dev/null | grep -m1 -E '^(active|failed|inactive|activating)' || true)"
            case "$_st" in
                failed|inactive) break ;;
                active)
                    sleep 2
                    still="$(systemctl is-active "$UNIT" 2>/dev/null | grep -m1 -E '^(active|failed|inactive|activating)' || true)"
                    if [ "$still" = "active" ]; then _st="active"; break; fi
                    _st="$still" ;;
            esac
            sleep 1; waited=$((waited+3))
        done
        if [ "$_st" = "active" ]; then
            local hc=0 i
            for i in $(seq 1 10); do
                if omega_up; then hc=1; break; fi
                sleep 2
            done
            if [ "$hc" = 1 ]; then
                st OK "Omega Panel V3 installed successfully!"
            else
                st WARN "Service active but port $OMG_PORT not answering yet — check [6] Logs"
            fi
            echo -e "  ${W}URL:${NC}     http://$DOMAIN:$OMG_PORT"
            [ "$DOMAIN" != "localhost" ] && echo -e "  ${W}Nginx:${NC}   http://$DOMAIN"
            echo -e "  ${W}Service:${NC} $UNIT (active)"
            echo -e "  ${W}Path:${NC}    $PDIR"
            show_creds_box "http://$DOMAIN:$OMG_PORT"
            echo -e "  ${SL}Manual test: cd $PDIR && venv/bin/python app.py${NC}"
            if lxc storage show default >/dev/null 2>&1; then
                echo -e "  ${W}LXD:${NC}     storage pool ready (VPS create OK)"
            else
                echo -e "  ${FR}LXD pool missing — VPS create will fail (run: lxd init --auto)${NC}"
            fi
        else
            st ERR "Service failed (state: ${_st:-unknown}) — last journal lines:"
            journalctl -u "$UNIT" -n 12 --no-pager 2>/dev/null | tail -8 | sed 's/^/  /'
            st INFO "Full log: journalctl -u $UNIT -e"
            st INFO "Manual: cd $PDIR && venv/bin/python app.py"
            st INFO "Fix the error above, then re-run [1] Install"
        fi
    else
        st WARN "No systemd — starting in background mode..."
        pkill -f "$PDIR/app.py" 2>/dev/null || true
        cd "$PDIR" && PORT=$OMG_PORT HOST=0.0.0.0 nohup "$PDIR/venv/bin/python" "$PDIR/app.py" >/var/log/omega-panel.log 2>&1 &
        sleep 3
        if pgrep -f "$PDIR/app.py" >/dev/null 2>&1; then
            st OK "Omega Panel running (background mode, no systemd)"
            echo -e "  ${W}URL:${NC}  http://$DOMAIN:$OMG_PORT"
            echo -e "  ${W}Log:${NC}   /var/log/omega-panel.log"
            st INFO "Note: auto-start on reboot not available without systemd"
            show_creds_box "http://$DOMAIN:$OMG_PORT"
        else
            st ERR "Start failed. Check: cat /var/log/omega-panel.log"
        fi
    fi
    pause
}

start_service() {
    show_header
    if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] && systemctl start "$UNIT" 2>/dev/null; then
        sleep 2
        local _st="$(systemctl is-active "$UNIT" 2>/dev/null | grep -m1 -E '^(active|failed|inactive|activating)' || true)"
        if [ "$_st" = "active" ]; then
            st OK "Started (systemd)"
        else
            st ERR "Service crashed after start (state: ${_st:-unknown}) — last journal lines:"
            journalctl -u "$UNIT" -n 12 --no-pager 2>/dev/null | tail -8 | sed 's/^/  /'
        fi
    elif pgrep -f "$PDIR/app.py" >/dev/null 2>&1; then
        st INFO "Already running (background mode)"
    else
        if [ -f "$PDIR/app.py" ] && [ -x "$PDIR/venv/bin/python" ]; then
            cd "$PDIR" && PORT=$OMG_PORT HOST=0.0.0.0 nohup "$PDIR/venv/bin/python" "$PDIR/app.py" >/var/log/omega-panel.log 2>&1 &
            sleep 3
            pgrep -f "$PDIR/app.py" >/dev/null 2>&1 && st OK "Started (background mode)" || st ERR "Failed — see /var/log/omega-panel.log"
        else
            st ERR "Not installed"
        fi
    fi
    pause
}

stop_service() {
    show_header
    local stopped=0
    systemctl stop "$UNIT" 2>/dev/null && stopped=1
    pkill -f "$PDIR/app.py" 2>/dev/null && stopped=1
    [ "$stopped" = 1 ] && st OK "Stopped" || st ERR "Not running / not installed"
    pause
}

restart_service() {
    show_header
    systemctl stop "$UNIT" 2>/dev/null
    pkill -f "$PDIR/app.py" 2>/dev/null
    sleep 1
    if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] && systemctl start "$UNIT" 2>/dev/null; then
        sleep 2
        local _st="$(systemctl is-active "$UNIT" 2>/dev/null | grep -m1 -E '^(active|failed|inactive|activating)' || true)"
        if [ "$_st" = "active" ]; then
            st OK "Restarted (systemd)"
        else
            st ERR "Service crashed after restart (state: ${_st:-unknown}) — last journal lines:"
            journalctl -u "$UNIT" -n 12 --no-pager 2>/dev/null | tail -8 | sed 's/^/  /'
        fi
    elif [ -f "$PDIR/app.py" ] && [ -x "$PDIR/venv/bin/python" ]; then
        cd "$PDIR" && PORT=$OMG_PORT HOST=0.0.0.0 nohup "$PDIR/venv/bin/python" "$PDIR/app.py" >/var/log/omega-panel.log 2>&1 &
        sleep 3
        pgrep -f "$PDIR/app.py" >/dev/null 2>&1 && st OK "Restarted (background mode)" || st ERR "Failed — see /var/log/omega-panel.log"
    else
        st ERR "Not installed"
    fi
    pause
}

service_status() {
    show_header
    echo -e "  ${C}◆ PANEL${NC}"
    if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
        systemctl status "$UNIT" --no-pager -l 2>/dev/null | head -12
    else
        if pgrep -f "$PDIR/app.py" >/dev/null 2>&1; then
            st OK "Running (background) PID: $(pgrep -f "$PDIR/app.py" | head -1)"
        else
            st ERR "Not running"
        fi
    fi
    echo ""
    if omega_up; then st OK "Port $OMG_PORT answering (health OK)"; else st ERR "Port $OMG_PORT not answering"; fi
    ss -tlnp 2>/dev/null | grep ":$OMG_PORT " || echo "  Port $OMG_PORT not listening"
    echo ""
    echo -e "  ${C}◆ NODE AGENT (optional, port $NODE_PORT)${NC}"
    if pgrep -f "node.py --port=$NODE_PORT" >/dev/null 2>&1; then
        st OK "node agent running (PID $(pgrep -f "node.py --port=$NODE_PORT" | head -1))"
    else
        st INFO "node agent not running (menu [8] to start)"
    fi
    pause
}

view_logs() {
    show_header
    st INFO "Last 30 log lines:"
    echo ""
    if journalctl -u "$UNIT" -n 30 --no-pager 2>/dev/null | grep -q .; then
        journalctl -u "$UNIT" -n 30 --no-pager 2>/dev/null
    elif [ -f /var/log/omega-panel.log ]; then
        tail -30 /var/log/omega-panel.log
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
    cat > /etc/nginx/sites-available/omega-panel.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://127.0.0.1:$OMG_PORT;
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
    ln -sf /etc/nginx/sites-available/omega-panel.conf /etc/nginx/sites-enabled/omega-panel.conf
    nginx -t >/dev/null 2>&1 && systemctl reload nginx
    st WAIT "Requesting SSL certificate..."
    run_live "certbot" certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email || st ERR "Certbot failed (DNS not pointing?)."
    st OK "Domain set: https://$DOMAIN → :$OMG_PORT"
    pause
}

node_agent() {
    show_header
    local running=0
    pgrep -f "node.py --port=$NODE_PORT" >/dev/null 2>&1 && running=1
    echo -e "  ${C}◆ NODE AGENT (worker node ke liye, port $NODE_PORT)${NC}"
    if [ "$running" = 1 ]; then st OK "Currently RUNNING (PID $(pgrep -f "node.py --port=$NODE_PORT" | head -1))"; else st INFO "Currently not running"; fi
    echo ""
    echo -e "     ${GR}[1]${NC} Start node agent"
    echo -e "     ${GR}[2]${NC} Stop node agent"
    echo -e "     ${R}[0]${NC} Cancel"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-2):${NC} "
    read -r op || return
    case "$op" in
        1)
            if [ ! -f "$PDIR/node.py" ]; then st ERR "Not installed"; pause; return; fi
            if [ ! -x "$PDIR/venv/bin/python" ]; then st ERR "venv missing — run [1] Install"; pause; return; fi
            st WAIT "Starting node agent..."
            pkill -f "node.py --port=$NODE_PORT" 2>/dev/null || true
            cd "$PDIR" && nohup "$PDIR/venv/bin/python" "$PDIR/node.py" --port=$NODE_PORT --name=node1 >/var/log/omega-node.log 2>&1 &
            sleep 3
            if pgrep -f "node.py --port=$NODE_PORT" >/dev/null 2>&1; then
                st OK "Node agent started (port $NODE_PORT, name node1)"
                echo -e "  ${W}Log:${NC}  /var/log/omega-node.log"
                echo -e "  ${SL}Panel me: Admin → Nodes → register this node${NC}"
            else
                st ERR "Start failed — see /var/log/omega-node.log"
            fi
            ;;
        2)
            pkill -f "node.py --port=$NODE_PORT" 2>/dev/null && st OK "Node agent stopped" || st ERR "Not running"
            ;;
        0) return ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
    pause
}

uninstall_omega() {
    show_header
    echo -e "  ${R}⚠ Delete Omega Panel and all its data (panel DB + instances)?${NC}"
    echo -e "  ${Y}(LXD/images rehenge — sirf panel hatayega)${NC}"
    read -rp "  Proceed? (y/N): " conf
    [[ "$conf" =~ ^[Yy]$ ]] || { st INFO "Cancelled."; pause; return; }
    systemctl stop "$UNIT" 2>/dev/null
    systemctl disable "$UNIT" 2>/dev/null
    pkill -f "$PDIR/app.py" 2>/dev/null || true
    pkill -f "node.py --port=$NODE_PORT" 2>/dev/null || true
    rm -f "/etc/systemd/system/$UNIT"
    systemctl daemon-reload 2>/dev/null || true
    rm -rf /root/omega-panel
    rm -f /etc/nginx/sites-{available,enabled}/omega-panel.conf
    systemctl reload nginx 2>/dev/null || true
    rm -f /var/log/omega-panel.log /var/log/omega-node.log
    st OK "Omega Panel removed."
    pause
}

while true; do
    show_header
    echo -e "  ${C}◆ OMEGA PANEL MANAGEMENT${NC}"
    echo -e "     ${GR}[1]${NC} Install         ${DG}•${NC} Full Setup + LXD + Domain"
    echo -e "     ${GR}[2]${NC} Start           ${DG}•${NC} Start Service"
    echo -e "     ${GR}[3]${NC} Stop            ${DG}•${NC} Stop Service"
    echo -e "     ${GR}[4]${NC} Restart         ${DG}•${NC} Restart Service"
    echo -e "     ${GR}[5]${NC} Status          ${DG}•${NC} Service + Port $OMG_PORT + Node"
    echo -e "     ${GR}[6]${NC} Logs            ${DG}•${NC} View Journal"
    echo -e "     ${GR}[7]${NC} Domain & SSL    ${DG}•${NC} Nginx → :$OMG_PORT"
    echo -e "     ${GR}[8]${NC} Node Agent      ${DG}•${NC} Start/Stop (port $NODE_PORT)"
    echo -e "     ${GR}[9]${NC} Uninstall       ${DG}•${NC} Remove All"
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-9):${NC} "
    read -r choice || exit 0
    case $choice in
        1) install_omega ;;
        2) start_service ;;
        3) stop_service ;;
        4) restart_service ;;
        5) service_status ;;
        6) view_logs ;;
        7) setup_domain ;;
        8) node_agent ;;
        9) uninstall_omega ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
