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

PT_DIR="/var/www/pterodactyl"

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

bp_status() {
    if command -v blueprint >/dev/null 2>&1; then echo -e "${G}● ONLINE${NC}"; else echo -e "${R}● OFFLINE${NC}"; fi
}

show_header() {
    clear
    echo -e "  ${B}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "  ${B}║${NC}   ${W}B L U E P R I N T   F R A M E W O R K${NC}         ${B}║${NC}"
    echo -e "  ${B}║${NC}   ${DG}HAPPY NODE • Extension Engine${NC}                 ${B}║${NC}"
    echo -e "  ${B}╚══════════════════════════════════════════════════╝${NC}"
    echo -e "  ${DG}Status:${NC} $(bp_status)  ${DG}│${NC}  ${DG}Panel:${NC} ${W}${PT_DIR}${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

do_install() {
    st INFO "Blueprint auto-installer starting..."
    if [ "$EUID" -ne 0 ]; then st ERR "Run as root"; pause; return; fi
    if [ ! -d "$PT_DIR" ]; then st ERR "Pterodactyl not found at $PT_DIR"; pause; return; fi
    st OK "Panel directory found"

    st WAIT "Checking system dependencies..."
    ensure_sys_deps
    st OK "Dependencies ready"

    st WAIT "Configuring Node.js + Yarn..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg 2>/dev/null || true
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
    run_live "nodesource" bash -c 'curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -' || true
    run_live "nodejs" env DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs || true
    run_live "yarn" npm i -g yarn || true
    st OK "Node.js & Yarn ready"

    st WAIT "Downloading Blueprint framework..."
    cd "$PT_DIR" || return 1
    local DOWNLOAD_URL
    DOWNLOAD_URL=$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep 'browser_download_url' | grep 'release.zip' | cut -d '"' -f 4)
    if [ -z "$DOWNLOAD_URL" ]; then
        st ERR "Could not resolve release URL"
        pause; return 1
    fi
    run_dl "Blueprint release.zip" "$DOWNLOAD_URL" "$PT_DIR/release.zip" || { st ERR "Download failed"; pause; return 1; }
    run_live "unzip" unzip -o -q release.zip
    rm -f release.zip
    st OK "Files extracted"

    st WAIT "Generating configuration..."
    cat <<EOF > "$PT_DIR/.blueprintrc"
WEBUSER="www-data";
OWNERSHIP="www-data:www-data";
USERSHELL="/bin/bash";
EOF
    chmod +x "$PT_DIR/blueprint.sh" 2>/dev/null
    chown -R www-data:www-data "$PT_DIR" 2>/dev/null
    st OK "Config written"

    st WAIT "Running Blueprint installer..."
    yes | bash "$PT_DIR/blueprint.sh"
    st OK "Blueprint installation complete"
}

do_reinstall() {
    st WAIT "Re-running Blueprint installer..."
    yes | blueprint -rerun-install
    st OK "Reinstall finished"
    pause
}

do_update() {
    st WAIT "Updating Blueprint..."
    yes | blueprint -upgrade
    st OK "Update finished"
    pause
}

do_info() {
    blueprint -info 2>/dev/null || st ERR "blueprint not installed"
    pause
}

do_version() {
    blueprint -version 2>/dev/null || st ERR "blueprint not installed"
    pause
}

do_uninstall() {
    st WARN "Will remove Blueprint framework + all extensions"
    read -rp "  Confirm? (y/N): " confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        local path
        path=$(which blueprint 2>/dev/null)
        if [ -n "$path" ]; then
            systemctl stop pterodactyl-queue 2>/dev/null || true
            rm -f "$path"
            rm -rf ~/.blueprint ~/.config/blueprint "$PT_DIR/.blueprint"
            rm -rf "$PT_DIR/app/BlueprintFramework" "$PT_DIR/extensions"
            rm -rf /etc/blueprint /etc/systemd/system/blueprint* /etc/systemd/system/pteroq.service
            rm -f "$PT_DIR/blueprint.backup.tar.gz" 2>/dev/null
            command -v mysql >/dev/null 2>&1 && mysql -e "DROP TABLE IF EXISTS pterodactyl.blueprint_extensions;" 2>/dev/null || true
            systemctl daemon-reload 2>/dev/null || true
            st OK "Blueprint fully uninstalled"
        else
            st ERR "Not installed"
        fi
    else
        st INFO "Cancelled"
    fi
    pause
}

while true; do
    show_header
    if ! command -v blueprint >/dev/null 2>&1; then
        echo -e "     ${GR}[1]${NC} Install            ${DG}•${NC} One-click setup"
    else
        echo -e "     ${GR}[1]${NC} Reinstall           ${DG}•${NC} Fresh setup"
        echo -e "     ${GR}[2]${NC} Update              ${DG}•${NC} blueprint -upgrade"
        echo -e "     ${GR}[3]${NC} Info                ${DG}•${NC} Framework details"
        echo -e "     ${GR}[4]${NC} Version             ${DG}•${NC} Current version"
        echo -e "     ${GR}[5]${NC} Uninstall           ${DG}•${NC} Remove all"
    fi
    echo ""
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-5):${NC} "
    read -r bp
    case $bp in
        1)
            if ! command -v blueprint >/dev/null 2>&1; then do_install; else do_reinstall; fi ;;
        2) do_update ;;
        3) do_info ;;
        4) do_version ;;
        5) do_uninstall ;;
        0) clear; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.7 ;;
    esac
done
