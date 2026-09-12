#!/bin/bash

# ==================================================
#  TERMINAL SHARING HUB v4.2 | HAPPY-NODE
# ==================================================

# --- COLORS & STYLES ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
GRAY='\033[1;90m'
NC='\033[0m'

# --- DETECT RUNNER ---
[ "$(id -u)" -eq 0 ] && SUDO="" || SUDO="sudo"

# --- ARCH DETECTION ---
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) SYS_ARCH="amd64" ;;
    aarch64|arm64) SYS_ARCH="arm64" ;;
    *) SYS_ARCH="amd64" ;;
esac

# --- UTILS ---
has() { command -v "$1" >/dev/null 2>&1; }

get_status() {
    if has "$1"; then
        echo -e "${GREEN}[ INSTALLED ]${NC}"
    else
        echo -e "${GRAY}[  MISSING  ]${NC}"
    fi
}

msg_info() { echo -e "  ${BLUE}➜${NC} $1"; }
msg_ok()   { echo -e "  ${GREEN}✔${NC} $1"; }
msg_err()  { echo -e "  ${RED}✖${NC} $1"; }

# --- CLEANUP HELPER ---
cleanup_tmp() {
    rm -f /tmp/upterm.tar.gz /tmp/upterm 2>/dev/null
    rm -f /tmp/ttyd /tmp/gotty*.tar.gz /tmp/gotty 2>/dev/null
    rm -f /tmp/cloudflared-linux-* 2>/dev/null
}

# --- HEADER UI ---
draw_header() {
    clear
    local host=$(hostname)
    local ip=$(hostname -I | awk '{print $1}')
    
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}║${NC}       ${WHITE}TERMINAL SHARING HUB${NC} ${GRAY}::${NC} ${PURPLE}REMOTE COLLABORATION SUITE${NC}           ${CYAN}║${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}║${NC} ${GRAY}SYSTEM:${NC} ${WHITE}$host${NC}  ${GRAY}IP:${NC} ${WHITE}$ip${NC}   ${GRAY}VER:${NC} ${WHITE}4.2 (Stable)${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# --- INSTALL / UNINSTALL LOGIC ---
manage_tool() {
    TOOL=$1
    echo -e "${GRAY}  ──────────────────────────────────────────${NC}"
    
    if has "$TOOL"; then
        echo -e "${RED}  Detected '$TOOL' is installed.${NC}"
        read -p "  Uninstall it? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            msg_info "Removing $TOOL..."
            
            case $TOOL in
                sshx)  
                    rm -rf "$HOME/.sshx"
                    rm -f "$(which sshx)" 2>/dev/null
                    ;;
                tmate) 
                    if has apt; then $SUDO apt remove -y tmate -qq
                    elif has dnf; then $SUDO dnf remove -y tmate
                    elif has yum; then $SUDO yum remove -y tmate
                    elif has pacman; then $SUDO pacman -Rns --noconfirm tmate
                    fi 
                    ;;
                upterm) rm -f /usr/local/bin/upterm /usr/bin/upterm ;;
                ttyd)   rm -f /usr/local/bin/ttyd ;;
                gotty)  rm -f /usr/local/bin/gotty ;;
                cloudflared) rm -f /usr/local/bin/cloudflared ;;
            esac
            
            if ! has "$TOOL"; then
                msg_ok "Uninstallation Complete."
            else
                msg_err "Failed to remove. Try running as root."
            fi
        else
            msg_info "Cancelled."
        fi
    else
        echo -e "${GREEN}  Detected '$TOOL' is missing.${NC}"
        read -p "  Install it now? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            msg_info "Installing $TOOL..."
            cleanup_tmp
            
            case $TOOL in
                sshx)
                    curl -sSf https://sshx.io/get | sh -s run
                    ;;
                tmate) 
                    if has apt; then $SUDO apt update -qq && $SUDO apt install -y tmate -qq
                    elif has yum; then $SUDO yum install -y tmate
                    elif has pacman; then $SUDO pacman -S --noconfirm tmate
                    fi 
                    ;;
                upterm)
                    curl -fsSL "https://github.com/owenthereal/upterm/releases/latest/download/upterm_linux_${SYS_ARCH}.tar.gz" -o /tmp/upterm.tar.gz
                    tar -xzf /tmp/upterm.tar.gz -C /tmp/
                    chmod +x /tmp/upterm
                    mv /tmp/upterm /usr/local/bin/upterm
                    cleanup_tmp
                    ;;
                ttyd) 
                    curl -fsSL "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${SYS_ARCH}" -o /usr/local/bin/ttyd
                    chmod +x /usr/local/bin/ttyd
                    ;;
                gotty)
                    curl -fsSL "https://github.com/yudai/gotty/releases/latest/download/gotty_linux_${SYS_ARCH}.tar.gz" -o /tmp/gotty.tar.gz
                    tar -xzf /tmp/gotty.tar.gz -C /tmp/
                    chmod +x /tmp/gotty
                    mv /tmp/gotty /usr/local/bin/gotty
                    cleanup_tmp
                    ;;
                cloudflared)
                    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${SYS_ARCH}" -o /usr/local/bin/cloudflared
                    chmod +x /usr/local/bin/cloudflared
                    ;;
            esac
            
            if has "$TOOL"; then
                msg_ok "Installation Complete."
            else
                msg_err "Installation failed."
            fi
        else
            msg_info "Cancelled."
        fi
    fi
    read -p "  Press Enter..."
}

package_manager_menu() {
    while true; do
        draw_header
        echo -e "  ${WHITE}PACKAGE MANAGER (INSTALL / UNINSTALL):${NC}"
        echo -e "  ${GRAY}Select a tool to toggle its installation state.${NC}"
        echo ""
        echo -e "  ${CYAN}[1]${NC} $(get_status sshx) sshx"
        echo -e "  ${CYAN}[2]${NC} $(get_status tmate) tmate"
        echo -e "  ${CYAN}[3]${NC} $(get_status upterm) upterm"
        echo -e "  ${CYAN}[4]${NC} $(get_status ttyd) ttyd"
        echo -e "  ${CYAN}[5]${NC} $(get_status gotty) gotty"
        echo -e "  ${CYAN}[6]${NC} $(get_status cloudflared) cloudflared"
        echo ""
        echo -e "  ${RED}[0] Back to Main Menu${NC}"
        echo ""
        echo -ne "${PURPLE}  root@manager:~# ${NC}"
        read pkg_opt
        
        case $pkg_opt in
            1) manage_tool "sshx" ;;
            2) manage_tool "tmate" ;;
            3) manage_tool "upterm" ;;
            4) manage_tool "ttyd" ;;
            5) manage_tool "gotty" ;;
            6) manage_tool "cloudflared" ;;
            0) return ;;
            *) msg_err "Invalid Option"; sleep 1 ;;
        esac
    done
}

# --- RUN TOOLS LOGIC ---
sshx_run() { has sshx || manage_tool "sshx"; sshx; }
tmate_run() { has tmate || manage_tool "tmate"; tmate; }
upterm_run() { has upterm || manage_tool "upterm"; upterm host; }
ttyd_run() { 
    has ttyd || manage_tool "ttyd"
    echo -ne "${PURPLE}  ➤ Select Port (Default 8080): ${NC}"
    read P
    P=${P:-8080}
    echo -e "${GREEN}  ▶ Web Terminal Active: http://$(hostname -I | awk '{print $1}'):$P${NC}"
    ttyd -p "$P" bash
}
gotty_run() { has gotty || manage_tool "gotty"; gotty -w bash; }
cloudflared_run() { 
    has cloudflared || manage_tool "cloudflared"
    echo -e "${GREEN}  ▶ Starting Quick Tunnel...${NC}"
    cloudflared tunnel --url ssh://localhost:22
}
serveo_run() {
    echo -ne "${PURPLE}  ➤ Custom Subdomain (Enter for random): ${NC}"
    read SUB
    if [ -z "$SUB" ]; then ssh -R 80:localhost:22 serveo.net
    else ssh -R "$SUB":80:localhost:22 serveo.net; fi
}
localhost_run() { ssh -R 80:localhost:22 nokey@localhost.run; }

# --- PRE-REQ CHECK ---
base_install() {
    if ! has curl || ! has wget; then
        echo -e "${YELLOW}  [SYSTEM] Installing base dependencies...${NC}"
        if has apt; then
            $SUDO apt update -y -qq >/dev/null
            $SUDO apt install -y curl wget screen tmux -qq >/dev/null
        elif has yum; then
            $SUDO yum install -y curl wget screen tmux -q
        fi
    fi
}

# --- MAIN ---
base_install

while true; do
    draw_header
    
    echo -e "  ${WHITE}COLLABORATIVE SHELLS:${NC}"
    echo -e "  ${GREEN}[1]${NC} $(get_status sshx) sshx      ${GRAY}:: (Web-based, Multiplayer)${NC}"
    echo -e "  ${GREEN}[2]${NC} $(get_status tmate) tmate     ${GRAY}:: (Tmux Session Sharing)${NC}"
    echo -e "  ${GREEN}[3]${NC} $(get_status upterm) upterm    ${GRAY}:: (Secure SSH Sharing)${NC}"
    echo ""
    echo -e "  ${WHITE}WEB TERMINALS:${NC}"
    echo -e "  ${BLUE}[4]${NC} $(get_status ttyd) ttyd      ${GRAY}:: (C++ Backend)${NC}"
    echo -e "  ${BLUE}[5]${NC} $(get_status gotty) gotty     ${GRAY}:: (Go Backend)${NC}"
    echo ""
    echo -e "  ${WHITE}TUNNELS & UTILS:${NC}"
    echo -e "  ${PURPLE}[6]${NC} Serveo    ${GRAY}:: (Clientless Tunnel)${NC}"
    echo -e "  ${PURPLE}[7]${NC} Localhost ${GRAY}:: (Clientless Tunnel)${NC}"
    echo -e "  ${PURPLE}[8]${NC} $(get_status cloudflared) Cloudflare${GRAY}:: (Zero Trust Tunnel)${NC}"
    echo ""
    echo -e "  ${YELLOW}[9] PACKAGE MANAGER (Install/Uninstall)${NC}"
    echo -e "  ${GRAY}[0] Exit Hub${NC}"
    echo ""
    echo -ne "${CYAN}  root@hub:~# ${NC}"
    read option
    
    case $option in
        1) sshx_run ;;
        2) tmate_run ;;
        3) upterm_run ;;
        4) ttyd_run ;;
        5) gotty_run ;;
        6) serveo_run ;;
        7) localhost_run ;;
        8) cloudflared_run ;;
        9) package_manager_menu ;;
        0) clear; exit 0 ;;
        *) echo -e "  ${RED}Invalid Option${NC}"; sleep 1 ;;
    esac
done
