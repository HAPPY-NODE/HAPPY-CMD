#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
source "$ROOT/colors.sh"

SERVICE="wings"

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

get_status() {
    if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
        echo "${G}ACTIVE${NC}"
    else
        echo "${R}INACTIVE${NC}"
    fi
}

show_header() {
    clear
    local STATUS UPTIME
    STATUS=$(get_status)
    UPTIME=$(systemctl show -p ActiveEnterTimestamp "$SERVICE" 2>/dev/null | cut -d= -f2)
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     W I N G S   C O N T R O L                ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    HAPPY NODE • Service Manager               ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${DG}Service:${NC} ${W}$SERVICE${NC}  ${DG}│${NC}  ${DG}Status:${NC} $STATUS  ${DG}│${NC}  ${DG}Since:${NC} ${W}${UPTIME:-N/A}${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

create_node_ssl() {
    st WAIT "Public domain node (auto SSL)..."
    local DEFAULT_DOMAIN DOMAIN
    DEFAULT_DOMAIN=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "")
    read -rp "  Enter Domain [${DEFAULT_DOMAIN}]: " DOMAIN
    DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}
    if [ -z "$DOMAIN" ]; then st ERR "No domain"; return; fi
    run_live "certbot" env DEBIAN_FRONTEND=noninteractive apt-get install -y certbot python3-certbot-nginx || true
    rm -rf "/etc/letsencrypt/live/$DOMAIN" "/etc/pterodactyl" 2>/dev/null
    certbot certonly --nginx -d "$DOMAIN" --non-interactive --agree-tos \
        --email "ssl$(tr -dc a-z0-9 </dev/urandom | head -c6)@$DOMAIN" 2>/dev/null || st WARN "Certbot issue"
    cd /var/www/pterodactyl || return
    local LAST_NUM NEXT_NUM NODE_NAME
    LAST_NUM=$(php artisan p:node:list 2>/dev/null | grep -oP 'Node - \K[0-9]+' | sort -n | tail -1)
    if [ -z "$LAST_NUM" ]; then NEXT_NUM=1; else NEXT_NUM=$((LAST_NUM + 1)); fi
    NODE_NAME="Node - $NEXT_NUM"
    printf "%s\nVPS: %s | IP: %s | RAM: %sMB | Location: IN\n1\nhttps\n%s\ny\nn\nn\n99999\n0\n99999\n0\n1024\n8080\n2022\n/var/lib/pterodactyl/volumes\n" \
        "$NODE_NAME" "$(hostname)" "$(curl -s --max-time 5 ifconfig.me)" \
        "$(free -m 2>/dev/null | awk '/Mem:/ {print $2}')" "$DOMAIN" | php artisan p:node:make >/dev/null 2>&1
    st OK "Node created with SSL ($DOMAIN)"
}

create_node_local() {
    st WAIT "Local IP node (manual)..."
    local DEFAULT_IP DOMAIN
    DEFAULT_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    read -rp "  Enter Domain/IP [${DEFAULT_IP}]: " DOMAIN
    DOMAIN=${DOMAIN:-$DEFAULT_IP}
    if [ -z "$DOMAIN" ]; then st ERR "No host"; return; fi
    cd /var/www/pterodactyl || return
    local LAST_NUM NEXT_NUM NODE_NAME
    LAST_NUM=$(php artisan p:node:list 2>/dev/null | grep -oP 'Node - \K[0-9]+' | sort -n | tail -1)
    if [ -z "$LAST_NUM" ]; then NEXT_NUM=1; else NEXT_NUM=$((LAST_NUM + 1)); fi
    NODE_NAME="Node - $NEXT_NUM"
    printf "%s\nVPS: %s | IP: %s | RAM: %sMB | Location: IN\n1\nhttps\n%s\ny\nn\nn\n99999\n0\n99999\n0\n1024\n443\n2022\n/var/lib/pterodactyl/volumes\n" \
        "$NODE_NAME" "$(hostname)" "$(hostname -I 2>/dev/null | awk '{print $1}')" \
        "$(free -m 2>/dev/null | awk '/Mem:/ {print $2}')" "$DOMAIN" | php artisan p:node:make >/dev/null 2>&1
    st OK "Node created ($DOMAIN)"
}

finalize_wings() {
    st WAIT "Generating wings config from panel..."
    cd /var/www/pterodactyl || return
    local NODE_COUNT NODE_ID
    NODE_COUNT=$(php artisan p:node:list 2>/dev/null | awk -F'|' 'NR>3 && $2+0 {count++} END {print count+0}')
    if [ "$NODE_COUNT" -eq 0 ]; then
        st WARN "No node found — create one first"
        return
    fi
    echo -e "  ${C}◆ Available nodes:${NC}"
    php artisan p:node:list 2>/dev/null | awk -F'|' 'NR>3 && $2+0 {
        ID=$2; NAME=$4; HOST=$6;
        gsub(/ /,"",ID); gsub(/^ +| +$/,"",NAME); gsub(/ /,"",HOST);
        split(HOST,a,":"); PORT=a[length(a)];
        printf "     %s) %s | %s | Port:%s\n", ID, NAME, HOST, PORT
    }'
    read -rp "  Select Node ID: " NODE_ID
    [ -z "$NODE_ID" ] && { st ERR "Invalid Node"; return; }
    mkdir -p /etc/pterodactyl
    php artisan p:node:configuration "$NODE_ID" > /etc/pterodactyl/config.yml || { st ERR "Config failed"; return; }
    pkill wings 2>/dev/null || true
    systemctl restart wings 2>/dev/null || true
    st OK "Node $NODE_ID connected & wings restarted"
}

auto_setup() {
    while true; do
        show_header
        echo -e "  ${C}◆ AUTO-SETUP PROTOCOLS${NC}"
        echo -e "     ${GR}[1]${NC} Configure Node         ${DG}•${NC} Wizard (UUID/Token)"
        echo -e "     ${GR}[2]${NC} Manual Paste           ${DG}•${NC} Deploy Command"
        echo -e "     ${R}[0]${NC} Back"
        echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
        echo -ne "  ${C}➜${NC} ${W}Setup Action${NC} ${DG}(0-2):${NC} "
        read -r s_choice
        case $s_choice in
            1)
                bash "$DIR/config.sh"
                pause
                ;;
            2)
                echo -e "  ${R}!! This will delete /etc/pterodactyl/config.yml !!${NC}"
                rm -f /etc/pterodactyl/config.yml
                read -rp "  Paste Auto-Deploy command (starts with 'sudo wings...'): " CMD
                if [ -z "$CMD" ]; then
                    st ERR "No command entered"
                else
                    st WAIT "Executing deploy command..."
                    eval "$CMD"
                    systemctl restart wings 2>/dev/null
                    bash "$DIR/config.sh"
                fi
                pause
                ;;
            0) break ;;
            *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
        esac
    done
}

node_menu() {
    while true; do
        show_header
        echo -e "  ${C}◆ NODE SETUP PROTOCOLS${NC}"
        echo -e "     ${GR}[1]${NC} Public Domain          ${DG}•${NC} Auto SSL"
        echo -e "     ${GR}[2]${NC} Local IP               ${DG}•${NC} Manual"
        echo -e "     ${GR}[3]${NC} Finalize               ${DG}•${NC} Start Wings + Config"
        echo -e "     ${R}[0]${NC} Back"
        echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
        echo -ne "  ${C}➜${NC} ${W}Setup Action${NC} ${DG}(0-3):${NC} "
        read -r s_choice
        case $s_choice in
            1) create_node_ssl; pause ;;
            2) create_node_local; pause ;;
            3) finalize_wings; pause ;;
            0) break ;;
            *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
        esac
    done
}

while true; do
    show_header
    echo -e "  ${C}◆ SERVICE MANAGEMENT${NC}"
    echo -e "     ${GR}[1]${NC} Start              ${GR}[4]${NC} Status"
    echo -e "     ${GR}[2]${NC} Restart            ${GR}[5]${NC} Live Logs"
    echo -e "     ${GR}[3]${NC} Stop               ${GR}[6]${NC} Debug Mode"
    echo -e "  ${C}◆ ADVANCED${NC}"
    echo -e "     ${G}[A]${NC} Auto-Setup / Nodes"
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Command${NC} ${DG}(0-6/A):${NC} "
    read -r choice
    case $choice in
        1) sudo systemctl start "$SERVICE"; st OK "Started"; sleep 1 ;;
        2) sudo systemctl restart "$SERVICE"; st OK "Restarted"; sleep 1 ;;
        3) sudo systemctl stop "$SERVICE"; st OK "Stopped"; sleep 1 ;;
        4)
            echo -e "  ${W}--- systemctl status ---${NC}"
            systemctl status "$SERVICE" --no-pager 2>/dev/null || true
            pause
            ;;
        5)
            echo -e "  ${Y}--- Live logs (Ctrl+C to exit) ---${NC}"
            journalctl -u "$SERVICE" -f 2>/dev/null || st WARN "No logs"
            ;;
        6)
            st WARN "Debug mode: stopping service, running wings foreground"
            sudo systemctl stop "$SERVICE" 2>/dev/null
            sudo wings
            pause
            ;;
        [Aa]) node_menu ;;
        [Ss])
            while true; do
                show_header
                echo -e "  ${C}◆ AUTO-SETUP${NC}"
                echo -e "     ${GR}[1]${NC} Configure Wizard"
                echo -e "     ${R}[0]${NC} Back"
                echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
                echo -ne "  ${C}➜${NC} ${W}Choice${NC} ${DG}(0-1):${NC} "
                read -r sc
                case $sc in
                    1) bash "$DIR/config.sh"; pause ;;
                    0) break ;;
                    *) echo -e "  ${R}✗ Invalid${NC}"; sleep 0.6 ;;
                esac
            done
            ;;
        0)
            echo -e "  ${DG}Goodbye from HAPPY NODE.${NC}"
            exit 0
            ;;
        *) echo -e "  ${R}✗ Invalid selection${NC}"; sleep 0.8 ;;
    esac
done
