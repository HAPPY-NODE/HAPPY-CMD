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
LOCAL_EXT="$DIR/Extension"
URL_EXT="$HN_BASE_URL/themes/Extension"
PTERO_DIR="/var/www/pterodactyl"

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

# Catalog: short labels (file stems under test/Extension/)
EXTS=(
  "Admin Audit Logs|adminauditlogs"
  "Auto Backups|autobackups"
  "Blue Announcements|blueannoucements"
  "Config Editor|configeditor"
  "Console Logs|consolelogs"
  "Custom CSS|customcss"
  "Custom Server Sort|customserversort"
  "DB Import/Export|databaseimportexport"
  "Egg Changer|eggchanger"
  "Hux Register|huxregister"
  "Laravel Logs|laravellogs"
  "Loader|loader"
  "Lyrdy Announce|lyrdyannounce"
  "MC Logs|mclogs"
  "MCP|mcp"
  "MC Player|mcplayer"
  "MC Plugins|mcplugins"
  "MC Tools|mctools"
  "MC Mod Manager|minecraftmodmanager"
  "MC Plugin Manager|minecraftpluginmanager"
  "MC Player Manager|minecraftplayermanager"
  "Modrinth Browser|modrinthbrowser"
  "Monaco Editor|monacoeditor"
  "MOTD Maker|motdmaker"
  "MySQL Auto Backup|mysqlautobackup"
  "Node Info|node"
  "No Pagination|nopagination"
  "Panel Address Override|paneladdressoverride"
  "Player Listing|playerlisting"
  "PStats|pstatistics"
  "CPU Burst|pterodactylcpuburst"
  "Panel Ban|pterodactylpanelban"
  "RAM Burst|pterodactylramburst"
  "Ptero Monaco|pteromonaco"
  "Pull Files|pullfiles"
  "Redirect|redirect"
  "Resource Alerts|resourcealerts"
  "Resource Manager|resourcemanager"
  "Saga Auto Suspension|sagaautosuspension"
  "Saga MC Modpack|sagaminecraftmodpackinstaller"
  "Server Backgrounds|serverbackgrounds"
  "Server Icon Importer|servericonimporter"
  "Server ID|serverid"
  "Server Importer|serverimporter"
  "Server Props|serverpropsmanager"
  "Server Splitter|serversplitter"
  "Show Node IDs|shownodeids"
  "Sidebar|sidebar"
  "Simple Favicon|simplefavicons"
  "Simple Footer|simplefooters"
  "Snowflakes|snowflakes"
  "Social Login|sociallogin"
  "Startup Changer|startupchanger"
  "Stats|stats"
  "Stellar|stellar"
  "Subdomain Manager|subdomainmanager"
  "Subdomains|subdomains"
  "Tawk.to|tawkto"
  "Translations|translations"
  "Trash Bin|trashbin"
  "URL Downloader|urldownloader"
  "Vanilla Tweaks|vanillatweaks"
  "Version Changer|versionchanger"
  "VM Info|vminfo"
  "Votifier Tester|votifiertester"
  "Activity Purges|activitypurges"
  "Blue Server Props|blueserverproperties"
  "DB Edit|dbedit"
  "Extension Manager|extensionmanager"
  "Left 4 Utils|left4utils"
  "Shooting Stars|shootingStars"
)

is_ext_installed() {
    local slug="$1"
    [ -d "$PTERO_DIR/storage/extensions/$slug" ] || [ -d "$PTERO_DIR/extensions/$slug" ]
}

show_header() {
    clear
    local count=${#EXTS[@]}
    local active=0
    if [ -d "$PTERO_DIR/extensions" ]; then
        active=$(ls "$PTERO_DIR/extensions" 2>/dev/null | wc -l)
    fi
    echo -e "  ${B}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "  ${B}║${NC}   ${W}E X T E N S I O N S${NC}                           ${B}║${NC}"
    echo -e "  ${B}║${NC}   ${DG}HAPPY NODE • ${count} blueprints available${NC}          ${B}║${NC}"
    echo -e "  ${B}╚══════════════════════════════════════════════════╝${NC}"
    echo -e "  ${DG}Installed:${NC} ${G}${active}${NC}  ${DG}│${NC}  ${DG}Blueprint:${NC} $(command -v blueprint >/dev/null 2>&1 && echo -e "${G}ONLINE${NC}" || echo -e "${R}OFFLINE${NC}")"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

show_list() {
    show_header
    echo ""
    local i num label slug status
    for i in "${!EXTS[@]}"; do
        num=$((i+1))
        IFS='|' read -r label slug <<< "${EXTS[$i]}"
        if is_ext_installed "$slug"; then
            status="${G}●${NC}"
        else
            status="${DG}○${NC}"
        fi
        printf "     ${status} ${G}%3d${NC}  %s\n" "$num" "$label"
    done
    echo ""
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Pick Extension${NC} ${DG}(0-${#EXTS[@]}):${NC} "
}

install_ext() {
    local slug="$1" label="$2"
    if [ ! -d "$PTERO_DIR" ]; then
        st ERR "Pterodactyl not found"; pause; return 1
    fi
    ensure_sys_deps
    ensure_blueprint "$PTERO_DIR" || { pause; return 1; }
    if is_ext_installed "$slug"; then
        st INFO "$label already installed"
        read -rp "  Reinstall? (y/N): " cf
        [[ "$cf" =~ ^[Yy]$ ]] || { st INFO "Skipped"; pause; return; }
    fi
    st INFO "Installing $label..."
    cd "$PTERO_DIR" || return 1
    pkill -9 -f "blueprint" 2>/dev/null || true
    rm -f "$PTERO_DIR/.blueprint/lock" "$PTERO_DIR/.blueprint.lock" 2>/dev/null
    blueprint -unlock 2>/dev/null || true
    local URL="$URL_EXT/${slug}.blueprint"
    local TMPF="/tmp/hn_ext_${slug}.blueprint"
    if [ -f "$LOCAL_EXT/${slug}.blueprint" ]; then
        st OK "Local file: ${slug}.blueprint"
        cp "$LOCAL_EXT/${slug}.blueprint" "$TMPF"
    else
        if ! run_dl "${slug}.blueprint" "$URL" "$TMPF"; then
            rm -f "$TMPF"; st ERR "Download failed"; pause; return 1
        fi
    fi
    if head -c 15 "$TMPF" 2>/dev/null | grep -qi "<!DOCTYPE\|<html"; then
        rm -f "$TMPF"; st ERR "Got HTML, not a blueprint"; pause; return 1
    fi
    st WAIT "Running blueprint -i..."
    run_live "blueprint" blueprint -i "$TMPF"
    local rc=$?
    rm -f "$TMPF"
    if [ $rc -ne 0 ]; then
        st ERR "Install failed (exit $rc)"; pause; return 1
    fi
    run_live "artisan-clear" php artisan optimize:clear
    sudo chown -R www-data:www-data "$PTERO_DIR/storage" "$PTERO_DIR/bootstrap/cache" 2>/dev/null
    st OK "$label installed"
    pause
}

uninstall_ext() {
    local slug="$1" label="$2"
    if ! is_ext_installed "$slug"; then
        st INFO "$label not installed"; pause; return
    fi
    st WARN "Uninstall $label?"
    read -rp "  Confirm? (y/N): " cf
    if [[ "$cf" =~ ^[Yy]$ ]]; then
        cd "$PTERO_DIR" 2>/dev/null || { st ERR "No panel"; pause; return; }
        yes | blueprint -r "$slug" 2>/dev/null
        rm -rf "$PTERO_DIR/storage/extensions/$slug" 2>/dev/null
        rm -rf "$PTERO_DIR/extensions/$slug" 2>/dev/null
        php artisan optimize:clear 2>/dev/null
        st OK "$label uninstalled"
    else
        st INFO "Cancelled"
    fi
    pause
}

if [ "$EUID" -ne 0 ]; then
    st ERR "Run as root"
    sleep 1
    exit 1
fi

while true; do
    show_list
    read -r opt || exit 0
    [ "$opt" = "0" ] && { clear; exit 0; }
    if ! [[ "$opt" =~ ^[0-9]+$ ]] || [ "$opt" -lt 1 ] || [ "$opt" -gt "${#EXTS[@]}" ]; then
        echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.7; continue
    fi
    index=$((opt - 1))
    IFS='|' read -r label slug <<< "${EXTS[$index]}"
    clear
    show_header
    echo -e "  ${W}Selected:${NC} ${C}${label}${NC}"
    if is_ext_installed "$slug"; then
        echo -e "  ${W}Status:${NC}   ${G}INSTALLED${NC}"
    else
        echo -e "  ${W}Status:${NC}   ${DG}NOT INSTALLED${NC}"
    fi
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -e "     ${GR}[1]${NC} Install"
    echo -e "     ${GR}[2]${NC} Uninstall"
    echo -e "     ${FR}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Action${NC} ${DG}(0-2):${NC} "
    read -r action || exit 0
    case $action in
        1) install_ext "$slug" "$label" ;;
        2) uninstall_ext "$slug" "$label" ;;
        0) continue ;;
        *) echo -e "  ${R}✗ Invalid${NC}"; sleep 0.6 ;;
    esac
done
