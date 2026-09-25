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
BOT_HOME="${BOT_HOME:-/root/happy-lxc-bot}"
UNIT="happy-lxc-bot.service"
SRC_REL="bots/lxc-bot"

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
    echo -e "  ${CB}│${FW}     L X C   V P S   B O T                   ${CB}│${NC}"
    echo -e "  ${CB}│${GR}    HAPPY NODE • prefix + economy             ${CB}│${NC}"
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
    fetch_src "$SRC_REL/bot.py" "$BOT_HOME/bot.py" "$ROOT/bots/lxc-bot/bot.py" || return 1
    fetch_src "$SRC_REL/requirements.txt" "$BOT_HOME/requirements.txt" "$ROOT/bots/lxc-bot/requirements.txt" || return 1
}

prompt_env() {
    echo ""
    echo -e "  ${FC}◆${NC} ${FW}Bot Configuration${NC} ${SL}(only 2 inputs — rest uses defaults)${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    printf "  ${CY}1) Discord Bot Token:${NC} "
    read -r DISCORD_TOKEN || { echo ""; st ERR "Aborted."; return 1; }
    printf "  ${CY}2) Main Admin Discord ID:${NC} "
    read -r MAIN_ADMIN_ID || { echo ""; st ERR "Aborted."; return 1; }

    if [ -z "$DISCORD_TOKEN" ] || [ -z "$MAIN_ADMIN_ID" ]; then
        st ERR "Token and Admin ID cannot be empty."
        return 1
    fi
    if ! [[ "$MAIN_ADMIN_ID" =~ ^[0-9]+$ ]]; then
        st ERR "Admin ID must be a numeric Discord user ID"
        return 1
    fi
    # catch: admin id set to the BOT's own id (decoded from token) -> commands ignored
    local bid="${DISCORD_TOKEN%%.*}"
    bid="${bid}$(printf '%*s' $(( (4 - ${#bid} % 4) % 4 )) '' | tr ' ' '=')"
    bid=$(printf '%s' "$bid" | base64 -d 2>/dev/null | grep -oE '^[0-9]+' || true)
    if [ -n "$bid" ] && [ "$bid" = "$MAIN_ADMIN_ID" ]; then
        st WARN "Admin ID $MAIN_ADMIN_ID is the BOT's own ID — bot will IGNORE every command!"
        st INFO "Enable Developer Mode → right-click YOU → Copy User ID (that is YOUR id)"
    fi
    [[ "$DISCORD_TOKEN" == *.* ]] || st WARN "Token looks odd (no dots) — double-check it"

    # defaults — no prompts
    BOT_NAME="HAPPY NODE"
    PREFIX="!"
    BOT_VERSION="v8.0-PRO"
    BOT_DEVELOPER="HAPPY-NODE"
    YOUR_SERVER_IP="127.0.0.1"
    VPS_USER_ROLE_ID="0"
    DEFAULT_STORAGE_POOL="default"

    mkdir -p "$BOT_HOME" || { st ERR "Cannot create $BOT_HOME"; return 1; }
    if ! cat > "$BOT_HOME/.env" <<EOF
DISCORD_TOKEN=$DISCORD_TOKEN
BOT_NAME=$BOT_NAME
PREFIX=$PREFIX
BOT_VERSION=$BOT_VERSION
BOT_DEVELOPER=$BOT_DEVELOPER
MAIN_ADMIN_ID=$MAIN_ADMIN_ID
VPS_USER_ROLE_ID=$VPS_USER_ROLE_ID
YOUR_SERVER_IP=$YOUR_SERVER_IP
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
    st WAIT "Installing Python dependencies..."
    local log rc
    log="$(mktemp /tmp/hn_pip.XXXXXX)"
    python3 -m pip install -U -r "$BOT_HOME/requirements.txt" >"$log" 2>&1 \
        || pip3 install -U -r "$BOT_HOME/requirements.txt" >>"$log" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
        st WARN "pip reported errors — last lines:"
        tail -n 8 "$log" | sed 's/^/    /'
    fi
    rm -f "$log"
    local miss=0
    python3 -c "import discord" 2>/dev/null || { st ERR "missing: discord.py"; miss=1; }
    python3 -c "import dotenv" 2>/dev/null || { st ERR "missing: python-dotenv"; miss=1; }
    python3 -c "import requests" 2>/dev/null || { st ERR "missing: requests"; miss=1; }
    if [ "$miss" = 1 ]; then
        st ERR "Import check failed — bot cannot start"
        st INFO "retry: python3 -m pip install -U -r $BOT_HOME/requirements.txt"
        return 1
    fi
    st OK "Dependencies verified"
}

smoke_test() {
    SMOKE_OK=1
    if ! command -v timeout >/dev/null 2>&1; then
        st WARN "timeout not found — skipping smoke test"
        return 0
    fi
    st WAIT "Smoke test: running the bot for 12 seconds..."
    local log rc
    log="$(mktemp /tmp/hn_smoke.XXXXXX)"
    ( cd "$BOT_HOME" && timeout 12 python3 bot.py ) >"$log" 2>&1
    rc=$?
    if [ "$rc" = 124 ]; then
        st OK "Bot stayed alive — Discord login OK"
        rm -f "$log"
        return 0
    fi
    SMOKE_OK=0
    st ERR "Bot crashed on startup:"
    tail -n 12 "$log" | sed 's/^/    /'
    rm -f "$log"
    return 1
}

create_service() {
    if [ ! -d /etc/systemd/system ]; then
        st WARN "systemd not found — service skipped"
        return 0
    fi
    st WAIT "Creating systemd unit $UNIT ..."
    cat > "/etc/systemd/system/$UNIT" <<EOF
[Unit]
Description=HAPPY NODE LXC VPS Discord Bot
After=network.target

[Service]
User=root
WorkingDirectory=$BOT_HOME
ExecStart=/usr/bin/python3 $BOT_HOME/bot.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=$BOT_HOME/.env
StandardOutput=journal
StandardError=journal
SyslogIdentifier=happy-lxc-bot

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload 2>/dev/null || { st WARN "daemon-reload failed"; return 0; }
    if [ "${SMOKE_OK:-1}" != 1 ]; then
        st WARN "Service written but NOT started (smoke test failed)"
        st INFO "Fix $BOT_HOME/.env, then: systemctl enable --now $UNIT"
        return 0
    fi
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
    if ! command -v lxc >/dev/null 2>&1; then
        st WARN "LXC not found — install LXD/LXC first for this bot"
    else
        st OK "LXC found"
    fi
    prompt_env || { pause; return 1; }
    install_python || { pause; return 1; }
    deploy_bot || { pause; return 1; }
    install_deps || { st ERR "Dependencies missing — fix pip errors above"; pause; return 1; }
    smoke_test
    create_service
    final_message
    if [ "${SMOKE_OK:-1}" != 1 ]; then
        echo ""
        st ERR "Bot did NOT stay alive — edit $BOT_HOME/.env (token/admin id)"
        st INFO "then: systemctl enable --now $UNIT"
    fi
    pause
}

main "$@"
