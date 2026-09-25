#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
source "$ROOT/colors.sh"

STEP=0
TOTAL_STEPS=8
START_TIME=$(date +%s)

st() {
    case $1 in
        OK)   echo -e "  ${G}✓${NC} $2" ;;
        ERR)  echo -e "  ${R}✗${NC} $2" ;;
        INFO) echo -e "  ${C}→${NC} $2" ;;
        WAIT) echo -e "  ${Y}⏳${NC} $2" ;;
        WARN) echo -e "  ${Y}!${NC} $2" ;;
    esac
}
pause() { echo ""; read -rp "  Press Enter to continue... " _; }

print_banner() {
    clear
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     W I N G S   I N S T A L L E R            ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    HAPPY NODE • Pterodactyl Daemon            ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

print_step() {
    STEP=$((STEP + 1))
    echo ""
    echo -e "  ${C}◆${NC} ${W}Step ${STEP}/${TOTAL_STEPS}: $1${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

elapsed() {
    local diff=$(( $(date +%s) - START_TIME ))
    printf "%02d:%02d" $((diff / 60)) $((diff % 60))
}

print_banner
echo -e "  ${DG}OS:${NC} $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo unknown)  ${DG}│${NC}  ${DG}Kernel:${NC} $(uname -r)  ${DG}│${NC}  ${DG}Arch:${NC} $(uname -m)"
echo ""
if [ "$EUID" -ne 0 ]; then
    st ERR "Run as root"
    exit 1
fi
read -rp "  Begin Wings installation? [Y/n]: " yn
[[ "${yn:-y}" =~ ^[Nn]$ ]] && { st INFO "Cancelled"; exit 0; }

print_step "Docker Engine"
if command -v docker >/dev/null 2>&1; then
    st OK "Docker already installed ($(docker --version 2>/dev/null))"
else
    st WAIT "Installing Docker..."
    run_live "docker" bash -c 'curl -sSL https://get.docker.com/ | CHANNEL=stable bash' || st WARN "Docker install may need manual check"
fi
systemctl enable --now docker >/dev/null 2>&1 || true
st OK "Docker service ready"

print_step "ZFS Snapshotter Fix"
ZFS_FSTYPE=$(findmnt -rn -o FSTYPE -T /var/lib/docker 2>/dev/null)
if [ "$ZFS_FSTYPE" = "zfs" ]; then
    st INFO "ZFS detected at /var/lib/docker — configuring fuse-overlayfs"
    if ! command -v fuse-overlayfs >/dev/null 2>&1; then
        st WAIT "Installing fuse-overlayfs..."
        if command -v apt-get >/dev/null 2>&1; then
            run_live "fuse-overlayfs" apt-get install -y fuse-overlayfs
        elif command -v dnf >/dev/null 2>&1; then
            run_live "fuse-overlayfs" dnf install -y fuse-overlayfs
        elif command -v yum >/dev/null 2>&1; then
            run_live "fuse-overlayfs" yum install -y fuse-overlayfs
        elif command -v zypper >/dev/null 2>&1; then
            run_live "fuse-overlayfs" zypper -n install fuse-overlayfs
        else
            st WARN "No supported package manager found for fuse-overlayfs"
        fi
    fi
    if command -v fuse-overlayfs >/dev/null 2>&1; then
        st OK "fuse-overlayfs installed"
    else
        st WARN "fuse-overlayfs not found — may need manual install"
    fi
    DAEMON_JSON="/etc/docker/daemon.json"
    if [ -f "$DAEMON_JSON" ]; then
        cp "$DAEMON_JSON" "${DAEMON_JSON}.bak.$(date +%Y%m%d%H%M%S)"
        st OK "Backed up existing daemon.json"
        if command -v python3 >/dev/null 2>&1; then
            python3 - "$DAEMON_JSON" <<'PYEOF'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except Exception:
    data = {}
data["storage-driver"] = "fuse-overlayfs"
data.setdefault("features", {})["containerd-snapshotter"] = False
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
            st OK "daemon.json updated (storage-driver=fuse-overlayfs, containerd-snapshotter=false)"
        else
            st WARN "python3 missing — writing minimal daemon.json"
            printf '{\n  "storage-driver": "fuse-overlayfs",\n  "features": {\n    "containerd-snapshotter": false\n  }\n}\n' > "$DAEMON_JSON"
            st OK "daemon.json rewritten"
        fi
    else
        mkdir -p /etc/docker
        printf '{\n  "storage-driver": "fuse-overlayfs",\n  "features": {\n    "containerd-snapshotter": false\n  }\n}\n' > "$DAEMON_JSON"
        st OK "daemon.json created"
    fi
    systemctl restart docker
    sleep 2
    STORAGE_DRIVER=$(docker info 2>/dev/null | awk '/Storage Driver:/ {print $3}')
    if [ "$STORAGE_DRIVER" = "fuse-overlayfs" ]; then
        st OK "Docker storage driver is now fuse-overlayfs"
    else
        st WARN "Storage driver is '${STORAGE_DRIVER:-unknown}' — verify manually (docker info)"
    fi
else
    st OK "No ZFS on /var/lib/docker ($ZFS_FSTYPE) — snapshotter fix skipped"
fi

print_step "Kernel Parameters"
GRUB_FILE="/etc/default/grub"
if [ -f "$GRUB_FILE" ]; then
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="swapaccount=1"/' "$GRUB_FILE"
    update-grub >/dev/null 2>&1 || st WARN "update-grub skipped"
    st OK "GRUB updated (swapaccount=1)"
else
    st INFO "GRUB not found — skipped"
fi

print_step "Wings Binary"
mkdir -p /etc/pterodactyl
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l)  ARCH="arm32" ;;
    *) st ERR "Unsupported arch: $ARCH"; pause; exit 1 ;;
esac
st INFO "Architecture: $ARCH"
if [ -f /usr/local/bin/wings ]; then
    st OK "Wings binary already present"
else
    run_dl "Wings linux_$ARCH" \
        "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$ARCH" \
        /usr/local/bin/wings || { st ERR "Download failed"; pause; exit 1; }
fi
chmod u+x /usr/local/bin/wings
st OK "Permissions set — $(/usr/local/bin/wings --version 2>/dev/null || echo wings)"

print_step "Systemd Service"
WINGS_SERVICE_FILE="/etc/systemd/system/wings.service"
if [ -f "$WINGS_SERVICE_FILE" ]; then
    st OK "Service file already exists"
else
    cat > "$WINGS_SERVICE_FILE" <<'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    st OK "Service file created"
fi
systemctl daemon-reload >/dev/null 2>&1
systemctl enable wings >/dev/null 2>&1
st OK "Wings service enabled"

print_step "SSL Certificate"
mkdir -p /etc/certs/wing
if [ -f /etc/certs/wing/fullchain.pem ] && [ -f /etc/certs/wing/privkey.pem ]; then
    st OK "SSL certificates already exist"
else
    st WAIT "Generating self-signed cert (3650 days)..."
    openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
        -subj "/C=NA/ST=NA/L=NA/O=HAPPY NODE/CN=HAPPY NODE Wings" \
        -keyout /etc/certs/wing/privkey.pem -out /etc/certs/wing/fullchain.pem \
        >/dev/null 2>&1
    st OK "Certificate generated"
fi

print_step "Helper Command"
cat > /usr/local/bin/wing <<'EOF'
#!/bin/bash
echo ""
echo "  HAPPY NODE Wings Helper"
echo "  ────────────────────────"
echo "  start    sudo systemctl start wings"
echo "  stop     sudo systemctl stop wings"
echo "  restart  sudo systemctl restart wings"
echo "  status   sudo systemctl status wings"
echo "  logs     sudo journalctl -u wings -f"
echo ""
EOF
chmod +x /usr/local/bin/wing
st OK "Helper installed (wing)"

echo ""
echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
echo -e "  ${CB}│${G}  All steps completed successfully             ${CB}│${NC}"
echo -e "  ${CB}├──────────────────────────────────────────────┤${NC}"
echo -e "  ${CB}│${DG}  Duration${NC}     ${W}$(elapsed)${NC}                         ${CB}│${NC}"
echo -e "  ${CB}│${DG}  Binary${NC}       ${W}/usr/local/bin/wings${NC}           ${CB}│${NC}"
echo -e "  ${CB}│${DG}  Config${NC}       ${W}/etc/pterodactyl${NC}              ${CB}│${NC}"
echo -e "  ${CB}│${DG}  SSL${NC}          ${W}/etc/certs/wing${NC}               ${CB}│${NC}"
echo -e "  ${CB}│${DG}  Service${NC}      ${W}wings ($(systemctl is-enabled wings 2>/dev/null))${NC}  ${CB}│${NC}"
echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
echo ""
st INFO "Start: sudo systemctl start wings"
st INFO "Helper: wing"
st INFO "Logs:  sudo journalctl -u wings -f"
pause
