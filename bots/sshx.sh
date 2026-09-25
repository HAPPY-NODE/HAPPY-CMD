#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
source "$ROOT/colors.sh"

HN_BASE_URL="https://raw.githubusercontent.com/HAPPY-NODE/HAPPY-CMD/main"
IMG_URL="https://i.postimg.cc/jdbphsXP/Chat-GPT-Image-Sep-23-2026-05-48-16-PM.png"
BOT_HOME="/root/happy-sshx-bot"
UNIT="happy-sshx-bot.service"
SRC_REL="bots/sshx-bot"

st() {
    case $1 in
        OK)   echo -e "  ${FG}✓${NC} $2" ;;
        ERR)  echo -e "  ${FR}✗${NC} $2" ;;
        INFO) echo -e "  ${FC}→${NC} $2" ;;
        WAIT) echo -e "  ${FY}⏳${NC} $2" ;;
        WARN) echo -e "  ${FY}!${NC} $2" ;;
    esac
}
pause() { echo ""; read -rp "  Press Enter to continue... " _; }

print_banner() {
    clear
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${FW}     D O C K E R   S S H X   B O T            ${CB}│${NC}"
    echo -e "  ${CB}│${VI}    HAPPY NODE • browser ssh access           ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

fetch_src() {
    local rel="$1" out="$2" local_path="$3"
    if [ -f "$local_path" ]; then
        cp "$local_path" "$out" && st OK "Copied $(basename "$out") (local)" && return 0
    fi
    run_dl "$(basename "$out")" "$HN_BASE_URL/$rel" "$out"
}

install_python() {
    st WAIT "Installing Python 3 + pip..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y python3 python3-pip >/dev/null 2>&1 || st WARN "apt install had warnings"
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y python3 python3-pip >/dev/null 2>&1 || true
    elif command -v yum >/dev/null 2>&1; then
        yum install -y python3 python3-pip >/dev/null 2>&1 || true
    fi
    mkdir -p ~/.config/pip
    printf '[global]\nbreak-system-packages = true\n' > ~/.config/pip/pip.conf
    command -v python3 >/dev/null 2>&1 && st OK "Python ready" || { st ERR "Python not found"; return 1; }
}

deploy_bot() {
    st WAIT "Creating $BOT_HOME ..."
    mkdir -p "$BOT_HOME"
    fetch_src "$SRC_REL/bot.py" "$BOT_HOME/bot.py" "$ROOT/bots/sshx-bot/bot.py" || return 1
    fetch_src "$SRC_REL/requirements.txt" "$BOT_HOME/requirements.txt" "$ROOT/bots/sshx-bot/requirements.txt" || return 1
}

prompt_env() {
    echo ""
    echo -e "  ${FC}◆${NC} ${FW}Bot Configuration${NC} ${SL}(token → admin id → optional)${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    read -rp "  ${CY}1) Discord Bot Token:${NC} " TOKEN
    read -rp "  ${CY}2) Admin Discord ID:${NC} " ADMIN_ID
    read -rp "  ${CY}3) Status name [HAPPY NODE]:${NC} " BOT_STATUS_NAME
    BOT_STATUS_NAME="${BOT_STATUS_NAME:-HAPPY NODE}"
    read -rp "  ${CY}4) Watermark [Powered by HAPPY NODE VPS Bot]:${NC} " WATERMARK
    WATERMARK="${WATERMARK:-Powered by HAPPY NODE VPS Bot}"
    read -rp "  ${CY}5) Default RAM [2g]:${NC} " DEFAULT_RAM
    DEFAULT_RAM="${DEFAULT_RAM:-2g}"
    read -rp "  ${CY}6) Default CPU [1]:${NC} " DEFAULT_CPU
    DEFAULT_CPU="${DEFAULT_CPU:-1}"
    read -rp "  ${CY}7) Default Disk [5G]:${NC} " DEFAULT_DISK
    DEFAULT_DISK="${DEFAULT_DISK:-5G}"
    read -rp "  ${CY}8) Hostname prefix [happy-node]:${NC} " VPS_HOSTNAME
    VPS_HOSTNAME="${VPS_HOSTNAME:-happy-node}"
    read -rp "  ${CY}9) Per-user server limit [3]:${NC} " SERVER_LIMIT
    SERVER_LIMIT="${SERVER_LIMIT:-3}"
    read -rp "  ${CY}10) Total server limit [50]:${NC} " TOTAL_SERVER_LIMIT
    TOTAL_SERVER_LIMIT="${TOTAL_SERVER_LIMIT:-50}"

    if [ -z "$TOKEN" ] || [ -z "$ADMIN_ID" ]; then
        st ERR "Token and Admin ID cannot be empty."
        return 1
    fi

    cat > "$BOT_HOME/.env" <<EOF
TOKEN=$TOKEN
ADMIN_ID=$ADMIN_ID
BOT_STATUS_NAME=$BOT_STATUS_NAME
WATERMARK=$WATERMARK
DEFAULT_RAM=$DEFAULT_RAM
DEFAULT_CPU=$DEFAULT_CPU
DEFAULT_DISK=$DEFAULT_DISK
VPS_HOSTNAME=$VPS_HOSTNAME
SERVER_LIMIT=$SERVER_LIMIT
TOTAL_SERVER_LIMIT=$TOTAL_SERVER_LIMIT
DATABASE_FILE=vps_bot.db
EOF
    chmod 600 "$BOT_HOME/.env"
    st OK ".env written"
}

install_deps() {
    st WAIT "Installing Python dependencies..."
    python3 -m pip install -U -r "$BOT_HOME/requirements.txt" >/dev/null 2>&1 \
        || pip3 install -U -r "$BOT_HOME/requirements.txt" >/dev/null 2>&1 \
        || st WARN "pip reported warnings — check requirements"
    st OK "Dependencies installed"
}

create_service() {
    st WAIT "Creating systemd unit $UNIT ..."
    cat > "/etc/systemd/system/$UNIT" <<EOF
[Unit]
Description=HAPPY NODE Docker SSHX Discord Bot
After=network.target docker.service
Wants=docker.service

[Service]
User=root
WorkingDirectory=$BOT_HOME
ExecStart=/usr/bin/python3 $BOT_HOME/bot.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=$BOT_HOME/.env

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "$UNIT" >/dev/null 2>&1 || true
    systemctl restart "$UNIT"
    sleep 1
    if systemctl is-active --quiet "$UNIT"; then
        st OK "Service active"
    else
        st WARN "Service not active yet — check: journalctl -u $UNIT -f"
    fi
}

final_message() {
    echo ""
    echo -e "  ${CY}────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${FG}  Installation complete!${NC}"
    echo -e "  ${CY}────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${SL}home${NC}     ${CB}$BOT_HOME${NC}"
    echo -e "  ${SL}service${NC}  ${CB}$UNIT${NC}"
    echo -e "  ${SL}status${NC}   ${CB}systemctl status $UNIT${NC}"
    echo -e "  ${SL}logs${NC}     ${CB}journalctl -u $UNIT -f${NC}"
    echo -e "  ${SL}restart${NC}  ${CB}systemctl restart $UNIT${NC}"
    echo -e "  ${SL}ssh${NC}      ${CB}browser link via sshx.io in Discord${NC}"
    echo -e "  ${SL}image${NC}    ${CB}$IMG_URL${NC}"
    echo -e "  ${CY}────────────────────────────────────────────────────────────────${NC}"
}

main() {
    print_banner
    if [ "$EUID" -ne 0 ]; then
        st ERR "Run as root"
        pause
        return 1
    fi
    command -v docker >/dev/null 2>&1 \
        && st OK "Docker found" \
        || st WARN "Docker not found — install Wings/Docker first for this bot"
    prompt_env || { pause; return 1; }
    install_python || { pause; return 1; }
    deploy_bot || { pause; return 1; }
    install_deps
    create_service
    final_message
    pause
}

main "$@"
