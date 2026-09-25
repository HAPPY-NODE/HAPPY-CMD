#!/bin/bash
set -uo pipefail

# =============================
# HAPPY-CMD Docker VPS Manager
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
VM_DIR="${VM_DIR:-$HOME/vms-docker}"

run_live() {
    local msg="$1"; shift
    local log; log="$(mktemp /tmp/hn_live.XXXXXX)"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0 rc line
    "$@" >"$log" 2>&1 &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        line=$(grep -E '^(Get:|Hit:|Unpacking:|Setting up:|Selecting:|Preparing:|Downloading:|Extracting:|Processing:|Building:|Step |Successfully|Pulling|Pull complete)' "$log" 2>/dev/null | tail -1)
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
    echo -e "  ${CB}│${DG}       HAPPY  NODE  •  DOCKER  MODE           ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    local total=0 running=0
    if command -v docker &>/dev/null; then
        total=$(docker ps -aq 2>/dev/null | wc -l)
        running=$(docker ps -q 2>/dev/null | wc -l)
    fi
    echo -e "  ${DG}Mode:${NC} ${C}DOCKER${NC}  ${DG}│${NC}  ${DG}Running:${NC} ${G}${running}${NC}${DG}/${NC}${total}  ${DG}│${NC}  ${DG}Dir:${NC} /var/lib/docker"
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
    if ! command -v docker &>/dev/null; then
        st I "Docker missing — installing..."
        echo ""
        if command -v curl &>/dev/null; then
            run_live "docker-install" bash -c 'curl -fsSL https://get.docker.com/ | CHANNEL=stable bash'
        elif command -v wget &>/dev/null; then
            run_live "docker-install" bash -c 'wget -qO- https://get.docker.com/ | sh'
        else
            if command -v apt-get &>/dev/null; then
                run_live "apt-install" env DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io
            else
                st E "Cannot install Docker"; return 1
            fi
        fi
        systemctl enable docker 2>/dev/null || true
        systemctl start docker 2>/dev/null || true
        sleep 2
        if ! command -v docker &>/dev/null; then
            st E "Docker install failed"; return 1
        fi
        st S "Docker ready"
    fi
}

get_list() {
    docker ps -a --format '{{.Names}}' 2>/dev/null | grep -v '^$' | sort
}

is_running() {
    [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = "true" ]
}

save_cfg() {
    mkdir -p "$VM_DIR"
    cat > "$VM_DIR/$VM_NAME.conf" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
IMAGE="$IMAGE"
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
    if [ -f "$f" ]; then
        unset VM_NAME OS_TYPE IMAGE HOSTNAME USERNAME PASSWORD SSH_PORT MEM_MB CPUS CREATED
        source "$f"
        return 0
    fi
    # fallback: inspect docker
    if docker inspect "$n" &>/dev/null; then
        VM_NAME="$n"
        IMAGE=$(docker inspect -f '{{.Config.Image}}' "$n" 2>/dev/null)
        SSH_PORT=$(docker inspect -f '{{(index (index .NetworkSettings.Ports "22/tcp") 0).HostPort}}' "$n" 2>/dev/null)
        [ -z "$SSH_PORT" ] && SSH_PORT="?"
        USERNAME="root"
        PASSWORD="?"
        HOSTNAME="$n"
        OS_TYPE="$IMAGE"
        MEM_MB="?"
        CPUS="?"
        CREATED=$(docker inspect -f '{{.Created}}' "$n" 2>/dev/null | cut -dT -f1)
        return 0
    fi
    st E "Container not found: $n"; return 1
}

declare -A OS_OPTS=(
    ["Ubuntu 22.04"]="ubuntu:22.04|ubuntu22"
    ["Ubuntu 24.04"]="ubuntu:24.04|ubuntu24"
    ["Debian 12"]="debian:12|debian12"
    ["Alpine 3.19"]="alpine:3.19|alpine319"
    ["CentOS Stream 9"]="quay.io/centos/centos:stream9|centos9"
    ["Fedora 39"]="fedora:39|fedora39"
    ["Arch Linux"]="archlinux:latest|arch"
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
    IFS='|' read -r IMAGE DEF_HOST <<< "${OS_OPTS[$os]}"
    OS_TYPE="$os"

    while true; do
        read -p "$(st Q "  Container name [$DEF_HOST]: ")" VM_NAME
        VM_NAME="${VM_NAME:-$DEF_HOST}"
        vd name "$VM_NAME" && { docker inspect "$VM_NAME" &>/dev/null && st E "Exists" || break; }
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
    while true; do
        read -p "$(st Q "  Memory MB [512]: ")" MEM_MB
        MEM_MB="${MEM_MB:-512}"
        vd number "$MEM_MB" && break
    done
    while true; do
        read -p "$(st Q "  CPUs [1]: ")" CPUS
        CPUS="${CPUS:-1}"
        vd number "$CPUS" && break
    done

    CREATED="$(date)"
    st I "Pulling image: $IMAGE"
    echo ""
    run_live "docker-pull" docker pull "$IMAGE" || { st E "Pull failed"; return 1; }

    st I "Creating container: $VM_NAME"
    echo ""
    run_live "docker-run" docker run -d \
        --name "$VM_NAME" \
        --hostname "$HOSTNAME" \
        -p "$SSH_PORT:22" \
        --memory "${MEM_MB}m" \
        --cpus "$CPUS" \
        --restart unless-stopped \
        "$IMAGE" \
        sleep infinity || { st E "Run failed"; return 1; }

    st I "Installing SSH + configuring..."
    run_live "setup" docker exec "$VM_NAME" /bin/bash -c "
        export DEBIAN_FRONTEND=noninteractive
        if command -v apt-get &>/dev/null; then
            apt-get update -y -q 2>/dev/null
            apt-get install -y openssh-server sudo 2>/dev/null
        elif command -v yum &>/dev/null; then
            yum install -y openssh-server sudo 2>/dev/null
        elif command -v apk &>/dev/null; then
            apk add --no-cache openssh sudo 2>/dev/null
            echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
        elif command -v pacman &>/dev/null; then
            pacman -Sy --noconfirm openssh 2>/dev/null
        fi
        mkdir -p /run/sshd /root/.ssh
        echo 'root:$PASSWORD' | chpasswd
        if [ '$USERNAME' != 'root' ]; then
            useradd -m -s /bin/bash '$USERNAME' 2>/dev/null || true
            echo '$USERNAME:$PASSWORD' | chpasswd
            usermod -aG sudo '$USERNAME' 2>/dev/null || usermod -aG wheel '$USERNAME' 2>/dev/null || true
        fi
        sed -i 's/^#*Port .*/Port 22/' /etc/ssh/sshd_config 2>/dev/null
        sed -i 's/^#*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null
        sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
        (command -v sshd &>/dev/null && /usr/sbin/sshd) || (command -v ssh &>/dev/null && rc-service sshd start 2>/dev/null) || true
    " || st WARN "SSH setup had warnings (check manually)"

    save_cfg
    st S "Container '$VM_NAME' created"
    st I "Login: $USERNAME / $PASSWORD"
    st I "SSH: ssh -p $SSH_PORT $USERNAME@localhost"
}

start_vm() {
    local n=$1
    load_cfg "$n" || return 1
    if is_running "$n"; then
        st W "Already running"; return 0
    fi
    st I "Starting: $n"
    run_live "docker-start" docker start "$n" || { st E "Start failed"; return 1; }
    sleep 1
    docker exec "$n" /bin/bash -c 'command -v sshd &>/dev/null && /usr/sbin/sshd' 2>/dev/null || true
    if is_running "$n"; then
        st S "Started: $n"
        [ -n "${SSH_PORT:-}" ] && [ "$SSH_PORT" != "?" ] && st I "SSH: ssh -p $SSH_PORT ${USERNAME:-root}@localhost"
    else
        st E "Failed"
    fi
}

stop_vm() {
    local n=$1
    if is_running "$n"; then
        st I "Stopping: $n"
        run_live "docker-stop" docker stop "$n" || true
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
        sleep 1
    fi
    st I "Attaching to: $n"
    st I "Type 'exit' to leave"
    echo ""
    docker exec -it "$n" /bin/bash 2>/dev/null || docker exec -it "$n" /bin/sh || true
    echo ""
    read -p "   Press Enter..."
}

run_cmd_vm() {
    local n=$1
    load_cfg "$n" || return 1
    if ! is_running "$n"; then
        st E "Container not running"; return 1
    fi
    read -p "$(st Q '  Command: ')" cmd
    [ -z "$cmd" ] && return
    echo ""
    docker exec "$n" /bin/bash -c "$cmd" 2>/dev/null || docker exec "$n" /bin/sh -c "$cmd" || true
    echo ""
    read -p "   Press Enter..."
}

delete_vm() {
    local n=$1
    st W "Delete '$n' and ALL data?"
    read -p "$(st Q 'Confirm (y/N): ')" -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || { st I "Cancelled"; return; }
    if is_running "$n"; then
        run_live "docker-stop" docker stop "$n" 2>/dev/null || true
    fi
    run_live "docker-rm" docker rm -f "$n" 2>/dev/null || true
    rm -f "$VM_DIR/$n.conf" 2>/dev/null
    st S "Deleted: $n"
}

show_info() {
    local n=$1
    load_cfg "$n" || return 1
    local st_run="${R}stopped${NC}"
    is_running "$n" && st_run="${G}running${NC}"
    local inspect=""
    inspect=$(docker inspect "$n" 2>/dev/null | grep -E '"Memory"|"NanoCpus"|"Image"|"Created"' | head -6)
    echo ""
    echo -e "  ${CB}┌─── ${W}$n${CB} ──────────────────────────────────────┐${NC}"
    echo -e "  ${CB}│${NC} ${DG}OS:${NC}       ${OS_TYPE:-?}"
    echo -e "  ${CB}│${NC} ${DG}Image:${NC}    ${IMAGE:-?}"
    echo -e "  ${CB}│${NC} ${DG}Host:${NC}     ${HOSTNAME:-?}"
    echo -e "  ${CB}│${NC} ${DG}User:${NC}     ${USERNAME:-root}"
    echo -e "  ${CB}│${NC} ${DG}Pass:${NC}     ${PASSWORD:-?}"
    echo -e "  ${CB}│${NC} ${DG}SSH Port:${NC} ${SSH_PORT:-?}"
    echo -e "  ${CB}│${NC} ${DG}Memory:${NC}   ${MEM_MB:-?}MB"
    echo -e "  ${CB}│${NC} ${DG}CPUs:${NC}     ${CPUS:-?}"
    echo -e "  ${CB}│${NC} ${DG}Status:${NC}   $st_run"
    echo -e "  ${CB}│${NC} ${DG}Created:${NC}  ${CREATED:-?}"
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
        echo "  ${DG}(Memory/CPUs need container recreate)${NC}"
        echo ""
        read -p "   Choice: " c
        case $c in
            1) read -p "  Hostname [$HOSTNAME]: " v; HOSTNAME="${v:-$HOSTNAME}"
               docker rename "$n" "$HOSTNAME" 2>/dev/null || true
               docker update --hostname "$HOSTNAME" "$n" 2>/dev/null || true ;;
            2) read -p "  Username [$USERNAME]: " v; USERNAME="${v:-$USERNAME}" ;;
            3) read -s -p "  Password [****]: " v; echo; PASSWORD="${v:-$PASSWORD}"
               is_running "$n" && docker exec "$n" /bin/bash -c "echo '$USERNAME:$PASSWORD' | chpasswd" 2>/dev/null || true ;;
            4) read -p "  SSH Port [$SSH_PORT]: " v
               if [ -n "$v" ] && [ "$v" != "$SSH_PORT" ]; then
                   st I "Note: port change needs recreate"; SSH_PORT="$v"
               fi ;;
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
