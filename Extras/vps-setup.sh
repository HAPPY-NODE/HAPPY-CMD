#!/bin/bash

# ============================================================
#   HAPPY-NODE  |  Universal VPS Setup Script
#   Supports: Debian / Ubuntu (any VPS)
# ============================================================

set -o pipefail

# ---------- Colors ----------
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'

# ---------- Helpers ----------
info()  { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()    { echo -e "${GREEN}[ OK ]${RESET}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
err()   { echo -e "${RED}[FAIL]${RESET}  $*"; }
pause() { echo ""; read -rp "$(echo -e "${DIM}Press Enter to return to menu...${RESET}")" _; }

line() { echo -e "${BLUE}------------------------------------------------------------${RESET}"; }

run() {
    "$@" || warn "Command failed: $*"
}

# ---------- Root check ----------
if [ "$(id -u)" -ne 0 ]; then
    warn "Not running as root. Some operations may fail."
fi

# ---------- Distro / package manager detection ----------
detect_pm() {
    if command -v apt-get >/dev/null 2>&1; then
        PM="apt"
        PM_INSTALL="apt-get install -y"
        PM_UPDATE="apt-get update -y"
        PM_UPGRADE="apt-get upgrade -y"
        PM_REMOVE="apt-get remove -y"
        PM_PURGE="apt-get purge -y"
    elif command -v apk >/dev/null 2>&1; then
        PM="apk"
        PM_INSTALL="apk add"
        PM_UPDATE="apk update"
        PM_UPGRADE="apk upgrade"
        PM_REMOVE="apk del"
        PM_PURGE="apk del"
    elif command -v dnf >/dev/null 2>&1; then
        PM="dnf"
        PM_INSTALL="dnf install -y"
        PM_UPDATE="dnf check-update"
        PM_UPGRADE="dnf upgrade -y"
        PM_REMOVE="dnf remove -y"
        PM_PURGE="dnf remove -y"
    elif command -v yum >/dev/null 2>&1; then
        PM="yum"
        PM_INSTALL="yum install -y"
        PM_UPDATE="yum check-update"
        PM_UPGRADE="yum update -y"
        PM_REMOVE="yum remove -y"
        PM_PURGE="yum remove -y"
    else
        PM="unknown"
    fi
}

detect_os() {
    OS_NAME="Linux"
    OS_VER=""
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="${NAME:-Linux}"
        OS_VER="${VERSION_ID:-}"
    fi
}

detect_pm
detect_os

# ---------- Banner ----------
banner() {
    clear
    echo -e "${MAGENTA}${BOLD}"
    cat <<'EOF'
  _   _    _    ____  ____  __   __   _   _  ___  ____  _____
 | | | |  / \  |  _ \|  _ \ \ \ / /  | \ | |/ _ \|  _ \| ____|
 | |_| | / _ \ | |_) | |_) | \ V /   |  \| | | | | | | |  _|
 |  _  |/ ___ \|  __/|  __/   | |    | |\  | |_| | |_| | |___
 |_| |_/_/   \_\_|   |_|      |_|    |_| \_|\___/|____/|_____|
EOF
    echo -e "${RESET}"
    echo -e "${CYAN}${BOLD}            Universal VPS Setup  |  HAPPY-NODE${RESET}"
    line
    echo -e "  ${WHITE}System${RESET}   : ${GREEN}${OS_NAME} ${OS_VER}${RESET}"
    echo -e "  ${WHITE}Arch${RESET}     : ${GREEN}$(uname -m)${RESET}"
    echo -e "  ${WHITE}Packages${RESET} : ${GREEN}${PM}${RESET}"
    line
}

# ---------- Options ----------

opt_lxde_xrdp() {
    clear
    info "Installing LXDE Desktop + XRDP Remote Desktop..."
    if [ "$PM" != "apt" ]; then
        warn "LXDE/XRDP option currently supports Debian/Ubuntu only."
        pause; return
    fi
    run $PM_UPDATE
    run $PM_UPGRADE
    export SUDO_FORCE_REMOVE=yes
    run $PM_REMOVE sudo
    run $PM_INSTALL lxde xrdp
    if [ -f /etc/xrdp/startwm.sh ] && ! grep -q "lxsession -s LXDE" /etc/xrdp/startwm.sh; then
        echo "lxsession -s LXDE -e LXDE" >> /etc/xrdp/startwm.sh
    fi
    echo ""
    read -rp "$(echo -e "${YELLOW}Select RDP Port (default 3389): ${RESET}")" selectedPort
    selectedPort="${selectedPort:-3389}"
    if [ -f /etc/xrdp/xrdp.ini ]; then
        sed -i "s/^port=.*/port=$selectedPort/g" /etc/xrdp/xrdp.ini
    fi
    run service xrdp restart
    ok "RDP ready on port ${BOLD}${selectedPort}${RESET}"
    pause
}

opt_pufferpanel() {
    clear
    info "Installing PufferPanel..."
    if [ "$PM" != "apt" ]; then
        warn "PufferPanel option currently supports Debian/Ubuntu only."
        pause; return
    fi
    run $PM_UPDATE
    run $PM_UPGRADE
    export SUDO_FORCE_REMOVE=yes
    run $PM_REMOVE sudo
    run $PM_INSTALL curl wget git python3
    run bash -c 'curl -fsSL https://packagecloud.io/install/repositories/pufferpanel/pufferpanel/script.deb.sh | bash'
    run $PM_UPDATE
    if [ ! -f /bin/systemctl ]; then
        run bash -c 'curl -fsSL -o /bin/systemctl https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl3.py'
        chmod 777 /bin/systemctl 2>/dev/null
    fi
    run $PM_INSTALL pufferpanel
    echo ""
    read -rp "$(echo -e "${YELLOW}Enter PufferPanel Port (default 8080): ${RESET}")" pufferPanelPort
    pufferPanelPort="${pufferPanelPort:-8080}"
    if [ -f /etc/pufferpanel/config.json ]; then
        sed -i "s/\"host\": \"0.0.0.0:[0-9]*\"/\"host\": \"0.0.0.0:$pufferPanelPort\"/g" /etc/pufferpanel/config.json
    fi
    echo ""
    read -rp "$(echo -e "${YELLOW}Admin username: ${RESET}")" adminUsername
    read -rsp "$(echo -e "${YELLOW}Admin password: ${RESET}")" adminPassword; echo ""
    read -rp "$(echo -e "${YELLOW}Admin email: ${RESET}")" adminEmail
    run pufferpanel user add --name "$adminUsername" --password "$adminPassword" --email "$adminEmail" --admin
    run systemctl restart pufferpanel
    ok "PufferPanel started on port ${BOLD}${pufferPanelPort}${RESET}"
    pause
}

opt_basic() {
    clear
    info "Installing basic packages..."
    run $PM_UPDATE
    run $PM_UPGRADE
    if [ "$PM" = "apt" ]; then
        run $PM_INSTALL git curl wget sudo lsof iputils-ping
    elif [ "$PM" = "apk" ]; then
        run $PM_INSTALL git curl wget sudo lsof iputils
    else
        run $PM_INSTALL git curl wget sudo lsof iputils
    fi
    if [ "$PM" = "apt" ] && [ ! -f /bin/systemctl ]; then
        run bash -c 'curl -fsSL -o /bin/systemctl https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl3.py'
        chmod 777 /bin/systemctl 2>/dev/null
    fi
    ok "Basic packages installed: sudo, curl, wget, git, lsof, ping"
    pause
}

opt_nodejs() {
    clear
    info "Node.js Installer"
    echo ""
    echo -e "  ${WHITE}1)${RESET} 12.x    ${WHITE}2)${RESET} 14.x    ${WHITE}3)${RESET} 16.x"
    echo -e "  ${WHITE}4)${RESET} 18.x    ${WHITE}5)${RESET} 20.x    ${WHITE}6)${RESET} 22.x"
    echo ""
    read -rp "$(echo -e "${YELLOW}Choose version (1-6): ${RESET}")" choice
    case $choice in
        1) version="12" ;;
        2) version="14" ;;
        3) version="16" ;;
        4) version="18" ;;
        5) version="20" ;;
        6) version="22" ;;
        *) err "Invalid choice."; pause; return ;;
    esac
    info "Installing Node.js ${version}.x ..."
    if [ "$PM" = "apt" ]; then
        run $PM_PURGE "node*" nodejs npm
        run $PM_UPDATE
        run $PM_INSTALL curl
        run bash -c "curl -fsSL https://deb.nodesource.com/setup_${version}.x -o /tmp/nodesource_setup.sh"
        run bash /tmp/nodesource_setup.sh
        run $PM_UPDATE
        run $PM_INSTALL nodejs
    elif [ "$PM" = "apk" ]; then
        run $PM_INSTALL nodejs npm
    else
        run bash -c "curl -fsSL https://rpm.nodesource.com/setup_${version}.x | bash -"
        run $PM_INSTALL nodejs
    fi
    if command -v node >/dev/null 2>&1; then
        ok "Node.js installed: $(node -v)"
    else
        warn "Node.js installation could not be verified."
    fi
    pause
}

# ---------- Menu ----------
menu() {
    while true; do
        banner
        echo -e "  ${WHITE}${BOLD}Available Options${RESET}"
        echo ""
        echo -e "   ${GREEN}1)${RESET} LXDE Desktop + XRDP Remote Desktop"
        echo -e "   ${GREEN}2)${RESET} PufferPanel (Game Server Panel)"
        echo -e "   ${GREEN}3)${RESET} Install Basic Packages"
        echo -e "   ${GREEN}4)${RESET} Install Node.js"
        echo ""
        echo -e "   ${RED}0)${RESET} Exit"
        line
        read -rp "$(echo -e "${YELLOW}Select an option: ${RESET}")" option

        case $option in
            1) opt_lxde_xrdp ;;
            2) opt_pufferpanel ;;
            3) opt_basic ;;
            4) opt_nodejs ;;
            0) clear; echo -e "${MAGENTA}${BOLD}Thanks for using HAPPY-NODE. Goodbye!${RESET}"; exit 0 ;;
            *) err "Invalid option selected."; sleep 1 ;;
        esac
    done
}

menu