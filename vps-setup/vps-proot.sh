#!/bin/bash
set -uo pipefail

# =============================
# HAPPY-CMD proot VM Manager
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
VM_DIR="${VM_DIR:-$HOME/vms-proot}"

run_live() {
    local msg="$1"; shift
    local log; log="$(mktemp /tmp/hn_live.XXXXXX)"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0 rc line
    "$@" >"$log" 2>&1 &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        line=$(grep -E '^(Get:|Hit:|Unpacking:|Setting up:|Selecting:|Preparing:|Downloading:|Extracting:|Processing:|Building:|W:|E:)' "$log" 2>/dev/null | tail -1)
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
    echo -e "  ${CB}│${DG}       HAPPY  NODE  •  PROOT  MODE            ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    local total_vms=$(find "$VM_DIR" -name "*.conf" 2>/dev/null | wc -l)
    echo -e "  ${DG}Mode:${NC} ${C}PROOT${NC}  ${DG}│${NC}  ${DG}Containers:${NC} ${G}${total_vms}${NC}  ${DG}│${NC}  ${DG}Dir:${NC} ${VM_DIR}"
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
        size)   [[ "$v" =~ ^[0-9]+[GgMm]$ ]] || { st E "Use format: 20G, 512M"; return 1; } ;;
        port)   [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge 23 ] && [ "$v" -le 65535 ] || { st E "Port 23-65535"; return 1; } ;;
        name)   [[ "$v" =~ ^[a-zA-Z0-9_-]+$ ]] || { st E "Letters, numbers, - and _ only"; return 1; } ;;
        user)   [[ "$v" =~ ^[a-z_][a-z0-9_-]*$ ]] || { st E "Start with letter/underscore"; return 1; } ;;
    esac
    return 0
}

chk_deps() {
    local deps=("proot" "wget" "tar")
    local miss=()
    for d in "${deps[@]}"; do command -v "$d" &>/dev/null || miss+=("$d"); done
    if [ ${#miss[@]} -ne 0 ]; then
        st I "Missing: ${miss[*]}"
        st I "Installing packages (live)..."
        echo ""
        if command -v apt-get &>/dev/null; then
            run_live "apt-update" apt-get update -y -q || true
            run_live "apt-install" env DEBIAN_FRONTEND=noninteractive apt-get install -y proot wget tar
        elif command -v yum &>/dev/null; then
            run_live "yum-install" yum install -y proot wget tar
        else
            st E "Cannot auto-install. Run: apt install proot wget tar"
            return 1
        fi
        echo ""
        for d in "${deps[@]}"; do
            command -v "$d" &>/dev/null || { st E "Still missing: $d"; return 1; }
        done
        st S "Dependencies installed"
    fi
}

get_list() {
    find "$VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

load_cfg() {
    local n=$1 f="$VM_DIR/$1.conf"
    [ -f "$f" ] || { st E "Config not found: $n"; return 1; }
    unset VM_NAME OS_TYPE ROOTFS_URL ROOTFS_DIR HOSTNAME USERNAME PASSWORD SSH_PORT CREATED
    source "$f"
}

save_cfg() {
    cat > "$VM_DIR/$VM_NAME.conf" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
ROOTFS_URL="$ROOTFS_URL"
ROOTFS_DIR="$ROOTFS_DIR"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
SSH_PORT="$SSH_PORT"
CREATED="$CREATED"
EOF
    st S "Config saved: $VM_DIR/$VM_NAME.conf"
}

declare -A OS_OPTS=(
    ["Ubuntu 22.04 RootFS"]="ubuntu22|https://partner-images.canonical.com/core/jammy/current/ubuntu-base-jammy-base-amd64.tar.gz"
    ["Ubuntu 24.04 RootFS"]="ubuntu24|https://partner-images.canonical.com/core/noble/current/ubuntu-base-noble-base-amd64.tar.gz"
    ["Debian 12 RootFS"]="debian12|https://github.com/debuerreotype/docker-debian-artifacts/raw/dist-amd64/bookworm/rootfs.tar.xz"
    ["Alpine 3.19 RootFS"]="alpine319|https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-minirootfs-3.19.1-x86_64.tar.gz"
)

download_rootfs() {
    st I "Downloading rootfs: $OS_TYPE"
    echo ""
    if ! wget --progress=bar:force:noscroll -t 3 --timeout=30 "$ROOTFS_URL" -O "$ROOTFS_DIR.tar.gz.tmp"; then
        st E "Download failed"; rm -f "$ROOTFS_DIR.tar.gz.tmp" 2>/dev/null; return 1
    fi
    echo ""
    mv "$ROOTFS_DIR.tar.gz.tmp" "$ROOTFS_DIR.tar.gz"
    mkdir -p "$ROOTFS_DIR"
    st I "Extracting rootfs..."
    if ! tar -xzf "$ROOTFS_DIR.tar.gz" -C "$ROOTFS_DIR" 2>/dev/null; then
        tar -xJf "$ROOTFS_DIR.tar.gz" -C "$ROOTFS_DIR" 2>/dev/null || { st E "Extract failed"; return 1; }
    fi
    rm -f "$ROOTFS_DIR.tar.gz"
    st S "Rootfs ready"
}

setup_rootfs() {
    st I "Configuring rootfs..."
    mkdir -p "$ROOTFS_DIR/etc" "$ROOTFS_DIR/root" "$ROOTFS_DIR/tmp" "$ROOTFS_DIR/var/tmp"
    chmod 1777 "$ROOTFS_DIR/tmp" "$ROOTFS_DIR/var/tmp" 2>/dev/null

    echo "$HOSTNAME" > "$ROOTFS_DIR/etc/hostname"
    cat > "$ROOTFS_DIR/etc/hosts" <<EOF
127.0.0.1 localhost $HOSTNAME
::1       localhost $HOSTNAME
EOF

    if [ ! -f "$ROOTFS_DIR/etc/resolv.conf" ] || [ ! -s "$ROOTFS_DIR/etc/resolv.conf" ]; then
        cat > "$ROOTFS_DIR/etc/resolv.conf" <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
    fi

    cat > "$ROOTFS_DIR/root/.bashrc" <<EOF
export PS1='[\u@\h \W]\\$ '
alias ll='ls -la'
EOF

    cat > "$ROOTFS_DIR/setup-user.sh" <<EOF
#!/bin/bash
if ! id "$USERNAME" &>/dev/null; then
    useradd -m -s /bin/bash "$USERNAME" 2>/dev/null || adduser -D "$USERNAME" 2>/dev/null
fi
echo "$USERNAME:$PASSWORD" | chpasswd 2>/dev/null || echo "root:$PASSWORD" | chpasswd 2>/dev/null
echo "root:$PASSWORD" | chpasswd 2>/dev/null
EOF
    chmod +x "$ROOTFS_DIR/setup-user.sh"

    st I "Setting up user via proot..."
    run_live "proot-setup" proot -r "$ROOTFS_DIR" -0 -w / -b /dev -b /proc -b /sys -b /etc/resolv.conf:/etc/resolv.conf /bin/bash /setup-user.sh || true
    rm -f "$ROOTFS_DIR/setup-user.sh"
    st S "Rootfs configured: $USERNAME / $PASSWORD"
}

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
    IFS='|' read -r OS_TYPE ROOTFS_URL <<< "${OS_OPTS[$os]}"

    while true; do
        read -p "$(st Q "  Container name [$OS_TYPE]: ")" VM_NAME
        VM_NAME="${VM_NAME:-$OS_TYPE}"
        vd name "$VM_NAME" && { [ -f "$VM_DIR/$VM_NAME.conf" ] && st E "Exists" || break; }
    done
    while true; do
        read -p "$(st Q "  Hostname [$VM_NAME]: ")" HOSTNAME
        HOSTNAME="${HOSTNAME:-$VM_NAME}"
        vd name "$HOSTNAME" && break
    done
    while true; do
        read -p "$(st Q "  Username [root]: ")" USERNAME
        USERNAME="${USERNAME:-root}"
        vd user "$USERNAME" 2>/dev/null || true
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

    ROOTFS_DIR="$VM_DIR/$VM_NAME/rootfs"
    mkdir -p "$ROOTFS_DIR"
    CREATED="$(date)"
    download_rootfs || return 1
    setup_rootfs
    save_cfg
}

enter_vm() {
    local n=$1
    load_cfg "$n" || return 1
    [ -d "$ROOTFS_DIR" ] || { st E "Rootfs not found"; return 1; }
    st I "Entering: $n (user: $USERNAME)"
    st I "Type 'exit' to leave"
    echo ""
    proot -r "$ROOTFS_DIR" -0 -w / -b /dev -b /proc -b /sys -b /etc/resolv.conf:/etc/resolv.conf \
        -b "$ROOTFS_DIR/tmp:/tmp" \
        /bin/bash -l || true
    echo ""
    st S "Exited: $n"
}

run_cmd_vm() {
    local n=$1
    load_cfg "$n" || return 1
    [ -d "$ROOTFS_DIR" ] || { st E "Rootfs not found"; return 1; }
    read -p "$(st Q '  Command: ')" cmd
    [ -z "$cmd" ] && return
    echo ""
    proot -r "$ROOTFS_DIR" -0 -w / -b /dev -b /proc -b /sys -b /etc/resolv.conf:/etc/resolv.conf \
        /bin/bash -c "$cmd" || true
    echo ""
    read -p "   Press Enter..."
}

delete_vm() {
    local n=$1
    st W "Delete '$n' and ALL rootfs data?"
    read -p "$(st Q 'Confirm (y/N): ')" -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || { st I "Cancelled"; return; }
    load_cfg "$n" || return 1
    rm -rf "$ROOTFS_DIR" "$VM_DIR/$n.conf" 2>/dev/null
    st S "Deleted: $n"
}

show_info() {
    local n=$1
    load_cfg "$n" || return 1
    local rfs_size="?"
    [ -d "$ROOTFS_DIR" ] && rfs_size=$(du -sh "$ROOTFS_DIR" 2>/dev/null | awk '{print $1}')
    local running="${R}no shell${NC}"
    pgrep -f "proot.*$ROOTFS_DIR" &>/dev/null && running="${G}active${NC}"
    echo ""
    echo -e "  ${CB}┌─── ${W}$n${CB} ──────────────────────────────────────┐${NC}"
    echo -e "  ${CB}│${NC} ${DG}OS:${NC}       $OS_TYPE"
    echo -e "  ${CB}│${NC} ${DG}Host:${NC}     $HOSTNAME"
    echo -e "  ${CB}│${NC} ${DG}User:${NC}     $USERNAME"
    echo -e "  ${CB}│${NC} ${DG}Pass:${NC}     $PASSWORD"
    echo -e "  ${CB}│${NC} ${DG}SSH Port:${NC} $SSH_PORT"
    echo -e "  ${CB}│${NC} ${DG}Rootfs:${NC}   $ROOTFS_DIR"
    echo -e "  ${CB}│${NC} ${DG}Size:${NC}     $rfs_size"
    echo -e "  ${CB}│${NC} ${DG}Status:${NC}   $running"
    echo -e "  ${CB}│${NC} ${DG}Created:${NC}  $CREATED"
    echo -e "  ${CB}└─────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${DG}Enter: proot -r $ROOTFS_DIR -0 -b /dev -b /proc -b /sys /bin/bash${NC}"
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
            1) read -p "  Hostname [$HOSTNAME]: " v; HOSTNAME="${v:-$HOSTNAME}" ;;
            2) read -p "  Username [$USERNAME]: " v; USERNAME="${v:-$USERNAME}" ;;
            3) read -s -p "  Password [****]: " v; echo; PASSWORD="${v:-$PASSWORD}" ;;
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
        st W "No containers found"
        read -p "   Press Enter..."
        return 1
    fi
    echo ""
    for i in "${!vms[@]}"; do
        printf "    %d) %s\n" $((i+1)) "${vms[$i]}"
    done
    echo ""
    read -p "   Container number: " num
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#vms[@]} ]; then
        $action "${vms[$((num-1))]}"
    else
        st E "Invalid"
    fi
    read -p "   Press Enter..."
}

main() {
    mkdir -p "$VM_DIR"
    while true; do
        hdr
        echo -e "    ${GR}[1]${NC} Create new container"
        echo -e "    ${GR}[2]${NC} Enter container"
        echo -e "    ${GR}[3]${NC} Run command"
        echo -e "    ${GR}[4]${NC} Container info"
        echo -e "    ${GR}[5]${NC} Edit config"
        echo -e "    ${GR}[6]${NC} Delete container"
        echo -e "    ${R}[0]${NC} Back"
        echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
        read -p "  ${C}➜${NC} Choice: " c
        if [ "$c" != "0" ] && [ -n "$c" ]; then
            chk_deps || { read -p "   Press Enter..."; continue; }
        fi
        case $c in
            1) create_vm; read -p "   Press Enter..." ;;
            2) pick_vm enter_vm ;;
            3) pick_vm run_cmd_vm ;;
            4) pick_vm show_info ;;
            5) pick_vm edit_vm ;;
            6) pick_vm delete_vm ;;
            0) clear; exit 0 ;;
            *) st E "Invalid"; sleep 1 ;;
        esac
    done
}

main
