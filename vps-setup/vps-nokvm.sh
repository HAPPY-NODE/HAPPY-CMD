#!/bin/bash
set -uo pipefail

# =============================
# HAPPY-CMD No-KVM VM Manager
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
VM_DIR="${VM_DIR:-$HOME/vms}"

# Live spinner + last interesting line from a temp log
run_live() {
    local msg="$1"; shift
    local log; log="$(mktemp /tmp/hn_live.XXXXXX)"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0 rc line
    "$@" >"$log" 2>&1 &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        line=$(grep -E '^(Get:|Hit:|Unpacking:|Setting up:|Selecting:|Preparing:|Downloading:|Extracting:|Processing:|Building:)' "$log" 2>/dev/null | tail -1)
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
    echo -e "  ${CB}│${DG}       HAPPY  NODE  •  SOFTWARE  MODE          ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    local total_vms=$(find "$VM_DIR" -name "*.conf" 2>/dev/null | wc -l)
    local run_vms=$(pgrep -fc "qemu-system" 2>/dev/null || echo 0)
    echo -e "  ${DG}Mode:${NC} ${Y}TCG${NC}  ${DG}│${NC}  ${DG}VMs:${NC} ${G}${run_vms}${NC}${DG}/${NC}${total_vms}  ${DG}│${NC}  ${DG}Dir:${NC} ${VM_DIR}"
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
    local deps=("qemu-system-x86_64" "wget" "cloud-localds" "qemu-img" "lsof")
    local miss=()
    for d in "${deps[@]}"; do command -v "$d" &>/dev/null || miss+=("$d"); done
    if [ ${#miss[@]} -ne 0 ]; then
        st I "Missing: ${miss[*]}"
        st I "Installing packages (live)..."
        echo ""
        if command -v apt-get &>/dev/null; then
            run_live "apt-update" apt-get update -y -q || true
            run_live "apt-install" env DEBIAN_FRONTEND=noninteractive apt-get install -y qemu-system-x86 qemu-utils cloud-image-utils wget lsof
        elif command -v yum &>/dev/null; then
            run_live "yum-install" yum install -y qemu-system-x86 qemu-img cloud-utils wget lsof
        else
            st E "Cannot auto-install. Run: apt install qemu-system-x86 qemu-utils cloud-image-utils wget lsof"
            exit 1
        fi
        echo ""
        for d in "${deps[@]}"; do
            command -v "$d" &>/dev/null || { st E "Still missing: $d"; exit 1; }
        done
        st S "Dependencies installed"
    fi
}

cleanup() { rm -f user-data meta-data 2>/dev/null; }
trap cleanup EXIT

get_vm_list() {
    find "$VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

load_cfg() {
    local n=$1 f="$VM_DIR/$1.conf"
    [ -f "$f" ] || { st E "Config not found: $n"; return 1; }
    unset VM_NAME OS_TYPE CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
    unset DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE PORT_FORWARDS IMG_FILE SEED_FILE CREATED
    source "$f"
}

save_cfg() {
    cat > "$VM_DIR/$VM_NAME.conf" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
CODENAME="$CODENAME"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="$SSH_PORT"
GUI_MODE="$GUI_MODE"
PORT_FORWARDS="$PORT_FORWARDS"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$CREATED"
EOF
    st S "Config saved: $VM_DIR/$VM_NAME.conf"
}

is_running() {
    local n=$1
    pgrep -f "qemu-system.*$n" &>/dev/null && return 0
    load_cfg "$n" 2>/dev/null && pgrep -f "qemu-system.*$IMG_FILE" &>/dev/null
}

chk_lock() {
    local img=$1
    if lsof "$img" 2>/dev/null | grep -q qemu-system; then
        local pid=$(lsof "$img" 2>/dev/null | grep qemu-system | awk '{print $2}' | head -1)
        st W "Image locked by PID $pid"
        read -p "$(st Q 'Force kill? (y/N): ')" fk
        if [[ "$fk" =~ ^[Yy]$ ]]; then
            kill "$pid" 2>/dev/null; sleep 1
            kill -9 "$pid" 2>/dev/null
            rm -f "${img}.lock" 2>/dev/null
            return 0
        fi
        return 1
    fi
    return 0
}

declare -A OS_OPTS=(
    ["Ubuntu 22.04 LTS"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"
    ["Ubuntu 24.04 LTS"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"
    ["Debian 12 (Bookworm)"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"
    ["Debian 13 (Trixie)"]="debian|trixie|https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2|debian13|debian|debian"
    ["Fedora 40"]="fedora|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-40-1.14.x86_64.qcow2|fedora40|fedora|fedora"
    ["CentOS Stream 9"]="centos|stream9|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos9|centos|centos"
    ["AlmaLinux 9"]="almalinux|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|almalinux9|alma|alma"
    ["Rocky Linux 9"]="rockylinux|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky9|rocky|rocky"
)

setup_image() {
    st I "Preparing VM image..."
    mkdir -p "$VM_DIR"
    if [ -f "$IMG_FILE" ]; then
        st S "Image exists, skipping download"
    else
        st I "Downloading: $IMG_URL"
        echo ""
        if ! wget --progress=bar:force:noscroll -t 3 --timeout=30 "$IMG_URL" -O "$IMG_FILE.tmp"; then
            st E "Download failed"; rm -f "$IMG_FILE.tmp" 2>/dev/null; exit 1
        fi
        echo ""
        mv "$IMG_FILE.tmp" "$IMG_FILE"
    fi
    qemu-img resize "$IMG_FILE" "$DISK_SIZE" 2>/dev/null || true

    cat > user-data <<EOF
#cloud-config
hostname: $HOSTNAME
ssh_pwauth: true
disable_root: false
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: $(openssl passwd -6 "$PASSWORD" | tr -d '\n')
chpasswd:
  list: |
    root:$PASSWORD
    $USERNAME:$PASSWORD
  expire: false
EOF

    cat > meta-data <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF

    cloud-localds "$SEED_FILE" user-data meta-data || { st E "cloud-init failed"; exit 1; }
    st S "VM '$VM_NAME' created"
    st I "Login: $USERNAME / $PASSWORD"
    st I "SSH: ssh -p $SSH_PORT $USERNAME@localhost"
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
    IFS='|' read -r OS_TYPE CODENAME IMG_URL DEF_HOST DEF_USER DEF_PASS <<< "${OS_OPTS[$os]}"

    while true; do
        read -p "$(st Q "  VM name [$DEF_HOST]: ")" VM_NAME
        VM_NAME="${VM_NAME:-$DEF_HOST}"
        vd name "$VM_NAME" && { [ -f "$VM_DIR/$VM_NAME.conf" ] && st E "Exists" || break; }
    done
    while true; do
        read -p "$(st Q "  Hostname [$VM_NAME]: ")" HOSTNAME
        HOSTNAME="${HOSTNAME:-$VM_NAME}"
        vd name "$HOSTNAME" && break
    done
    while true; do
        read -p "$(st Q "  Username [$DEF_USER]: ")" USERNAME
        USERNAME="${USERNAME:-$DEF_USER}"
        vd user "$USERNAME" && break
    done
    while true; do
        read -s -p "$(st Q "  Password [$DEF_PASS]: ")" PASSWORD; echo
        PASSWORD="${PASSWORD:-$DEF_PASS}"
        [ -n "$PASSWORD" ] && break
    done
    while true; do
        read -p "$(st Q "  Disk size [20G]: ")" DISK_SIZE
        DISK_SIZE="${DISK_SIZE:-20G}"
        vd size "$DISK_SIZE" && break
    done
    while true; do
        read -p "$(st Q "  Memory MB [2048]: ")" MEMORY
        MEMORY="${MEMORY:-2048}"
        vd number "$MEMORY" && break
    done
    while true; do
        read -p "$(st Q "  CPUs [2]: ")" CPUS
        CPUS="${CPUS:-2}"
        vd number "$CPUS" && break
    done
    while true; do
        read -p "$(st Q "  SSH port [2222]: ")" SSH_PORT
        SSH_PORT="${SSH_PORT:-2222}"
        vd port "$SSH_PORT" && { ss -tln 2>/dev/null | grep -q ":$SSH_PORT " && st E "Port in use" || break; }
    done
    read -p "$(st Q "  GUI mode? (y/n) [n]: ")" gui
    GUI_MODE=false; [[ "${gui:-n}" =~ ^[Yy]$ ]] && GUI_MODE=true
    read -p "$(st Q "  Port forwards (8080:80) or Enter: ")" PORT_FORWARDS

    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date)"
    setup_image
    save_cfg
}

start_vm() {
    local n=$1
    load_cfg "$n" || return 1

    chk_lock "$IMG_FILE" || { st E "Image locked"; return 1; }

    if is_running "$n"; then
        st W "Already running"
        read -p "$(st Q 'Restart? (y/N): ')" rc
        [[ "$rc" =~ ^[Yy]$ ]] || return 1
        stop_vm "$n"; sleep 1
    fi

    [ -f "$IMG_FILE" ] || { st E "Image not found"; return 1; }
    [ -f "$SEED_FILE" ] || setup_image

    st I "Starting: $n"
    st I "SSH: ssh -p $SSH_PORT $USERNAME@localhost"
    st I "Pass: $PASSWORD"
    st W "Software emulation — slower than KVM"

    local cmd=(
        qemu-system-x86_64
        -m "$MEMORY"
        -smp "$CPUS"
        -cpu qemu64
        -machine type=pc,accel=tcg
        -drive "file=$IMG_FILE,format=qcow2,if=virtio"
        -drive "file=$SEED_FILE,format=raw,if=virtio"
        -boot order=c
        -device virtio-net-pci,netdev=n0
        -netdev "user,id=n0,hostfwd=tcp::$SSH_PORT-:22"
        -device virtio-balloon-pci
        -object rng-random,filename=/dev/urandom,id=rng0
        -device virtio-rng-pci,rng=rng0
        -no-hpet
        -rtc base=utc,clock=host
    )

    if [ -n "$PORT_FORWARDS" ]; then
        local idx=1
        IFS=',' read -ra fw <<< "$PORT_FORWARDS"
        for f in "${fw[@]}"; do
            IFS=':' read -r hp gp <<< "$f"
            cmd+=(-device "virtio-net-pci,netdev=n$idx" -netdev "user,id=n$idx,hostfwd=tcp::$hp-:$gp")
            ((idx++))
        done
    fi

    if [ "$GUI_MODE" = true ]; then
        cmd+=(-vga virtio -display gtk,gl=on)
        st I "GUI mode"
    else
        cmd+=(-nographic -serial mon:stdio)
        st I "Console mode — Ctrl+A then X to exit"
    fi

    st I "RAM:${MEMORY}MB CPU:${CPUS} Disk:${DISK_SIZE}"
    "${cmd[@]}" || { st E "Start failed"; rm -f "${IMG_FILE}.lock" 2>/dev/null; return 1; }
    st I "VM stopped"
}

stop_vm() {
    local n=$1
    load_cfg "$n" || return 1
    if is_running "$n"; then
        st I "Stopping: $n"
        pkill -f "qemu-system.*$IMG_FILE" 2>/dev/null; sleep 2
        is_running "$n" && { st W "Force kill"; pkill -9 -f "qemu-system.*$IMG_FILE" 2>/dev/null; sleep 1; }
        rm -f "${IMG_FILE}.lock" 2>/dev/null
        is_running "$n" && { st E "Failed"; return 1; }
        st S "Stopped"
    else
        st I "Not running"
        rm -f "${IMG_FILE}.lock" 2>/dev/null
    fi
}

delete_vm() {
    local n=$1
    st W "Delete '$n' and ALL data?"
    read -p "$(st Q 'Confirm (y/N): ')" -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || { st I "Cancelled"; return; }
    if load_cfg "$n"; then
        is_running "$n" && { stop_vm "$n"; sleep 1; }
        rm -f "$IMG_FILE" "$SEED_FILE" "$VM_DIR/$n.conf" "${IMG_FILE}.lock" 2>/dev/null
        st S "Deleted: $n"
    fi
}

show_info() {
    local n=$1
    load_cfg "$n" || return 1
    local st_run="${R}stopped${NC}"
    is_running "$n" && st_run="${G}running${NC}"
    echo ""
    echo -e "  ${CB}┌─── ${W}$n${CB} ──────────────────────────────────────┐${NC}"
    echo -e "  ${CB}│${NC} ${DG}OS:${NC}       $OS_TYPE"
    echo -e "  ${CB}│${NC} ${DG}Host:${NC}     $HOSTNAME"
    echo -e "  ${CB}│${NC} ${DG}User:${NC}     $USERNAME"
    echo -e "  ${CB}│${NC} ${DG}Pass:${NC}     $PASSWORD"
    echo -e "  ${CB}│${NC} ${DG}SSH:${NC}      port $SSH_PORT"
    echo -e "  ${CB}│${NC} ${DG}RAM:${NC}      ${MEMORY}MB"
    echo -e "  ${CB}│${NC} ${DG}CPU:${NC}      ${CPUS} cores"
    echo -e "  ${CB}│${NC} ${DG}Disk:${NC}     $DISK_SIZE"
    echo -e "  ${CB}│${NC} ${DG}GUI:${NC}      $GUI_MODE"
    echo -e "  ${CB}│${NC} ${DG}Fwd:${NC}      ${PORT_FORWARDS:-none}"
    echo -e "  ${CB}│${NC} ${DG}Created:${NC}  $CREATED"
    echo -e "  ${CB}│${NC} ${DG}Status:${NC}   $st_run"
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
        echo "  4) SSH Port    5) GUI Mode    6) Port Fwds"
        echo "  7) Memory      8) CPUs        9) Disk"
        echo "  0) Back"
        echo ""
        read -p "   Choice: " c
        case $c in
            1) read -p "  Hostname [$HOSTNAME]: " v; HOSTNAME="${v:-$HOSTNAME}" ;;
            2) read -p "  Username [$USERNAME]: " v; USERNAME="${v:-$USERNAME}" ;;
            3) read -s -p "  Password [****]: " v; echo; PASSWORD="${v:-$PASSWORD}" ;;
            4) while true; do read -p "  SSH Port [$SSH_PORT]: " v; v="${v:-$SSH_PORT}"; vd port "$v" && { SSH_PORT="$v"; break; }; done ;;
            5) read -p "  GUI? (y/n) [$GUI_MODE]: " v
               [[ "${v:-}" =~ ^[Yy]$ ]] && GUI_MODE=true || { [[ "${v:-}" =~ ^[Nn]$ ]] && GUI_MODE=false; } ;;
            6) read -p "  Fwds [$PORT_FORWARDS]: " v; PORT_FORWARDS="${v:-$PORT_FORWARDS}" ;;
            7) while true; do read -p "  Memory [$MEMORY]: " v; v="${v:-$MEMORY}"; vd number "$v" && { MEMORY="$v"; break; }; done ;;
            8) while true; do read -p "  CPUs [$CPUS]: " v; v="${v:-$CPUS}"; vd number "$v" && { CPUS="$v"; break; }; done ;;
            9) while true; do read -p "  Disk [$DISK_SIZE]: " v; v="${v:-$DISK_SIZE}"; vd size "$v" && { DISK_SIZE="$v"; break; }; done ;;
            0) return ;;
            *) continue ;;
        esac
        [[ "$c" =~ ^[123]$ ]] && { st I "Updating cloud-init..."; setup_image; }
        save_cfg
        read -p "   Continue editing? (y/N): " ce
        [[ "$ce" =~ ^[Yy]$ ]] || break
    done
}

resize_disk() {
    local n=$1
    load_cfg "$n" || return 1
    is_running "$n" && { st E "Stop VM first"; return 1; }
    st I "Current: $DISK_SIZE"
    read -p "$(st Q 'New size (e.g. 50G): ')" ns
    vd size "$ns" || return 1
    st I "Resizing to $ns..."
    qemu-img resize "$IMG_FILE" "$ns" && { DISK_SIZE="$ns"; save_cfg; st S "Resized"; } || st E "Failed"
}

fix_issues() {
    local n=$1
    load_cfg "$n" || return 1
    echo ""
    echo "  1) Remove locks    2) Recreate seed"
    echo "  3) Save config     4) Kill stuck proc"
    echo "  0) Back"
    read -p "   Choice: " c
    case $c in
        1) rm -f "${IMG_FILE}".lock* 2>/dev/null; st S "Locks removed" ;;
        2) rm -f "$SEED_FILE" 2>/dev/null; setup_image; st S "Seed recreated" ;;
        3) save_cfg ;;
        4) pkill -f "qemu-system.*$IMG_FILE" 2>/dev/null; sleep 1
           pgrep -f "qemu-system.*$IMG_FILE" &>/dev/null && pkill -9 -f "qemu-system.*$IMG_FILE" 2>/dev/null
           st S "Processes cleared" ;;
        0) return ;;
    esac
}

pick_vm() {
    local action=$1
    local vms=($(get_vm_list))
    if [ ${#vms[@]} -eq 0 ]; then
        st W "No VMs found"
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
    read -p "   VM number: " num
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#vms[@]} ]; then
        $action "${vms[$((num-1))]}"
    else
        st E "Invalid"
    fi
    read -p "   Press Enter..."
}

main() {
    chk_deps
    mkdir -p "$VM_DIR"
    while true; do
        hdr
        echo -e "    ${GR}[1]${NC} Create new VM"
        echo -e "    ${GR}[2]${NC} Start VM"
        echo -e "    ${GR}[3]${NC} Stop VM"
        echo -e "    ${GR}[4]${NC} VM info"
        echo -e "    ${GR}[5]${NC} Edit config"
        echo -e "    ${GR}[6]${NC} Delete VM"
        echo -e "    ${GR}[7]${NC} Resize disk"
        echo -e "    ${GR}[8]${NC} Fix issues"
        echo -e "    ${R}[0]${NC} Back"
        echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
        read -p "  ${C}➜${NC} Choice: " c
        case $c in
            1) create_vm; read -p "   Press Enter..." ;;
            2) pick_vm start_vm ;;
            3) pick_vm stop_vm ;;
            4) pick_vm show_info ;;
            5) pick_vm edit_vm ;;
            6) pick_vm delete_vm ;;
            7) pick_vm resize_disk ;;
            8) pick_vm fix_issues ;;
            0) clear; exit 0 ;;
            *) st E "Invalid"; sleep 1 ;;
        esac
    done
}

main
