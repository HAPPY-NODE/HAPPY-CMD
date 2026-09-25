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

[ "$(id -u)" -eq 0 ] && SUDO="" || SUDO="sudo"

ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) SYS_ARCH="amd64" ;;
    aarch64|arm64) SYS_ARCH="arm64" ;;
    *) SYS_ARCH="amd64" ;;
esac

has() { command -v "$1" >/dev/null 2>&1; }

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
msg_err()  { echo -e "  ${R}✖${NC} $1"; }

get_status() {
    if has "$1"; then
        echo -e "${G}[ ON ]${NC}"
    else
        echo -e "${DG}[ OFF ]${NC}"
    fi
}

cleanup_tmp() {
    rm -f /tmp/upterm.tar.gz /tmp/upterm /tmp/ttyd /tmp/gotty*.tar.gz /tmp/gotty /tmp/cloudflared-linux-* 2>/dev/null
}

show_header() {
    clear
    local host ip
    host=$(hostname)
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ip" ] && ip="N/A"
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     W E B   T E R M I N A L                  ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    HAPPY NODE • Shell Sharing Hub            ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${DG}Host:${NC} ${W}${host}${NC}  ${DG}│${NC}  ${DG}IP:${NC} ${W}${ip}${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

manage_tool() {
    TOOL=$1
    if has "$TOOL"; then
        st WARN "'$TOOL' is installed"
        read -rp "  Uninstall it? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            msg_info "Removing $TOOL..."
            case $TOOL in
                sshx) rm -rf "$HOME/.sshx"; rm -f "$(which sshx)" 2>/dev/null ;;
                tmate)
                    if has apt; then $SUDO apt remove -y tmate -qq
                    elif has dnf; then $SUDO dnf remove -y tmate
                    elif has yum; then $SUDO yum remove -y tmate
                    elif has pacman; then $SUDO pacman -Rns --noconfirm tmate
                    fi ;;
                upterm) rm -f /usr/local/bin/upterm /usr/bin/upterm ;;
                ttyd)   rm -f /usr/local/bin/ttyd ;;
                gotty)  rm -f /usr/local/bin/gotty ;;
                cloudflared) rm -f /usr/local/bin/cloudflared ;;
            esac
            if ! has "$TOOL"; then msg_ok "Uninstalled"; else msg_err "Failed — try as root"; fi
        else
            st INFO "Cancelled"
        fi
    else
        st INFO "'$TOOL' is missing"
        read -rp "  Install it now? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            msg_info "Installing $TOOL..."
            cleanup_tmp
            case $TOOL in
                sshx) curl -sSf https://sshx.io/get | sh -s run ;;
                tmate)
                    if has apt; then $SUDO apt update -qq && $SUDO apt install -y tmate -qq
                    elif has dnf; then $SUDO dnf install -y tmate
                    elif has pacman; then $SUDO pacman -S --noconfirm tmate
                    fi ;;
                upterm)
                    run_dl "upterm" "https://github.com/owenthereal/upterm/releases/latest/download/upterm_linux_${SYS_ARCH}.tar.gz" /tmp/upterm.tar.gz || true
                    tar -xzf /tmp/upterm.tar.gz -C /tmp/ 2>/dev/null
                    chmod +x /tmp/upterm 2>/dev/null
                    mv /tmp/upterm /usr/local/bin/upterm 2>/dev/null
                    cleanup_tmp ;;
                ttyd)
                    run_dl "ttyd" "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${SYS_ARCH}" /usr/local/bin/ttyd || true
                    chmod +x /usr/local/bin/ttyd 2>/dev/null ;;
                gotty)
                    run_dl "gotty" "https://github.com/yudai/gotty/releases/latest/download/gotty_linux_${SYS_ARCH}.tar.gz" /tmp/gotty.tar.gz || true
                    tar -xzf /tmp/gotty.tar.gz -C /tmp/ 2>/dev/null
                    chmod +x /tmp/gotty 2>/dev/null
                    mv /tmp/gotty /usr/local/bin/gotty 2>/dev/null
                    cleanup_tmp ;;
                cloudflared)
                    run_dl "cloudflared" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${SYS_ARCH}" /usr/local/bin/cloudflared || true
                    chmod +x /usr/local/bin/cloudflared 2>/dev/null ;;
            esac
            if has "$TOOL"; then msg_ok "Installed"; else msg_err "Install failed"; fi
        else
            st INFO "Cancelled"
        fi
    fi
    pause
}

package_manager_menu() {
    while true; do
        show_header
        echo -e "  ${C}◆ PACKAGE MANAGER${NC}"
        echo -e "     ${GR}[1]${NC} $(get_status sshx) sshx         ${DG}•${NC} Web multiplayer"
        echo -e "     ${GR}[2]${NC} $(get_status tmate) tmate        ${DG}•${NC} Tmux share"
        echo -e "     ${GR}[3]${NC} $(get_status upterm) upterm      ${DG}•${NC} SSH share"
        echo -e "     ${GR}[4]${NC} $(get_status ttyd) ttyd          ${DG}•${NC} Web terminal"
        echo -e "     ${GR}[5]${NC} $(get_status gotty) gotty         ${DG}•${NC} Web terminal"
        echo -e "     ${GR}[6]${NC} $(get_status cloudflared) cloudflared ${DG}•${NC} Quick tunnel"
        echo ""
        echo -e "     ${R}[0]${NC} Back"
        echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
        echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-6):${NC} "
        read -r pkg_opt || exit 0
        case $pkg_opt in
            1) manage_tool "sshx" ;;
            2) manage_tool "tmate" ;;
            3) manage_tool "upterm" ;;
            4) manage_tool "ttyd" ;;
            5) manage_tool "gotty" ;;
            6) manage_tool "cloudflared" ;;
            0) return ;;
            *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
        esac
    done
}

sshx_run() { has sshx || manage_tool "sshx"; has sshx && sshx; }
tmate_run() { has tmate || manage_tool "tmate"; has tmate && tmate; }
upterm_run() { has upterm || manage_tool "upterm"; has upterm && upterm host; }
ttyd_run() {
    has ttyd || manage_tool "ttyd"
    has ttyd || { pause; return; }
    read -rp "  Port (default 8080): " P
    P=${P:-8080}
    local hip
    hip=$(hostname -I 2>/dev/null | awk '{print $1}')
    st OK "Web terminal: http://${hip}:$P"
    ttyd -p "$P" bash
}
gotty_run() { has gotty || manage_tool "gotty"; has gotty && gotty -w bash; }
cloudflared_run() {
    has cloudflared || manage_tool "cloudflared"
    has cloudflared || { pause; return; }
    st INFO "Starting quick tunnel..."
    cloudflared tunnel --url ssh://localhost:22
}
serveo_run() {
    read -rp "  Custom subdomain (Enter for random): " SUB
    if [ -z "$SUB" ]; then ssh -R 80:localhost:22 serveo.net
    else ssh -R "$SUB":80:localhost:22 serveo.net; fi
}
localhost_run() { ssh -R 80:localhost:22 nokey@localhost.run; }

base_install() {
    if ! has curl || ! has wget; then
        st WAIT "Installing base dependencies..."
        if has apt; then
            $SUDO apt update -y -qq >/dev/null
            $SUDO apt install -y curl wget screen tmux -qq >/dev/null
        elif has yum; then
            $SUDO yum install -y curl wget screen tmux -q
        fi
    fi
}

base_install

while true; do
    show_header
    echo -e "  ${C}◆ COLLABORATIVE SHELLS${NC}"
    echo -e "     ${GR}[1]${NC} $(get_status sshx) sshx       ${DG}•${NC} Web multiplayer"
    echo -e "     ${GR}[2]${NC} $(get_status tmate) tmate      ${DG}•${NC} Tmux session share"
    echo -e "     ${GR}[3]${NC} $(get_status upterm) upterm    ${DG}•${NC} Secure SSH share"
    echo ""
    echo -e "  ${B}◆ WEB TERMINALS${NC}"
    echo -e "     ${GR}[4]${NC} $(get_status ttyd) ttyd       ${DG}•${NC} Browser shell"
    echo -e "     ${GR}[5]${NC} $(get_status gotty) gotty      ${DG}•${NC} Browser shell"
    echo ""
    echo -e "  ${P}◆ TUNNELS & UTILS${NC}"
    echo -e "     ${GR}[6]${NC} Serveo              ${DG}•${NC} Clientless tunnel"
    echo -e "     ${GR}[7]${NC} Localhost           ${DG}•${NC} Clientless tunnel"
    echo -e "     ${GR}[8]${NC} $(get_status cloudflared) Cloudflare   ${DG}•${NC} Zero Trust"
    echo ""
    echo -e "     ${GR}[9]${NC} Package Manager     ${DG}•${NC} Install / Uninstall"
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-9):${NC} "
    read -r option || exit 0
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
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
