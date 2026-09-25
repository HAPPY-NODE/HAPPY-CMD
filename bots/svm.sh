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
IMG_URL="https://i.postimg.cc/jdbphsXP/Chat-GPT-Image-Sep-23-2026-05-48-16-PM.png"
BOT_HOME="${BOT_HOME:-/root/happy-svm-bot}"
UNIT="happy-svm-bot.service"
SRC_REL="bots/svm-bot"

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
    echo -e "  ${CB}│${FW}     S V M   V 9   L X C   B O T             ${CB}│${NC}"
    echo -e "  ${CB}│${FY}    HAPPY NODE • multi-node installer         ${CB}│${NC}"
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

install_lxd() {
    if command -v lxc >/dev/null 2>&1; then
        st OK "LXC already installed"
        return 0
    fi
    st WAIT "Installing LXD/LXC (this can take a few minutes)..."
    if command -v snap >/dev/null 2>&1 || apt-get install -y snapd >/dev/null 2>&1; then
        systemctl enable --now snapd.socket >/dev/null 2>&1 || true
        snap install lxd >/dev/null 2>&1 || st WARN "snap lxd install had issues"
        lxd init --auto >/dev/null 2>&1 || true
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get install -y lxc lxc-utils bridge-utils uidmap >/dev/null 2>&1 || true
    fi
    command -v lxc >/dev/null 2>&1 && st OK "LXC ready" || st WARN "LXC may need manual setup"
}

deploy_bot() {
    st WAIT "Creating $BOT_HOME ..."
    mkdir -p "$BOT_HOME"
    fetch_src "$SRC_REL/bot.py" "$BOT_HOME/bot.py" "$ROOT/bots/svm-bot/bot.py" || return 1
}

prompt_env() {
    echo ""
    echo -e "  ${FC}◆${NC} ${FW}Bot Configuration${NC} ${SL}(only 2 inputs — rest uses defaults)${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    printf "  ${CY}1) Discord Bot Token:${NC} "
    read -r DISCORD_TOKEN || { echo ""; st ERR "Aborted."; return 1; }
    printf "  ${CY}2) Main Admin Discord ID (comma-sep ok):${NC} "
    read -r MAIN_ADMIN_ID || { echo ""; st ERR "Aborted."; return 1; }

    if [ -z "$DISCORD_TOKEN" ] || [ -z "$MAIN_ADMIN_ID" ]; then
        st ERR "Token and Admin ID cannot be empty."
        return 1
    fi

    # defaults — no prompts
    BOT_NAME="HAPPY NODE"
    PREFIX="!"
    BOT_VERSION="v9.0-PRO"
    BOT_DEVELOPER="HAPPY-NODE"
    VPS_USER_ROLE_ID="0"
    DEFAULT_STORAGE_POOL="default"

    mkdir -p "$BOT_HOME" || { st ERR "Cannot create $BOT_HOME"; return 1; }
    if ! cat > "$BOT_HOME/.env" <<EOF
DISCORD_TOKEN=$DISCORD_TOKEN
MAIN_ADMIN_ID=$MAIN_ADMIN_ID
BOT_NAME=$BOT_NAME
PREFIX=$PREFIX
BOT_VERSION=$BOT_VERSION
BOT_DEVELOPER=$BOT_DEVELOPER
VPS_USER_ROLE_ID=$VPS_USER_ROLE_ID
DEFAULT_STORAGE_POOL=$DEFAULT_STORAGE_POOL
EOF
    then
        st ERR ".env write failed — cannot create $BOT_HOME/.env"
        return 1
    fi
    chmod 600 "$BOT_HOME/.env" 2>/dev/null || true
    if [ -s "$BOT_HOME/.env" ]; then
        st OK ".env written → $BOT_HOME/.env"
        st INFO "Defaults set — edit that file anytime to customize"
    else
        st ERR ".env write failed"
        return 1
    fi
}

install_deps() {
    st WAIT "Installing Python dependencies (discord.py, requests)..."
    python3 -m pip install -U discord.py requests >/dev/null 2>&1 \
        || pip3 install -U discord.py requests >/dev/null 2>&1 \
        || st WARN "pip reported warnings"
    st OK "Dependencies installed"
}

create_service() {
    if [ ! -d /etc/systemd/system ]; then
        st WARN "systemd not found — service skipped"
        return 0
    fi
    st WAIT "Creating systemd unit $UNIT ..."
    cat > "/etc/systemd/system/$UNIT" <<EOF
[Unit]
Description=HAPPY NODE SVM V9 LXC Discord Bot
After=network.target

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
    systemctl daemon-reload 2>/dev/null || { st WARN "daemon-reload failed"; return 0; }
    systemctl enable "$UNIT" >/dev/null 2>&1 || true
    systemctl restart "$UNIT" 2>/dev/null || st WARN "restart failed"
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
    echo -e "  ${SL}image${NC}    ${CB}$IMG_URL${NC}"
    echo -e "  ${CY}────────────────────────────────────────────────────────────────${NC}"
}

main() {
    print_banner
    if [ "$EUID" -ne 0 ] && [ "${HN_NO_ROOT_CHECK:-}" != 1 ]; then
        st ERR "Run as root"
        pause
        return 1
    fi
    prompt_env || { pause; return 1; }
    install_python || { pause; return 1; }
    install_lxd
    deploy_bot || { pause; return 1; }
    install_deps
    create_service
    final_message
    pause
}

main "$@"
