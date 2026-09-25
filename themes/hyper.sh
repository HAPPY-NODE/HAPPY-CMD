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

PANEL_DIR="/var/www/pterodactyl"
HYPER_URL="https://r2.rolexdev.tech/hyperv1/installer.sh"

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

hyper_installed() { [ -d "$PANEL_DIR/resources/views/vendor/hyper" ]; }

get_hyper_version() {
    if [ -f "$PANEL_DIR/resources/views/vendor/hyper/hyper.blade.php" ]; then
        grep -oP 'Hyper V[0-9.]+' "$PANEL_DIR/resources/views/vendor/hyper/hyper.blade.php" 2>/dev/null | head -1 || echo "Unknown"
    else
        echo "Not installed"
    fi
}

panel_clear() {
    cd "$PANEL_DIR" 2>/dev/null || return
    php artisan view:clear 2>/dev/null
    php artisan config:clear 2>/dev/null
    php artisan cache:clear 2>/dev/null
    php artisan optimize:clear 2>/dev/null
    chown -R www-data:www-data "$PANEL_DIR"/* 2>/dev/null
    php artisan queue:restart 2>/dev/null
}

show_header() {
    clear
    local st_line hver=""
    if hyper_installed; then
        st_line="${G}● INSTALLED${NC}"
        hver="$(get_hyper_version)"
    else
        st_line="${R}● NOT INSTALLED${NC}"
    fi
    echo -e "  ${B}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "  ${B}║${NC}   ${W}H Y P E R   V 1${NC}                               ${B}║${NC}"
    echo -e "  ${B}║${NC}   ${DG}HAPPY NODE • Admin Revamp${NC}                     ${B}║${NC}"
    echo -e "  ${B}╚══════════════════════════════════════════════════╝${NC}"
    echo -e "  ${DG}Status:${NC} ${st_line}  ${DG}│${NC}  ${DG}Version:${NC} ${W}${hver:-—}${NC}"
    echo -e "  ${DG}Source:${NC} ${C}r2.rolexdev.tech/hyperv1${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

fetch_installer() {
    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        st WAIT "Installing wget..."
        run_live "wget" env DEBIAN_FRONTEND=noninteractive apt-get install -y wget || \
            run_live "wget-yum" yum install -y wget || true
    fi
    if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
        run_dl "Hyper installer.sh" "$HYPER_URL" /tmp/hyper-installer.sh
    else
        st ERR "No curl/wget available"
        return 1
    fi
    [ -f /tmp/hyper-installer.sh ] && [ -s /tmp/hyper-installer.sh ]
}

do_install() {
    st WAIT "Installing Hyper V1..."
    if fetch_installer; then
        chmod +x /tmp/hyper-installer.sh
        run_live "hyper-install" bash /tmp/hyper-installer.sh || st WARN "Installer returned non-zero"
        rm -f /tmp/hyper-installer.sh
        panel_clear
        st OK "Hyper V1 installed"
    else
        st ERR "Download failed — check internet"
    fi
    pause
}

do_info() {
    echo ""
    echo -e "  ${C}────────────────────────────────────────${NC}"
    if hyper_installed; then
        echo -e "  ${W}Status:${NC}    ${G}Installed${NC}"
        echo -e "  ${W}Version:${NC}   $(get_hyper_version)"
        echo -e "  ${W}Panel:${NC}     $PANEL_DIR"
        local hv hc
        hv=$(find "$PANEL_DIR/resources/views/vendor/hyper" -name "*.blade.php" 2>/dev/null | wc -l)
        hc=$(find "$PANEL_DIR/app/Http/Controllers/Admin/Hyper" -name "*.php" 2>/dev/null | wc -l)
        echo -e "  ${W}Views:${NC}     $hv blade files"
        echo -e "  ${W}Controllers:${NC} $hc php files"
    else
        echo -e "  ${W}Status:${NC}    ${R}Not Installed${NC}"
    fi
    echo -e "  ${C}────────────────────────────────────────${NC}"
    pause
}

do_uninstall() {
    st WARN "Uninstalling Hyper V1..."
    read -rp "  Confirm? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "$PANEL_DIR/resources/views/vendor/hyper" 2>/dev/null
        rm -rf "$PANEL_DIR/app/Http/Controllers/Admin/Hyper" 2>/dev/null
        rm -f "$PANEL_DIR/app/Http/Controllers/Admin/HyperController.php" 2>/dev/null
        rm -f "$PANEL_DIR/public/hyper" 2>/dev/null
        rm -rf "$PANEL_DIR/public/vendor/hyper" 2>/dev/null
        panel_clear
        st OK "Hyper V1 uninstalled"
    else
        st INFO "Cancelled"
    fi
    pause
}

while true; do
    show_header
    if ! hyper_installed; then
        echo -e "     ${GR}[1]${NC} Install            ${DG}•${NC} Download + run"
    else
        echo -e "     ${GR}[1]${NC} Reinstall / Update  ${DG}•${NC} Fresh install"
        echo -e "     ${GR}[2]${NC} Info               ${DG}•${NC} Version details"
        echo -e "     ${GR}[3]${NC} Uninstall          ${DG}•${NC} Remove Hyper"
    fi
    echo ""
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-3):${NC} "
    read -r hy
    case $hy in
        1) do_install ;;
        2) do_info ;;
        3) do_uninstall ;;
        0) clear; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.7 ;;
    esac
done
