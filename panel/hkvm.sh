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
PANEL_PORT=8080

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

# Panel code modern JS use karta hai (?., ejs6, uuid14) — Node ≥16 chahiye
node_ok() {
    command -v node >/dev/null 2>&1 || return 1
    local mj; mj="$(node -v 2>/dev/null | sed 's/^v//; s/\..*//')"
    [ -n "$mj" ] && [ "$mj" -ge 16 ] 2>/dev/null
}

ensure_node() {
    if node_ok; then
        st OK "Node $(node -v)"
        if ! command -v npm >/dev/null 2>&1; then
            st WAIT "npm missing — installing..."
            run_live "apt-npm" env DEBIAN_FRONTEND=noninteractive apt-get install -y npm || true
        fi
        if command -v npm >/dev/null 2>&1; then st OK "npm ready"; else st WARN "npm missing — needed only if node_modules incomplete"; fi
        return 0
    fi
    if command -v node >/dev/null 2>&1; then
        st WARN "Node $(node -v 2>/dev/null) too old — panel needs Node ≥16"
    else
        st INFO "Node.js not installed"
    fi
    st WAIT "Installing Node.js 20 (NodeSource)..."
    run_live "nodesource-dl" curl -fsSL https://deb.nodesource.com/setup_20.x -o /tmp/nodesource_setup.sh || true
    if [ -s /tmp/nodesource_setup.sh ]; then
        run_live "nodesource-setup" bash /tmp/nodesource_setup.sh || true
        # distro libnode-dev /usr/include/node ki files own karta hai → force-overwrite warna dpkg conflict
        run_live "apt-node20" env DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-overwrite" install -y nodejs || true
    fi
    if ! node_ok && [ -s /tmp/nodesource_setup.sh ]; then
        # pehla try fail (conflict/half-config state) → clean karke retry
        st INFO "Cleaning conflicting distro packages (libnode-dev)..."
        run_live "dpkg-fix" dpkg --configure -a || true
        run_live "apt-node-rm" env DEBIAN_FRONTEND=noninteractive apt-get remove -y libnode-dev nodejs npm node-nopt node-tar node-which || true
        run_live "apt-node20-retry" env DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-overwrite" install -y nodejs || true
    fi
    if node_ok; then
        st OK "Node $(node -v) ready"
        if command -v npm >/dev/null 2>&1; then st OK "npm ready"; else st WARN "npm missing — rebuild step will be skipped"; fi
        return 0
    fi
    st ERR "Node.js ≥16 could not be installed"
    st INFO "Manual fix: dpkg --configure -a && apt-get -f install -y && apt remove -y libnode-dev nodejs npm"
    st INFO "then: curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt install -y nodejs"
    st INFO "Then re-run [1] Install"
    return 1
}

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

fade_in() {
    local line="$1"
    local i
    for ((i=0; i<${#line}; i++)); do
        printf "%s" "${line:i:1}"
        sleep 0.012
    done
    printf "\n"
}

# systemd state pehle: crash-loop ko kabhi RUNNING mat dikhao
svc_display_state() {
    # $1=unit  $2=pgrep-pattern
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
    case "$(svc_display_state hkvm.service "hkvm/hkvm/app.js|node app.js" /root/hkvm/hkvm)" in
        RUNNING)   status="${G}● RUNNING${NC}" ;;
        CRASH-LOOP) status="${R}● CRASH-LOOP — see menu [5]/[6]${NC}" ;;
        STARTING)  status="${Y}● STARTING…${NC}" ;;
        FAILED)    status="${R}● FAILED — see menu [5]/[6]${NC}" ;;
        STOPPED)   status="${Y}● INSTALLED (stopped)${NC}" ;;
        PARTIAL)   status="${R}● PARTIAL — run Install again${NC}" ;;
    esac
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}      H K V M   P A N E L                     ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    QEMU/KVM Manager  Port $PANEL_PORT               ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${W}Status:${NC}  $status  ${DG}│${NC}  ${W}Port:${NC} $PANEL_PORT"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

vps_check() {
    local has_apt=0 has_node=0 has_sys=0 has_kvm=0 has_npm=0
    local critical_ok=1 warn_ok=1 reasons=()
    local arch virt free_mb

    command -v apt-get >/dev/null 2>&1 && has_apt=1
    command -v node >/dev/null 2>&1 && has_node=1
    command -v npm >/dev/null 2>&1 && has_npm=1
    if command -v systemctl >/dev/null 2>&1 && [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then
        has_sys=1
    fi
    { [ -e /dev/kvm ] || grep -Eq 'vmx|svm' /proc/cpuinfo 2>/dev/null; } && has_kvm=1
    arch="$(uname -m 2>/dev/null || echo unknown)"
    virt="$(systemd-detect-virt 2>/dev/null || echo unknown)"

    echo -e "  ${C}◆ VPS SUPPORT CHECK${NC}"
    if [ "$has_apt" = 1 ]; then st OK "OS tools (apt)"; else st ERR "No apt-get (Debian/Ubuntu)"; critical_ok=0; reasons+=("apt-get missing"); fi
    if [ "$has_node" = 1 ]; then
        if node_ok; then st OK "Node.js $(node -v)"; else st INFO "Node.js $(node -v 2>/dev/null) — will upgrade to Node 20"; fi
    else
        st INFO "Node.js missing (will install)"
    fi
    if [ "$has_npm" = 1 ]; then st OK "npm"; else st INFO "npm missing (will install)"; fi
    if [ "$has_sys" = 1 ]; then st OK "systemd (PID 1)"; else st ERR "systemd not running"; critical_ok=0; reasons+=("systemd not PID 1"); fi
    if [ "$arch" = "x86_64" ] || [ "$arch" = "amd64" ]; then st OK "Arch: $arch"; else st WARN "Arch: $arch"; warn_ok=0; fi
    if [ "$has_kvm" = 1 ]; then st OK "KVM / virt (QEMU)"; else st WARN "No /dev/kvm — VM create may fail"; warn_ok=0; fi
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

install_hkvm() {
    show_header
    # guard sirf tab skip jab service STABLY active ho — crash-loop me re-install hi repair hai
    local _gst=""
    [ -f /etc/systemd/system/hkvm.service ] && _gst="$(systemctl is-active hkvm.service 2>/dev/null || true)"
    if [ -d "/root/hkvm/hkvm" ] && { [ "$_gst" = "active" ] || { [ -z "$_gst" ] && pgrep -f "hkvm/hkvm/app.js|node app.js" >/dev/null 2>&1; }; }; then
        st OK "HKVM Panel already installed & running."
        pause; return
    fi

    vps_check || { pause; return; }

    echo -e "  ${C}◆ DOMAIN SETUP${NC}"
    read -rp "  Enter your domain (or IP) [localhost]: " DOMAIN
    DOMAIN="${DOMAIN:-localhost}"
    st INFO "Domain: $DOMAIN  →  http://$DOMAIN:$PANEL_PORT"
    echo ""

    # purani failed run apt ko broken state me chhod sakti hai (held packages) — pehle repair
    st WAIT "Repairing apt state (if a previous install failed)..."
    run_live "dpkg-configure" dpkg --configure -a || true
    run_live "apt-fix" env DEBIAN_FRONTEND=noninteractive apt-get -f install -y || true

    st WAIT "Updating packages..."
    run_live "apt-update" apt-get update -y -q || { st ERR "apt update failed"; pause; return; }

    # nodejs/npm yahan MAKSUD se NAHI — distro npm ke node-* deps nodesource se tangle hote hain.
    # Node 20 (NodeSource) ke saath npm bundled aata hai; ensure_node ye handle karta hai
    st WAIT "Installing dependencies (qemu, unzip, nginx)..."
    if ! run_live "apt-install" env DEBIAN_FRONTEND=noninteractive apt-get install -y unzip curl ca-certificates nginx qemu-system-x86 qemu-utils; then
        run_live "apt-fix2" env DEBIAN_FRONTEND=noninteractive apt-get -f install -y || true
        run_live "apt-retry" env DEBIAN_FRONTEND=noninteractive apt-get install -y --fix-broken unzip curl nginx qemu-system-x86 || {
            st ERR "Package install failed"
            st INFO "Try: dpkg --configure -a && apt-get -f install -y"
            st INFO "then re-run [1] Install"
            pause; return
        }
    fi
    ensure_node || { pause; return; }
    command -v qemu-system-x86_64 >/dev/null 2>&1 && st OK "QEMU ready" || st WARN "QEMU missing — VM create may fail"

    mkdir -p /root/hkvm
    if [ -f "$DIR/hkvm.zip" ]; then
        st WAIT "Extracting HKVM Panel..."
        run_live "unzip-hkvm" unzip -o "$DIR/hkvm.zip" -d /root/hkvm
        local uz=$?
    else
        run_dl "HKVM Panel zip" "$HN_BASE_URL/panel/hkvm.zip" /tmp/hkvm.zip
        local dl=$?
        if [ "$dl" = 0 ]; then
            run_live "unzip-hkvm" unzip -o /tmp/hkvm.zip -d /root/hkvm
            local uz=$?
        else
            local uz=1
        fi
    fi
    # asli proof = app.js file, unzip rc nahi (purane zip warning par rc=1 deti thi)
    if [ ! -f /root/hkvm/hkvm/app.js ]; then
        st ERR "Extract failed — app.js not found"
        st INFO "Fix: rm -rf /root/hkvm  →  re-run [1] Install"
        pause; return 1
    fi
    st OK "Panel files ready (/root/hkvm/hkvm)"

    # purana Node `?.` parse nahi kar pata → SyntaxError → crash-loop. Service start se pehle pakdo
    st WAIT "Syntax check (Node $(node -v 2>/dev/null))..."
    local sf s_out
    for sf in /root/hkvm/hkvm/app.js /root/hkvm/hkvm/licenses.js; do
        [ -f "$sf" ] || continue
        if ! s_out="$(node --check "$sf" 2>&1)"; then
            st ERR "Syntax error: ${sf##*/}"
            printf '%s\n' "$s_out" | sed 's/^/       │ /'
            st INFO "Node too old / file corrupted — re-run [1] Install"
            pause; return 1
        fi
    done
    st OK "Syntax OK"

    if [ -d /root/hkvm/hkvm/node_modules ] && [ -n "$(ls -A /root/hkvm/hkvm/node_modules 2>/dev/null)" ]; then
        st OK "node_modules present"
        # node version badla ho to native sqlite3 rebuild karo (ABI match)
        if ! command -v npm >/dev/null 2>&1; then
            st WARN "npm missing — skipping rebuild (require check will verify bundled modules)"
        elif ! (cd /root/hkvm/hkvm && run_live "npm-rebuild" npm rebuild sqlite3); then
            st WARN "npm rebuild sqlite3 failed — next check will decide"
        fi
    else
        if ! command -v npm >/dev/null 2>&1; then
            st WAIT "npm missing — installing..."
            run_live "apt-npm" env DEBIAN_FRONTEND=noninteractive apt-get install -y npm || true
        fi
        if ! command -v npm >/dev/null 2>&1; then
            st ERR "npm required (node_modules empty) but not installable"
            st INFO "Try: dpkg --configure -a && apt-get -f install -y && apt install -y npm"
            st INFO "then re-run [1] Install"
            pause; return 1
        fi
        st WAIT "npm install..."
        if ! (cd /root/hkvm/hkvm && run_live "npm" npm install --omit=dev --no-audit --no-fund); then
            st ERR "npm install failed — see error above"
            st INFO "Retry: cd /root/hkvm/hkvm && npm install --omit=dev"
            st INFO "then re-run [1] Install from this menu"
            pause; return 1
        fi
        if [ -z "$(ls -A /root/hkvm/hkvm/node_modules 2>/dev/null)" ]; then
            st ERR "node_modules still empty — panel would crash"
            st INFO "Retry: cd /root/hkvm/hkvm && npm install --omit=dev"
            pause; return 1
        fi
        st OK "npm deps installed"
    fi

    # final gate: native module isi Node par load ho sake — warna service crash-loop
    if [ "${HN_SKIP_NATIVE_CHECK:-0}" != 1 ]; then
        st WAIT "Checking native modules (sqlite3)..."
        if ! (cd /root/hkvm/hkvm && node -e "require('/root/hkvm/hkvm/node_modules/sqlite3');require('/root/hkvm/hkvm/node_modules/express')"); then
            st ERR "Modules broken for Node $(node -v 2>/dev/null) — panel would crash"
            st INFO "Fix: cd /root/hkvm/hkvm && rm -rf node_modules && npm install --omit=dev"
            st INFO "Then re-run [1] Install"
            pause; return 1
        fi
        st OK "Native modules OK"
    fi

    st WAIT "Writing systemd service..."
    cat > /etc/systemd/system/hkvm.service <<EOF
[Unit]
Description=HKVM Panel - HAPPY NODE
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/node /root/hkvm/hkvm/app.js
WorkingDirectory=/root/hkvm/hkvm
Restart=always
RestartSec=3
User=root
Environment=PORT=$PANEL_PORT
Environment=HOST=0.0.0.0
Environment=PANEL_NAME=HAPPY NODE
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

    st WAIT "Configuring Nginx → domain:$PANEL_PORT..."
    if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "localhost" ]; then
        cat > /etc/nginx/sites-available/hkvm.conf <<EOF
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
    }
}
EOF
        ln -sf /etc/nginx/sites-available/hkvm.conf /etc/nginx/sites-enabled/hkvm.conf
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
        systemctl enable hkvm.service >/dev/null 2>&1
        systemctl restart hkvm.service
        # is-active --quiet crash-loop me bhi 0 deta hai — state text + stability check chahiye
        local waited=0 _st="" still=""
        while [ "$waited" -lt 15 ]; do
            _st="$(systemctl is-active hkvm.service 2>/dev/null || true)"
            case "$_st" in
                failed|inactive) break ;;
                active)
                    sleep 2
                    still="$(systemctl is-active hkvm.service 2>/dev/null || true)"
                    if [ "$still" = "active" ]; then _st="active"; break; fi
                    _st="$still" ;;
            esac
            sleep 1; waited=$((waited+3))
        done
        if [ "$_st" = "active" ]; then
            st OK "HKVM Panel installed successfully!"
            echo -e "  ${W}URL:${NC}     http://$DOMAIN:$PANEL_PORT"
            [ "$DOMAIN" != "localhost" ] && echo -e "  ${W}Nginx:${NC}   http://$DOMAIN"
            echo -e "  ${W}Service:${NC} hkvm.service (active)"
            echo -e "  ${W}Path:${NC}    /root/hkvm/hkvm"
            if ss -ltn 2>/dev/null | grep -q ":$PANEL_PORT "; then
                st OK "Port $PANEL_PORT listening"
            else
                st WARN "Port $PANEL_PORT not detected yet — check menu [5]"
            fi
            show_creds_box "HKVM" "http://$DOMAIN:$PANEL_PORT"
        else
            st ERR "Service failed (state: ${_st:-unknown}) — last journal lines:"
            journalctl -u hkvm.service -n 12 --no-pager 2>/dev/null | tail -8 | sed 's/^/  /'
            st INFO "Full log: journalctl -u hkvm.service -e"
            st INFO "Manual: cd /root/hkvm/hkvm && node app.js"
            st INFO "Fix the error above, then re-run [1] Install"
        fi
    else
        st WARN "No systemd — starting in background mode..."
        pkill -f "/root/hkvm/hkvm/app.js" 2>/dev/null || true
        (cd /root/hkvm/hkvm && PORT=$PANEL_PORT HOST=0.0.0.0 nohup node app.js >/var/log/hkvm.log 2>&1 &)
        sleep 3
        if pgrep -f "hkvm/hkvm/app.js|node app.js" >/dev/null 2>&1; then
            st OK "HKVM Panel running (background mode, no systemd)"
            echo -e "  ${W}URL:${NC}  http://$DOMAIN:$PANEL_PORT"
            echo -e "  ${W}Log:${NC}   /var/log/hkvm.log"
            st INFO "Note: auto-start on reboot needs systemd"
            show_creds_box "HKVM" "http://$DOMAIN:$PANEL_PORT"
        else
            st ERR "Start failed — last log lines:"
            tail -8 /var/log/hkvm.log 2>/dev/null | sed 's/^/  /'
            st INFO "Fix the error above, then re-run [1] Install"
        fi
    fi
    pause
}

start_service() {
    show_header
    if command -v systemctl >/dev/null 2>&1 && systemctl start hkvm.service 2>/dev/null; then
        sleep 2
        local _st="$(systemctl is-active hkvm.service 2>/dev/null || true)"
        if [ "$_st" = "active" ]; then
            st OK "Started (systemd)"
        else
            st ERR "Service crashed after start (state: ${_st:-unknown}) — last journal lines:"
            journalctl -u hkvm.service -n 12 --no-pager 2>/dev/null | tail -8 | sed 's/^/  /'
        fi
    elif pgrep -f "hkvm/hkvm/app.js|node app.js" >/dev/null 2>&1; then
        st INFO "Already running (background mode)"
    else
        if [ -f /root/hkvm/hkvm/app.js ]; then
            (cd /root/hkvm/hkvm && PORT=$PANEL_PORT HOST=0.0.0.0 nohup node app.js >/var/log/hkvm.log 2>&1 &)
            sleep 2
            pgrep -f "hkvm/hkvm/app.js|node app.js" >/dev/null 2>&1 && st OK "Started (background mode)" || st ERR "Failed — /var/log/hkvm.log"
        else
            st ERR "Not installed"
        fi
    fi
    pause
}

stop_service() {
    show_header
    local stopped=0
    systemctl stop hkvm.service 2>/dev/null && stopped=1
    pkill -f "/root/hkvm/hkvm/app.js" 2>/dev/null && stopped=1
    [ "$stopped" = 1 ] && st OK "Stopped" || st ERR "Not running / not installed"
    pause
}

restart_service() {
    show_header
    systemctl stop hkvm.service 2>/dev/null
    pkill -f "/root/hkvm/hkvm/app.js" 2>/dev/null
    sleep 1
    if command -v systemctl >/dev/null 2>&1 && [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ] && systemctl start hkvm.service 2>/dev/null; then
        sleep 2
        local _st="$(systemctl is-active hkvm.service 2>/dev/null || true)"
        if [ "$_st" = "active" ]; then
            st OK "Restarted (systemd)"
        else
            st ERR "Service crashed after restart (state: ${_st:-unknown}) — last journal lines:"
            journalctl -u hkvm.service -n 12 --no-pager 2>/dev/null | tail -8 | sed 's/^/  /'
        fi
    elif [ -f /root/hkvm/hkvm/app.js ]; then
        (cd /root/hkvm/hkvm && PORT=$PANEL_PORT HOST=0.0.0.0 nohup node app.js >/var/log/hkvm.log 2>&1 &)
        sleep 2
        pgrep -f "hkvm/hkvm/app.js|node app.js" >/dev/null 2>&1 && st OK "Restarted (background mode)" || st ERR "Failed — /var/log/hkvm.log"
    else
        st ERR "Not installed"
    fi
    pause
}

service_status() {
    show_header
    if command -v systemctl >/dev/null 2>&1 && [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then
        systemctl status hkvm.service --no-pager -l 2>/dev/null | head -15
    else
        if pgrep -f "hkvm/hkvm/app.js|node app.js" >/dev/null 2>&1; then
            st OK "Running (background) PID: $(pgrep -f 'hkvm/hkvm/app.js|node app.js' | head -1)"
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
    if journalctl -u hkvm.service -n 30 --no-pager 2>/dev/null; then
        :
    elif [ -f /var/log/hkvm.log ]; then
        tail -30 /var/log/hkvm.log
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
    cat > /etc/nginx/sites-available/hkvm.conf <<EOF
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
    }
}
EOF
    ln -sf /etc/nginx/sites-available/hkvm.conf /etc/nginx/sites-enabled/hkvm.conf
    nginx -t >/dev/null 2>&1 && systemctl reload nginx
    st WAIT "Requesting SSL certificate..."
    run_live "certbot" certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email || st ERR "Certbot failed (DNS not pointing?)."
    st OK "Domain set: https://$DOMAIN → :$PANEL_PORT"
    pause
}

uninstall_hkvm() {
    show_header
    echo -e "  ${R}⚠ Delete HKVM Panel and all data?${NC}"
    read -rp "  Proceed? (y/N): " conf
    [[ "$conf" =~ ^[Yy]$ ]] || { st INFO "Cancelled."; pause; return; }
    systemctl stop hkvm.service 2>/dev/null
    systemctl disable hkvm.service 2>/dev/null
    pkill -f "/root/hkvm/hkvm/app.js" 2>/dev/null
    rm -f /etc/systemd/system/hkvm.service
    systemctl daemon-reload 2>/dev/null
    rm -rf /root/hkvm
    rm -f /etc/nginx/sites-available/hkvm.conf /etc/nginx/sites-enabled/hkvm.conf
    systemctl reload nginx 2>/dev/null
    st OK "HKVM Panel removed."
    pause
}

while true; do
    show_header
    echo -e "  ${C}◆ HKVM PANEL MANAGEMENT${NC}"
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
        1) install_hkvm ;;
        2) start_service ;;
        3) stop_service ;;
        4) restart_service ;;
        5) service_status ;;
        6) view_logs ;;
        7) setup_domain ;;
        8) uninstall_hkvm ;;
        0) dots_load "Returning" 2; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
