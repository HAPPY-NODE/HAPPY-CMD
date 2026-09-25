#!/bin/bash
set -e
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

st() {
    case $1 in
        OK)   echo -e "  ${G}✓${NC} $2" ;;
        ERR)  echo -e "  ${R}✗${NC} $2" ;;
        INFO) echo -e "  ${C}→${NC} $2" ;;
        WAIT) echo -e "  ${Y}⏳${NC} $2" ;;
        WARN) echo -e "  ${Y}!${NC} $2" ;;
    esac
}

msg_input() { read -rp "  $1: " INPUT; }

draw_header() {
    clear
    local host ip status
    host=$(hostname)
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    status="${R}● OFFLINE${NC}"
    if systemctl is-active --quiet wings 2>/dev/null; then
        status="${G}● ONLINE${NC}"
    fi
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     W I N G S   C O N F I G                  ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    HAPPY NODE • Configurator                 ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${W}Status:${NC}  $status  ${DG}│${NC}  ${DG}Host:${NC} ${W}${host}${NC}  ${DG}│${NC}  ${DG}IP:${NC} ${W}${ip}${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

draw_header
echo -e "  ${C}◆ CONFIGURATION WIZARD${NC}"
echo -e "  ${DG}Type 'back' for previous step. Enter keeps current value.${NC}"
echo ""

STEP=1
UUID=""
TOKEN_ID=""
TOKEN=""
API_PORT="8080"
REMOTE=""

while [ $STEP -le 6 ]; do
    case $STEP in
        1)
            [ -n "$UUID" ] && echo -e "  ${DG}(Current: $UUID)${NC}"
            msg_input "Node UUID"
            if [ "$INPUT" = "back" ]; then st WARN "Exiting"; exit 0
            elif [ -z "$INPUT" ] && [ -n "$UUID" ]; then STEP=$((STEP+1))
            elif [ -z "$INPUT" ]; then st ERR "UUID required"
            else UUID="$INPUT"; STEP=$((STEP+1)); fi
            ;;
        2)
            [ -n "$TOKEN_ID" ] && echo -e "  ${DG}(Current: $TOKEN_ID)${NC}"
            msg_input "Token ID"
            if [ "$INPUT" = "back" ]; then STEP=$((STEP-1))
            elif [ -z "$INPUT" ] && [ -n "$TOKEN_ID" ]; then STEP=$((STEP+1))
            elif [ -z "$INPUT" ]; then st ERR "Token ID required"
            else TOKEN_ID="$INPUT"; STEP=$((STEP+1)); fi
            ;;
        3)
            [ -n "$TOKEN" ] && echo -e "  ${DG}(Current: ************)${NC}"
            msg_input "Token Key"
            if [ "$INPUT" = "back" ]; then STEP=$((STEP-1))
            elif [ -z "$INPUT" ] && [ -n "$TOKEN" ]; then STEP=$((STEP+1))
            elif [ -z "$INPUT" ]; then st ERR "Token Key required"
            else TOKEN="$INPUT"; STEP=$((STEP+1)); fi
            ;;
        4)
            echo -e "  ${DG}(Default: 8080) — Enter to keep${NC}"
            msg_input "API Port"
            if [ "$INPUT" = "back" ]; then STEP=$((STEP-1))
            elif [ -z "$INPUT" ]; then st INFO "Using port $API_PORT"; STEP=$((STEP+1))
            elif [[ ! "$INPUT" =~ ^[0-9]+$ ]]; then st ERR "Must be a number"
            else API_PORT="$INPUT"; STEP=$((STEP+1)); fi
            ;;
        5)
            echo -e "  ${DG}(Default: https://panel.example.com)${NC}"
            msg_input "Panel URL"
            if [ "$INPUT" = "back" ]; then STEP=$((STEP-1))
            elif [ -z "$INPUT" ] && [ -n "$REMOTE" ]; then STEP=$((STEP+1))
            elif [ -z "$INPUT" ]; then REMOTE="https://panel.example.com"; st WARN "Using default URL"; STEP=$((STEP+1))
            elif [[ ! "$INPUT" =~ ^https?:// ]]; then st ERR "Use http:// or https://"
            else REMOTE="$INPUT"; STEP=$((STEP+1)); fi
            ;;
        6)
            echo ""
            echo -e "  ${C}◆ REVIEW SETTINGS${NC}"
            echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
            echo -e "  ${DG}•${NC} UUID      : ${W}$UUID${NC}"
            echo -e "  ${DG}•${NC} Token ID  : ${W}$TOKEN_ID${NC}"
            echo -e "  ${DG}•${NC} Token Key : ${W}****************${NC}"
            echo -e "  ${DG}•${NC} API Port  : ${W}$API_PORT${NC}"
            echo -e "  ${DG}•${NC} Remote    : ${W}$REMOTE${NC}"
            echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
            read -rp "  Apply configuration? [Y/n/back]: " CONFIRM
            if [ "$CONFIRM" = "back" ]; then STEP=$((STEP-1))
            elif [[ "$CONFIRM" =~ ^[Nn]$ ]]; then st ERR "Cancelled"; exit 0
            else break; fi
            ;;
    esac
done

echo ""
st WAIT "Generating configuration file..."
rm -f /etc/pterodactyl/config.yml
mkdir -p /etc/pterodactyl
cat > /etc/pterodactyl/config.yml <<CFG
debug: false
uuid: ${UUID}
token_id: ${TOKEN_ID}
token: ${TOKEN}
api:
  host: 0.0.0.0
  port: ${API_PORT}
  ssl:
    enabled: true
    cert: /etc/certs/wing/fullchain.pem
    key: /etc/certs/wing/privkey.pem
  upload_limit: 100
system:
  data: /var/lib/pterodactyl/volumes
  sftp:
    bind_port: 2022
allowed_mounts: []
remote: '${REMOTE}'
CFG
st OK "Config written: /etc/pterodactyl/config.yml"

echo ""
st WAIT "Restarting Wings..."
systemctl enable wings >/dev/null 2>&1 || true
run_live "wings-restart" systemctl restart wings || true
sleep 2
if systemctl is-active --quiet wings 2>/dev/null; then
    st OK "Wings is active & running"
    echo ""
    echo -e "  ${C}◆ DEBUG${NC}"
    echo -e "  ${W}systemctl status wings${NC}"
    echo -e "  ${W}journalctl -u wings -f${NC}"
else
    st ERR "Service failed to start"
    st INFO "Check: journalctl -u wings -n 20"
    exit 1
fi
