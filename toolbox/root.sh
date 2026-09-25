#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
source "$ROOT/colors.sh"

CONFIG_FILE="/etc/ssh/sshd_config"
BACKUP_FILE="/etc/ssh/sshd_config.bak"

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

msg_info() { echo -e "  ${C}➜${NC} $1"; }
msg_ok()   { echo -e "  ${G}✔${NC} $1"; }
msg_warn() { echo -e "  ${Y}⚠${NC} $1"; }
msg_err()  { echo -e "  ${R}✖${NC} $1"; }

get_conf_status() {
    local param=$1 default=$2
    local val
    val=$(grep -E "^${param}" "$CONFIG_FILE" 2>/dev/null | tail -n 1 | awk '{print $2}')
    [ -z "$val" ] && val="$default"
    if [ "$val" = "yes" ]; then
        echo -e "${G}[ ON ]${NC}"
    else
        echo -e "${R}[ OFF ]${NC}"
    fi
}

get_ssh_port() {
    local port
    port=$(grep -E "^Port" "$CONFIG_FILE" 2>/dev/null | head -n 1 | awk '{print $2}')
    if [ -z "$port" ]; then echo "22 (Default)"; else echo "$port"; fi
}

show_header() {
    clear
    local hostname ip active_sessions srv_stat root_login pass_auth current_port
    hostname=$(hostname)
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ip" ] && ip="N/A"
    active_sessions=$(who 2>/dev/null | grep -c pts || echo 0)
    srv_stat="${R}STOPPED${NC}"
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        srv_stat="${G}ONLINE${NC}"
    fi
    root_login=$(get_conf_status "PermitRootLogin" "prohibit-password")
    pass_auth=$(get_conf_status "PasswordAuthentication" "no")
    current_port=$(get_ssh_port)

    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     R O O T   A C C E S S                   ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    HAPPY NODE • SSH Commander                ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${DG}Host:${NC} ${W}${hostname}${NC}  ${DG}│${NC}  ${DG}IP:${NC} ${W}${ip}${NC}  ${DG}│${NC}  ${DG}Sessions:${NC} ${Y}${active_sessions}${NC}"
    echo -e "  ${DG}Status:${NC} ${srv_stat}  ${DG}│${NC}  ${DG}Port:${NC} ${W}${current_port}${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${C}Security:${NC}  Root ${root_login}  PassAuth ${pass_auth}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

enable_access() {
    st INFO "Unlocking server access..."
    cp "$CONFIG_FILE" "$BACKUP_FILE" 2>/dev/null
    sed -i '/^PermitRootLogin/d' "$CONFIG_FILE"
    sed -i '/^PasswordAuthentication/d' "$CONFIG_FILE"
    echo "PermitRootLogin yes" >> "$CONFIG_FILE"
    echo "PasswordAuthentication yes" >> "$CONFIG_FILE"
    st OK "Config updated (Root: YES, Pass: YES)"
    st WAIT "Reloading SSH daemon..."
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
    st OK "Service restarted"
    msg_warn "Ensure a strong root password is set!"
    pause
}

secure_lockdown() {
    st WARN "LOCKDOWN MODE"
    echo -e "  This will ${R}DISABLE${NC} root login and password auth."
    read -rp "  Confirm lockdown? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        cp "$CONFIG_FILE" "$BACKUP_FILE" 2>/dev/null
        sed -i '/^PermitRootLogin/d' "$CONFIG_FILE"
        sed -i '/^PasswordAuthentication/d' "$CONFIG_FILE"
        echo "PermitRootLogin no" >> "$CONFIG_FILE"
        echo "PasswordAuthentication no" >> "$CONFIG_FILE"
        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
        st OK "Server secured (key-only access)"
    else
        st INFO "Cancelled"
    fi
    pause
}

set_root_pass() {
    st INFO "ROOT PASSWORD MANAGEMENT"
    echo ""
    echo -e "  ${GR}[1]${NC} Quick set password ${DG}(hidden input)${NC}"
    echo -e "  ${GR}[2]${NC} Use passwd command ${DG}(manual)${NC}"
    read -rp "  Choose option: " choice
    case $choice in
        1)
            read -rsp "  New root password: " pass; echo ""
            read -rsp "  Confirm password: " confirm_pass; echo ""
            if [ "$pass" != "$confirm_pass" ]; then
                msg_err "Passwords do not match"
            elif [ -z "$pass" ]; then
                msg_err "Password cannot be empty"
            else
                echo "root:$pass" | chpasswd
                if [ $? -eq 0 ]; then msg_ok "Root password updated"; else msg_err "Failed"; fi
            fi
            ;;
        2)
            passwd root
            ;;
        *) msg_err "Invalid option" ;;
    esac
    pause
}

restore_backup() {
    if [ -f "$BACKUP_FILE" ]; then
        st WAIT "Restoring backup..."
        cp "$BACKUP_FILE" "$CONFIG_FILE"
        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
        st OK "Configuration restored"
    else
        st ERR "No backup file found"
    fi
    pause
}

if [ "$EUID" -ne 0 ]; then
    st ERR "Run as root"
    sleep 1
    exit 1
fi

while true; do
    show_header
    echo -e "  ${C}◆ ACCESS CONTROLS${NC}"
    echo -e "     ${GR}[1]${NC} Enable Root & Passwords"
    echo -e "     ${GR}[2]${NC} Secure Lockdown"
    echo ""
    echo -e "  ${Y}◆ MANAGEMENT${NC}"
    echo -e "     ${GR}[3]${NC} Set Root Password"
    echo -e "     ${GR}[4]${NC} Restore Backup"
    echo ""
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-4):${NC} "
    read -r option
    case $option in
        1) enable_access ;;
        2) secure_lockdown ;;
        3) set_root_pass ;;
        4) restore_backup ;;
        0) clear; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
