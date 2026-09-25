#!/bin/bash
set -uo pipefail

# =============================
# HAPPY-CMD LXC VM Manager
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
VM_DIR="${VM_DIR:-$HOME/vms-lxc}"

run_live() {
    local msg="$1"; shift
    local log; log="$(mktemp /tmp/hn_live.XXXXXX)"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0 rc line
    "$@" >"$log" 2>&1 &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        line=$(grep -E '^(Get:|Hit:|Unpacking:|Setting up:|Selecting:|Preparing:|Downloading:|Extracting:|Processing:|Building:|Creating:|Copy:)' "$log" 2>/dev/null | tail -1)
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
    echo -e "  ${CB}│${DG}       HAPPY  NODE  •  LXC  MODE              ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    local total=0 running=0
    if command -v lxc-ls &>/dev/null; then
        total=$(lxc-ls 2>/dev/null | wc -w)
        running=$(lxc-ls --active 2>/dev/null | wc -w)
    fi
    echo -e "  ${DG}Mode:${NC} ${C}LXC${NC}  ${DG}│${NC}  ${DG}Running:${NC} ${G}${running}${NC}${DG}/${NC}${total}  ${DG}│${NC}  ${DG}Dir:${NC} /var/lib/lxc"
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
        user)   [[ "$v" =~ ^[a-z_][a-z0-9_-]*$ ]] || { st E "Start with letter/underscore"; return 1; } ;;
    esac
    return 0
}

chk_deps() {
    local deps=("lxc-create" "lxc-start" "lxc-stop" "lxc-attach")
    local miss=()
    for d in "${deps[@]}"; do command -v "$d" &>/dev/null || miss+=("$d"); done
    if [ ${#miss[@]} -ne 0 ]; then
        st I "Missing: ${miss[*]}"
        st I "Installing LXC (live)..."
        echo ""
        if command -v apt-get &>/dev/null; then
            run_live "apt-update" apt-get update -y -q || true
            run_live "apt-install" env DEBIAN_FRONTEND=noninteractive apt-get install -y lxc lxc-templates
        elif command -v yum &>/dev/null; then
            run_live "yum-install" yum install -y lxc lxc-templates
        else
            st E "Cannot auto-install. Run: apt install lxc"
            return 1
        fi
        echo ""
        if ! command -v lxc-create &>/dev/null; then
            st E "LXC install failed"; return 1
        fi
        st S "LXC installed"
    fi
}

get_list() {
    lxc-ls 2>/dev/null | tr ' ' '\n' | grep -v '^$' | sort
}

is_running() {
    lxc-info -n "$1" 2>/dev/null | grep -q "State: *RUNNING"
}

save_cfg() {
    mkdir -p "$VM_DIR"
    cat > "$VM_DIR/$VM_NAME.conf" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
TEMPLATE="$TEMPLATE"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
SSH_PORT="$SSH_PORT"
MEM_MB="$MEM_MB"
CPUS="$CPUS"
CREATED="$CREATED"
EOF
    st S "Config saved: $VM_DIR/$VM_NAME.conf"
}

load_cfg() {
    local n=$1 f="$VM_DIR/$1.conf"
    [ -f "$f" ] || { st E "Config not found: $n"; return 1; }
    unset VM_NAME OS_TYPE TEMPLATE HOSTNAME USERNAME PASSWORD SSH_PORT MEM_MB CPUS CREATED
    source "$f"
}

declare -A OS_OPTS=(
    ["Ubuntu 22.04"]="ubuntu|jammy|amd64|ubuntu22"
    ["Ubuntu 24.04"]="ubuntu|noble|amd64|ubuntu24"
    ["Debian 12"]="debian|bookworm|amd64|debian12"
    ["Alpine 3.19"]="alpine|3.19|amd64|alpine319"
    ["CentOS Stream 9"]="centos|9|amd64|centos9"
    ["Fedora 39"]="fedora|39|amd64|fedora39"
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
    IFS='|' read -r OS_TYPE TEMPLATE ARCH DEF_HOST <<< "${OS_OPTS[$os]}"

    while true; do
        read -p "$(st Q "  Container name [$DEF_HOST]: ")" VM_NAME
        VM_NAME="${VM_NAME:-$DEF_HOST}"
        vd name "$VM_NAME" && { lxc-info -n "$VM_NAME" &>/dev/null && st E "Exists" || break; }
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
        read -p "$(st Q "  Memory MB [1024]: ")" MEM_MB
        MEM_MB="${MEM_MB:-1024}"
        vd number "$MEM_MB" && break
    done
    while true; do
        read -p "$(st Q "  CPUs [1]: ")" CPUS
        CPUS="${CPUS:-1}"
        vd number "$CPUS" && break
    done
    while true; do
        read -p "$(st Q "  SSH port [2222]: ")" SSH_PORT
        SSH_PORT="${SSH_PORT:-2222}"
        vd port "$SSH_PORT" && { ss -tln 2>/dev/null | grep -q ":$SSH_PORT " && st E "Port in use" || break; }
    done

    CREATED="$(date)"
    st I "Creating LXC container: $VM_NAME"
    echo ""
    if command -v lxc-create &>/dev/null; then
        if [ "$OS_TYPE" = "ubuntu" ] || [ "$OS_TYPE" = "debian" ]; then
            run_live "lxc-create" lxc-create -t "$TEMPLATE" -n "$VM_NAME" -- -a "$ARCH" || {
                st E "lxc-create failed"; return 1
            }
        else
            run_live "lxc-create" lxc-create -t download -n "$VM_NAME" -- -d "$OS_TYPE" -r "$TEMPLATE" -a "$ARCH" || {
                st E "lxc-create failed"; return 1
            }
        fi
    else
        st E "lxc-create not found"; return 1
    fi

    local conf="/var/lib/lxc/$VM_NAME/config"
    if [ -f "$conf" ]; then
        {
            echo ""
            echo "lxc.cgroup.memory.limit_in_bytes = $((MEM_MB * 1024 * 1024))"
            echo "lxc.cgroup.cpuset.cpus = 0-$((CPUS - 1))"
        } >> "$conf"
    fi

    st I "Setting root password..."
    run_live "set-pass" lxc-attach -n "$VM_NAME" -- /bin/bash -c "echo 'root:$PASSWORD' | chpasswd" 2>/dev/null || true
    if [ "$USERNAME" != "root" ]; then
        run_live "create-user" lxc-attach -n "$VM_NAME" -- /bin/bash -c "useradd -m -s /bin/bash $USERNAME 2>/dev/null; echo '$USERNAME:$PASSWORD' | chpasswd" 2>/dev/null || true
    fi

    st I "Configuring SSH port $SSH_PORT..."
    lxc-attach -n "$VM_NAME" -- /bin/bash -c "
        if command -v apt-get &>/dev/null; then
            apt-get update -y -q 2>/dev/null
            apt-get install -y openssh-server 2>/dev/null
        elif command -v yum &>/dev/null; then
            yum install -y openssh-server 2>/dev/null
        fi
        mkdir -p /run/sshd
        sed -i 's/^#*Port .*/Port $SSH_PORT/' /etc/ssh/sshd_config 2>/dev/null
        sed -i 's/^#*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null
        sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
        systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true
    " 2>/dev/null || true

    save_cfg
    st S "LXC '$VM_NAME' created"
    st I "Login: $USERNAME / $PASSWORD"
    st I "SSH: ssh -p $SSH_PORT $USERNAME@localhost"
}

start_vm() {
    local n=$1
    load_cfg "$n" || return 1
    if is_running "$n"; then
        st W "Already running"
        return 0
    fi
    st I "Starting: $n"
    run_live "lxc-start" lxc-start -n "$n" -d || { st E "Start failed"; return 1; }
    sleep 2
    if is_running "$n"; then
        st S "Started: $n"
        st I "SSH: ssh -p $SSH_PORT $USERNAME@localhost"
    else
        st E "Failed to start"
    fi
}

stop_vm() {
    local n=$1
    load_cfg "$n" 2>/dev/null || true
    if is_running "$n"; then
        st I "Stopping: $n"
        run_live "lxc-stop" lxc-stop -n "$n" --reboot 2>/dev/null || lxc-stop -n "$n" -k 2>/dev/null || true
        sleep 1
        is_running "$n" && { lxc-stop -n "$n" -k 2>/dev/null; sleep 1; }
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
        st W "Container not running — starting..."
        start_vm "$n" || return 1
        sleep 2
    fi
    st I "Attaching to: $n"
    st I "Type 'exit' to leave"
    echo ""
    lxc-attach -n "$n" || true
    echo ""
    read -p "   Press Enter..."
}

run_cmd_vm() {
    local n=$1
    load_cfg "$n" || return 1
    if ! is_running "$n"; then
        st E "Container not running — start it first"; return 1
    fi
    read -p "$(st Q '  Command: ')" cmd
    [ -z "$cmd" ] && return
    echo ""
    lxc-attach -n "$n" -- /bin/bash -c "$cmd" || true
    echo ""
    read -p "   Press Enter..."
}

delete_vm() {
    local n=$1
    st W "Delete '$n' and ALL data?"
    read -p "$(st Q 'Confirm (y/N): ')" -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || { st I "Cancelled"; return; }
    load_cfg "$n" 2>/dev/null || true
    is_running "$n" && { lxc-stop -n "$n" -k 2>/dev/null; sleep 1; }
    run_live "lxc-destroy" lxc-destroy -n "$n" || true
    rm -f "$VM_DIR/$n.conf" 2>/dev/null
    st S "Deleted: $n"
}

show_info() {
    local n=$1
    load_cfg "$n" || return 1
    local st_run="${R}stopped${NC}"
    is_running "$n" && st_run="${G}running${NC}"
    local lxc_info=""
    lxc_info=$(lxc-info -n "$n" 2>/dev/null | grep -E "^(State|IP|Memory|CPU)" | head -6)
    echo ""
    echo -e "  ${CB}┌─── ${W}$n${CB} ──────────────────────────────────────┐${NC}"
    echo -e "  ${CB}│${NC} ${DG}OS:${NC}       $OS_TYPE"
    echo -e "  ${CB}│${NC} ${DG}Host:${NC}     $HOSTNAME"
    echo -e "  ${CB}│${NC} ${DG}User:${NC}     $USERNAME"
    echo -e "  ${CB}│${NC} ${DG}Pass:${NC}     $PASSWORD"
    echo -e "  ${CB}│${NC} ${DG}SSH Port:${NC} $SSH_PORT"
    echo -e "  ${CB}│${NC} ${DG}Memory:${NC}   ${MEM_MB}MB"
    echo -e "  ${CB}│${NC} ${DG}CPUs:${NC}     $CPUS"
    echo -e "  ${CB}│${NC} ${DG}Status:${NC}   $st_run"
    echo -e "  ${CB}│${NC} ${DG}Created:${NC}  $CREATED"
    echo -e "  ${CB}└─────────────────────────────────────────────┘${NC}"
    if [ -n "$lxc_info" ]; then
        echo ""
        echo "$lxc_info" | while read -r line; do echo -e "  ${DG}$line${NC}"; done
    fi
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
        echo "  4) SSH Port    5) Memory      6) CPUs"
        echo "  0) Back"
        echo ""
        read -p "   Choice: " c
        case $c in
            1) read -p "  Hostname [$HOSTNAME]: " v; HOSTNAME="${v:-$HOSTNAME}" ;;
            2) read -p "  Username [$USERNAME]: " v; USERNAME="${v:-$USERNAME}" ;;
            3) read -s -p "  Password [****]: " v; echo; PASSWORD="${v:-$PASSWORD}" ;;
            4) while true; do read -p "  SSH Port [$SSH_PORT]: " v; v="${v:-$SSH_PORT}"; vd port "$v" && { SSH_PORT="$v"; break; }; done ;;
            5) while true; do read -p "  Memory [$MEM_MB]: " v; v="${v:-$MEM_MB}"; vd number "$v" && { MEM_MB="$v"; break; }; done ;;
            6) while true; do read -p "  CPUs [$CPUS]: " v; v="${v:-$CPUS}"; vd number "$v" && { CPUS="$v"; break; }; done ;;
            0) return ;;
            *) continue ;;
        esac
        if [ -f "/var/lib/lxc/$n/config" ]; then
            sed -i "s/lxc.cgroup.memory.limit_in_bytes = .*/lxc.cgroup.memory.limit_in_bytes = $((MEM_MB * 1024 * 1024))/" "/var/lib/lxc/$n/config" 2>/dev/null || true
            sed -i "s/lxc.cgroup.cpuset.cpus = .*/lxc.cgroup.cpuset.cpus = 0-$((CPUS - 1))/" "/var/lib/lxc/$n/config" 2>/dev/null || true
        fi
        if [ "$c" = "3" ] && is_running "$n"; then
            lxc-attach -n "$n" -- /bin/bash -c "echo '$USERNAME:$PASSWORD' | chpasswd" 2>/dev/null || true
        fi
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
        local s="${R}■${NC}"
        is_running "${vms[$i]}" && s="${G}●${NC}"
        printf "    %d) %s %s\n" $((i+1)) "$s" "${vms[$i]}"
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
        echo -e "    ${GR}[2]${NC} Start container"
        echo -e "    ${GR}[3]${NC} Stop container"
        echo -e "    ${GR}[4]${NC} Attach (shell)"
        echo -e "    ${GR}[5]${NC} Run command"
        echo -e "    ${GR}[6]${NC} Container info"
        echo -e "    ${GR}[7]${NC} Edit config"
        echo -e "    ${GR}[8]${NC} Delete container"
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
