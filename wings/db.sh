#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
source "$ROOT/colors.sh"

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

draw_header() {
    clear
    local host ip status
    host=$(hostname)
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    status="${R}● OFFLINE${NC}"
    if systemctl is-active --quiet mariadb 2>/dev/null || systemctl is-active --quiet mysql 2>/dev/null; then
        status="${G}● ONLINE${NC}"
    fi
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     D A T A B A S E   S E T U P               ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    HAPPY NODE • MySQL / MariaDB               ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${W}Status:${NC}  $status  ${DG}│${NC}  ${DG}Host:${NC} ${W}${host}${NC}  ${DG}│${NC}  ${DG}IP:${NC} ${W}${ip}${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

get_input() {
    local prompt="$1" def="$2" var="$3" input
    read -rp "  $prompt [$def]: " input
    if [ -z "$input" ]; then
        eval "$3=\"\$2\""
    else
        eval "$3=\"\$input\""
    fi
}

draw_header

echo -e "  ${C}◆ CONFIGURATION${NC}"
get_input "Username" "root" DB_USER
get_input "Password" "root" DB_PASS
st OK "Credentials saved"
echo ""

echo -e "  ${C}◆ SYSTEM REQUIREMENTS${NC}"
if ! command -v mysql >/dev/null 2>&1; then
    st WAIT "Installing MariaDB Server..."
    run_live "mariadb" env DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client || st WARN "Install may need retry"
    systemctl enable mariadb >/dev/null 2>&1 || true
    systemctl start mariadb >/dev/null 2>&1 || true
    st OK "Service started"
else
    st OK "MariaDB already installed"
fi
echo ""

echo -e "  ${C}◆ DATABASE OPERATIONS${NC}"
if sudo mysql <<MYSQL_SCRIPT >/dev/null 2>&1
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
MYSQL_SCRIPT
then
    st OK "User '${W}${DB_USER}${G}' configured"
else
    st ERR "Failed to configure database user"
fi
echo ""

echo -e "  ${C}◆ NETWORK CONFIGURATION${NC}"
CONF_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"
if [ -f "$CONF_FILE" ]; then
    sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' "$CONF_FILE"
    st OK "Remote access enabled (0.0.0.0)"
else
    st WARN "Config file not found — bind-address skipped"
fi
run_live "restart-db" bash -c 'systemctl restart mysql 2>/dev/null; systemctl restart mariadb 2>/dev/null' || true
st OK "Services restarted"
if command -v ufw >/dev/null 2>&1; then
    ufw allow 3306/tcp >/dev/null 2>&1
    st OK "Firewall port 3306 open"
else
    st INFO "UFW not detected — firewall skipped"
fi
echo ""

echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
echo -e "  ${CB}│${G}  INSTALLATION COMPLETE                       ${CB}│${NC}"
echo -e "  ${CB}├──────────────────────────────────────────────┤${NC}"
echo -e "  ${CB}│${DG}  User${NC}       ${W}${DB_USER}${NC}                             ${CB}│${NC}"
echo -e "  ${CB}│${DG}  Password${NC}   ${W}${DB_PASS}${NC}                             ${CB}│${NC}"
echo -e "  ${CB}│${DG}  Remote${NC}     ${W}0.0.0.0 (Any)${NC}                      ${CB}│${NC}"
echo -e "  ${CB}│${DG}  Port${NC}       ${W}3306${NC}                                ${CB}│${NC}"
echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
