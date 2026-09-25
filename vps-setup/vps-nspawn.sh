#!/bin/bash
set -uo pipefail

# =============================
# HAPPY-CMD systemd-nspawn VM Manager
# =============================

R=$'\033[1;31m'
G=$'\033[1;32m'
Y=$'\033[1;33m'
B=$'\033[1;34m'
M=$'\033[1;35m'
C=$'\033[1;36m'
W=$'\033[1;37m'
DG=$'\033[2m'
NC=$'\033[0m'
CB=$'\033[1;96m'
GR=$'\033[1;92m'
VM_DIR="${VM_DIR:-$HOME/vms-nspawn}"
NSPAWN_DIR="${NSPAWN_DIR:-/var/lib/machines}"

run_live() {
    local msg="$1"; shift
    local log; log="$(mktemp /tmp/hn_live.XXXXXX)"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0 rc line
    "$@" >"$log" 2>&1 &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        line=$(grep -E '^(Get:|Hit:|Unpacking:|Setting up:|Selecting:|Preparing:|Downloading:|Extracting:|Processing:|Building:|Importing:)' "$log" 2>/dev/null | tail -1)
        [ -z "$line" ] && line=$(tail -1 "$log" 2>/dev/null)
        line="${line//[$'\r\n']/}"
        if [ ${#line} -gt 56 ]; then line="…${line: -55}"; fi
        printf "\r   ${C}%s${NC} %-56s" "${frames[i]}" "$line"
        i=$(( (i+1) % ${#frames[@]} ))
        sleep 0.12
    done
    wait "$pid"; rc=$?
    printf "\r\033[K"
    rm -f "$log"
    return $rc
}

hdr() {
    clear
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     ██╗  ██╗ █████╗ ██╗   ██╗██████╗        ${CB}│${NC}"
    echo -e "  ${CB}│${W}     ██║  ██║██╔══██╗██║   ██║██╔══██╗       ${CB}│${NC}"
    echo -e "  ${CB}│${GR}     ███████║███████║██║   ██║██████╔╝       ${CB}│${NC}"
    echo -e "  ${CB}│${GR}     ██╔══██║██╔══██║██║   ██║██╔═══╝        ${CB}│${NC}"
    echo -e "  ${CB}│${Y}     ██║  ██║██║  ██║╚██████╔╝██║            ${CB}│${NC}"
    echo -e "  ${CB}│${Y}     ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝            ${CB}│${NC}"
    echo -e "  ${CB}│${DG}       HAPPY  NODE  •  NSPAWN  MODE           ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    local total=0 running=0
    if command -v machinectl &>/dev/null; then
        total=$(machinectl list --no-legend 2>/dev/null | wc -l)
        running=$(machinectl list --no-legend 2>/dev/null | grep -c running 2>/dev/null || echo 0)
    fi
    echo -e "  ${DG}Mode:${NC} ${C}NSPAWN${NC}  ${DG}│${NC}  ${DG}Running:${NC} ${G}${running}${NC}${DG}/${NC}${total}  ${DG}│${NC}  ${DG}Dir:${NC} $NSPAWN_DIR"
}

st() {
    local t=$1; local msg=$2
    case $t in
        I) echo -e "  ${B}→${NC} $msg" ;;
        W) echo -e "  ${Y}!${NC} $msg" ;;
        E) echo -e "  ${R}✗${NC} $msg" ;;
        S) echo -e "  ${G}✓${NC} $msg" ;;
        Q) echo -ne "  ${C}?${NC} $msg" ;;
    esac
}

vd() {
    local t=$1 v=$2
    case $t in
        number) [[ "$v" =~ ^[0-9]+$ ]] || { st E "Must be a number"; return 1; } ;;
        port)   [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge 23 ] && [ "$v" -le 65535 ] || { st E "Port 23-65535"; return 1; } ;;
        name)   [[ "$v" =~ ^[a-zA-Z0-9_-]+$ ]] || { st E "Letters, numbers, - and _ only"; return 1; } ;;
    esac
    return 0
}

chk_deps() {
    if [ "$EUID" -ne 0 ]; then
        st E "Run as root (nspawn needs privileges)"
        return 1
    fi
    local deps=("systemd-nspawn")
    local miss=()
    for d in "${deps[@]}"; do command -v "$d" &>/dev/null || miss+=("$d"); done
    if [ ${#miss[@]} -ne 0 ]; then
        st I "Missing: ${miss[*]}"
        echo ""
        if command -v apt-get &>/dev/null; then
            run_live "apt-update" apt-get update -y -q || true
            run_live "apt-install" env DEBIAN_FRONTEND=noninteractive apt-get install -y systemd-container
        elif command -v yum &>/dev/null; then
            run_live "yum-install" yum install -y systemd-container
        fi
        command -v systemd-nspawn &>/dev/null || { st E "systemd-nspawn not available"; return 1; }
    fi
    command -v debootstrap &>/dev/null || {
        st I "Installing debootstrap..."
        if command -v apt-get &>/dev/null; then
            run_live "debootstrap" env DEBIAN_FRONTEND=noninteractive apt-get install -y debootstrap
        fi
    }
    mkdir -p "$NSPAWN_DIR" "$VM_DIR"
}

get_list() {
    find "$VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

is_running() {
    local n=$1
    machinectl show "$n" 2>/dev/null | grep -q "State=running" && return 0
    pgrep -f "systemd-nspawn.*$NSPAWN_DIR/$n" &>/dev/null
}

load_cfg() {
    local n=$1 f="$VM_DIR/$1.conf"
    [ -f "$f" ] || { st E "Config not found: $n"; return 1; }
    unset VM_NAME OS_TYPE DISTRO CODENAME HOSTNAME USERNAME PASSWORD SSH_PORT MACHINEDIR CREATED
    source "$f"
}

save_cfg() {
    cat > "$VM_DIR/$VM_NAME.conf" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
DISTRO="$DISTRO"
CODENAME="$CODENAME"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
SSH_PORT="$SSH_PORT"
MACHINEDIR="$MACHINEDIR"
CREATED="$CREATED"
EOF
    st S "Config saved: $VM_DIR/$VM_NAME.conf"
}

declare -A OS_OPTS=(
    ["Debian 12 (Bookworm)"]="debian|bookworm|debian12"
    ["Debian 13 (Trixie)"]="debian|trixie|debian13"
    ["Ubuntu 22.04 (Jammy)"]="ubuntu|jammy|ubuntu22"
    ["Ubuntu 24.04 (Noble)"]="ubuntu|noble|ubuntu24"
)

create_vm() {
    echo ""
    st I "Select OS:"
    local opts=() i=1
    for os in "${!OS_OPTS[@]}"; do
        echo "    $i) $os"
        opts[$i]="$os"
        ((i++))
    done
    echo ""
    while true; do
        read -p "$(st Q "  OS choice (1-$((i-1))): ")" c
        [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -lt "$i" ] && break
        st E "Invalid"
    done
    local os="${opts[$c]}"
    IFS='|' read -r DISTRO CODENAME DEF_HOST <<< "${OS_OPTS[$os]}"
    OS_TYPE="$os"

    while true; do
        read -p "$(st Q "  Machine name [$DEF_HOST]: ")" VM_NAME
        VM_NAME="${VM_NAME:-$DEF_HOST}"
        vd name "$VM_NAME" && { [ -d "$NSPAWN_DIR/$VM_NAME" ] && st E "Exists" || break; }
    done
    while true; do
        read -p "$(st Q "  Hostname [$VM_NAME]: ")" HOSTNAME
        HOSTNAME="${HOSTNAME:-$VM_NAME}"
        vd name "$HOSTNAME" && break
    done
    while true; do
        read -p "$(st Q "  Username [root]: ")" USERNAME
        USERNAME="${USERNAME:-root}"
        break
    done
    while true; do
        read -s -p "$(st Q "  Password [root]: ")" PASSWORD; echo
        PASSWORD="${PASSWORD:-root}"
        [ -n "$PASSWORD" ] && break
    done
    while true; do
        read -p "$(st Q "  SSH port [2222]: ")" SSH_PORT
        SSH_PORT="${SSH_PORT:-2222}"
        vd port "$SSH_PORT" && { ss -tln 2>/dev/null | grep -q ":$SSH_PORT " && st E "Port in use" || break; }
    done

    MACHINEDIR="$NSPAWN_DIR/$VM_NAME"
    CREATED="$(date)"

    if [ -d "$MACHINEDIR" ] && [ -f "$MACHINEDIR/etc/os-release" ]; then
        st W "Directory exists — reusing base image"
    else
        st I "Bootstrapping $DISTRO $CODENAME (this may take a few minutes)..."
        echo ""
        if [ "$DISTRO" = "debian" ]; then
            run_live "debootstrap" debootstrap --variant=minbase "$CODENAME" "$MACHINEDIR" http://deb.debian.org/debian || {
                st E "debootstrap failed"; return 1
            }
        else
            run_live "debootstrap" debootstrap --variant=minbase "$CODENAME" "$MACHINEDIR" http://archive.ubuntu.com/ubuntu || {
                st E "debootstrap failed"; return 1
            }
        fi
    fi

    echo "$HOSTNAME" > "$MACHINEDIR/etc/hostname"
    cat > "$MACHINEDIR/etc/hosts" <<EOF
127.0.0.1 localhost $HOSTNAME
::1       localhost $HOSTNAME
EOF
    if [ ! -s "$MACHINEDIR/etc/resolv.conf" ]; then
        echo "nameserver 8.8.8.8" > "$MACHINEDIR/etc/resolv.conf"
    fi

    st I "Configuring base system..."
    systemd-nspawn -D "$MACHINEDIR" -b /bin/bash -c "
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y -q 2>/dev/null
        apt-get install -y openssh-server sudo procps 2>/dev/null || true
        mkdir -p /run/sshd
        echo 'root:$PASSWORD' | chpasswd
        if [ '$USERNAME' != 'root' ]; then
            useradd -m -s /bin/bash '$USERNAME' 2>/dev/null || true
            echo '$USERNAME:$PASSWORD' | chpasswd
            usermod -aG sudo '$USERNAME' 2>/dev/null || true
        fi
        sed -i 's/^#*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null
        sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
        systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true
    " 2>/dev/null || st WARN "Base config had warnings (checking...)"

    save_cfg
    st S "Machine '$VM_NAME' created"
    st I "Login: $USERNAME / $PASSWORD"
    st I "Start: option [2] then ssh -p $SSH_PORT $USERNAME@localhost"
}

start_vm() {
    local n=$1
    load_cfg "$n" || return 1
    if is_running "$n"; then
        st W "Already running"; return 0
    fi
    st I "Starting: $n"
    run_live "nspawn-start" systemd-nspawn -D "$MACHINEDIR" --boot \
        --machine "$n" \
        -p "tcp::$SSH_PORT:22" \
        --as-pid2 &
    local bg_pid=$!
    sleep 3
    if is_running "$n"; then
        st S "Started: $n"
        st I "SSH: ssh -p $SSH_PORT $USERNAME@localhost"
        st I "Pass: $PASSWORD"
    else
        st W "Checking status..."
        machinectl status "$n" 2>/dev/null | head -5 || true
        st I "Trying machinectl start..."
        machinectl start "$n" 2>/dev/null || true
        sleep 2
        is_running "$n" && st S "Started: $n" || st E "Start failed — check logs"
    fi
}

stop_vm() {
    local n=$1
    load_cfg "$n" 2>/dev/null || true
    if is_running "$n"; then
        st I "Stopping: $n"
        machinectl poweroff "$n" 2>/dev/null || true
        sleep 2
        is_running "$n" && { pkill -f "systemd-nspawn.*$NSPAWN_DIR/$n" 2>/dev/null; sleep 1; }
        is_running "$n" && { pkill -9 -f "systemd-nspawn.*$NSPAWN_DIR/$n" 2>/dev/null; sleep 1; }
        is_running "$n" && { st E "Failed"; return 1; }
        st S "Stopped"
    else
        st I "Not running"
    fi
}

attach_vm() {
    local n=$1
    load_cfg "$n" || return 1
    if ! is_running "$n"; then
        st W "Machine not running — starting..."
        start_vm "$n" || return 1
        sleep 2
    fi
    st I "Attaching to: $n"
    st I "Type 'exit' to leave"
    echo ""
    systemd-nspawn -D "$MACHINEDIR" --machine "$n" -b /bin/bash 2>/dev/null || \
        machinectl shell "$n" 2>/dev/null || true
    echo ""
    read -p "   Press Enter..."
}

run_cmd_vm() {
    local n=$1
    load_cfg "$n" || return 1
    if ! is_running "$n"; then
        st E "Machine not running"; return 1
    fi
    read -p "$(st Q '  Command: ')" cmd
    [ -z "$cmd" ] && return
    echo ""
    systemd-nspawn -D "$MACHINEDIR" --machine "$n" /bin/bash -c "$cmd" 2>/dev/null || \
        machinectl shell "$n" /bin/bash -c "$cmd" 2>/dev/null || true
    echo ""
    read -p "   Press Enter..."
}

delete_vm() {
    local n=$1
    st W "Delete '$n' and ALL rootfs data?"
    read -p "$(st Q 'Confirm (y/N): ')" -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || { st I "Cancelled"; return; }
    load_cfg "$n" 2>/dev/null || true
    is_running "$n" && { machinectl poweroff "$n" 2>/dev/null; sleep 2; }
    is_running "$n" && { pkill -9 -f "systemd-nspawn.*$NSPAWN_DIR/$n" 2>/dev/null; sleep 1; }
    machinectl remove "$n" 2>/dev/null || rm -rf "$NSPAWN_DIR/$n" 2>/dev/null
    rm -f "$VM_DIR/$n.conf" 2>/dev/null
    st S "Deleted: $n"
}

show_info() {
    local n=$1
    load_cfg "$n" || return 1
    local st_run="${R}stopped${NC}"
    is_running "$n" && st_run="${G}running${NC}"
    local size="?"
    [ -d "$MACHINEDIR" ] && size=$(du -sh "$MACHINEDIR" 2>/dev/null | awk '{print $1}')
    echo ""
    echo -e "  ${CB}┌─── ${W}$n${CB} ──────────────────────────────────────┐${NC}"
    echo -e "  ${CB}│${NC} ${DG}OS:${NC}       $OS_TYPE"
    echo -e "  ${CB}│${NC} ${DG}Host:${NC}     $HOSTNAME"
    echo -e "  ${CB}│${NC} ${DG}User:${NC}     $USERNAME"
    echo -e "  ${CB}│${NC} ${DG}Pass:${NC}     $PASSWORD"
    echo -e "  ${CB}│${NC} ${DG}SSH Port:${NC} $SSH_PORT"
    echo -e "  ${CB}│${NC} ${DG}Dir:${NC}      $MACHINEDIR"
    echo -e "  ${CB}│${NC} ${DG}Size:${NC}     $size"
    echo -e "  ${CB}│${NC} ${DG}Status:${NC}   $st_run"
    echo -e "  ${CB}│${NC} ${DG}Created:${NC}  $CREATED"
    echo -e "  ${CB}└─────────────────────────────────────────────┘${NC}"
    echo ""
    read -p "   Press Enter..."
}

edit_vm() {
    local n=$1
    load_cfg "$n" || return 1
    while true; do
        echo ""
        echo -e "  ${C}Editing: $n${NC}"
        echo "  1) Hostname    2) Username    3) Password"
        echo "  4) SSH Port    0) Back"
        echo ""
        read -p "   Choice: " c
        case $c in
            1) read -p "  Hostname [$HOSTNAME]: " v; HOSTNAME="${v:-$HOSTNAME}"
               echo "$HOSTNAME" > "$MACHINEDIR/etc/hostname" 2>/dev/null || true ;;
            2) read -p "  Username [$USERNAME]: " v; USERNAME="${v:-$USERNAME}" ;;
            3) read -s -p "  Password [****]: " v; echo; PASSWORD="${v:-$PASSWORD}"
               is_running "$n" && systemd-nspawn -D "$MACHINEDIR" --machine "$n" /bin/bash -c "echo '$USERNAME:$PASSWORD' | chpasswd" 2>/dev/null || true ;;
            4) while true; do read -p "  SSH Port [$SSH_PORT]: " v; v="${v:-$SSH_PORT}"; vd port "$v" && { SSH_PORT="$v"; break; }; done ;;
            0) return ;;
            *) continue ;;
        esac
        save_cfg
        read -p "   Continue editing? (y/N): " ce
        [[ "$ce" =~ ^[Yy]$ ]] || break
    done
}

pick_vm() {
    local action=$1
    local vms=($(get_list))
    if [ ${#vms[@]} -eq 0 ]; then
        st W "No machines found"
        read -p "   Press Enter..."
        return 1
    fi
    echo ""
    for i in "${!vms[@]}"; do
        local s="${R}■${NC}"
        is_running "${vms[$i]}" && s="${G}●${NC}"
        printf "    %d) %s %s\n" $((i+1)) "$s" "${vms[$i]}"
    done
    echo ""
    read -p "   Machine number: " num
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#vms[@]} ]; then
        $action "${vms[$((num-1))]}"
    else
        st E "Invalid"
    fi
    read -p "   Press Enter..."
}

main() {
    mkdir -p "$NSPAWN_DIR" "$VM_DIR" 2>/dev/null
    while true; do
        hdr
        echo -e "    ${GR}[1]${NC} Create new machine"
        echo -e "    ${GR}[2]${NC} Start machine"
        echo -e "    ${GR}[3]${NC} Stop machine"
        echo -e "    ${GR}[4]${NC} Attach (shell)"
        echo -e "    ${GR}[5]${NC} Run command"
        echo -e "    ${GR}[6]${NC} Machine info"
        echo -e "    ${GR}[7]${NC} Edit config"
        echo -e "    ${GR}[8]${NC} Delete machine"
        echo -e "    ${R}[0]${NC} Back"
        echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
        read -p "  ${C}➜${NC} Choice: " c
        if [ "$c" != "0" ] && [ -n "$c" ]; then
            chk_deps || { read -p "   Press Enter..."; continue; }
        fi
        case $c in
            1) create_vm; read -p "   Press Enter..." ;;
            2) pick_vm start_vm ;;
            3) pick_vm stop_vm ;;
            4) pick_vm attach_vm ;;
            5) pick_vm run_cmd_vm ;;
            6) pick_vm show_info ;;
            7) pick_vm edit_vm ;;
            8) pick_vm delete_vm ;;
            0) clear; exit 0 ;;
            *) st E "Invalid"; sleep 1 ;;
        esac
    done
}

main
