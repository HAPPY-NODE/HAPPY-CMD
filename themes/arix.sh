#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
source "$ROOT/colors.sh"

HN_BASE_URL="https://raw.githubusercontent.com/HAPPY-NODE/HAPPY-CMD/main"
LOCAL_ARIX="$DIR/arix"
ARIX_URL="$HN_BASE_URL/themes/arix"
ARIX_FALLBACK="https://raw.githubusercontent.com/sdgamer8263-sketch/pterodactyl_extention1/main/sd"
PANEL_DIR="/var/www/pterodactyl"
BACKUP_DIR="/tmp/hn_backups"
TMP_DIR="$(mktemp -d)"

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

arix_status_line() {
    if [ -d "$PANEL_DIR/arix" ] || [ -f "$PANEL_DIR/app/Console/Commands/Arix.php" ]; then
        echo -e "${G}● INSTALLED${NC}"
    else
        echo -e "${R}● NOT INSTALLED${NC}"
    fi
}

show_header() {
    clear
    echo -e "  ${B}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "  ${B}║${NC}   ${W}A R I X   T H E M E${NC}                           ${B}║${NC}"
    echo -e "  ${B}║${NC}   ${DG}HAPPY NODE • Premium UI Installer${NC}              ${B}║${NC}"
    echo -e "  ${B}╚══════════════════════════════════════════════════╝${NC}"
    echo -e "  ${DG}Status:${NC} $(arix_status_line)  ${DG}│${NC}  ${DG}Panel:${NC} ${W}${PANEL_DIR}${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

choose_version() {
    echo ""
    echo -e "     ${GR}[1]${NC} ARIX v2.1.0   ${C}(Latest, most features)${NC}"
    echo -e "     ${GR}[2]${NC} ARIX v2.0.8   ${Y}(Legacy, stable)${NC}"
    echo -e "     ${GR}[3]${NC} ARIX v1.3.1   ${P}(Classic, lightweight)${NC}"
    echo -e "     ${GR}[4]${NC} ARIX AV1      ${M}(Alternative build)${NC}"
    echo -e "     ${FR}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    read -rp "  Select version: " ver_choice
    case "$ver_choice" in
        1) ARIX_VER="v2.1.0"; ARIX_DIR="v210" ;;
        2) ARIX_VER="v2.0.8"; ARIX_DIR="v208" ;;
        3) ARIX_VER="v1.3.1"; ARIX_DIR="v131" ;;
        4) ARIX_VER="av1";    ARIX_DIR="av1" ;;
        0) return 1 ;;
        *) echo -e "  ${R}✗ Invalid${NC}"; sleep 0.7; return 1 ;;
    esac
    st OK "Selected: ARIX $ARIX_VER"
    return 0
}

validate_panel() {
    if [ ! -d "$PANEL_DIR" ]; then st ERR "Pterodactyl not found at $PANEL_DIR"; return 1; fi
    if [ ! -f "$PANEL_DIR/artisan" ]; then st ERR "Not a valid Pterodactyl installation"; return 1; fi
    st OK "Panel verified"
}

backup_panel() {
    st WAIT "Creating backup..."
    mkdir -p "$BACKUP_DIR"
    local NOW BPATH d
    NOW=$(date +%Y%m%d_%H%M%S)
    BPATH="$BACKUP_DIR/arix_backup_${NOW}"
    mkdir -p "$BPATH"
    for d in resources public app routes config database; do
        [ -d "$PANEL_DIR/$d" ] && cp -a "$PANEL_DIR/$d" "$BPATH/" 2>/dev/null
    done
    [ -f "$PANEL_DIR/.env" ] && cp -a "$PANEL_DIR/.env" "$BPATH/" 2>/dev/null
    echo "$BPATH" > "$TMP_DIR/backup_path.txt"
    st OK "Backup: $BPATH"
}

fix_errors() {
    st WAIT "Running error fixes..."
    cd "$PANEL_DIR" 2>/dev/null || return 1
    php artisan migrate --force 2>/dev/null || {
        php artisan migrate:rollback --force 2>/dev/null || true
        php artisan migrate --force 2>/dev/null || true
    }
    [ ! -L "$PANEL_DIR/public/storage" ] && php artisan storage:link --force 2>/dev/null || true
    php artisan config:cache 2>/dev/null || true
    php artisan view:cache 2>/dev/null || true
    php artisan event:cache 2>/dev/null || true
    php artisan queue:restart 2>/dev/null || true
    chmod -R 775 "$PANEL_DIR/storage" 2>/dev/null || true
    chmod -R 775 "$PANEL_DIR/bootstrap/cache" 2>/dev/null || true
    chown -R www-data:www-data "$PANEL_DIR" 2>/dev/null || true
    php artisan view:clear 2>/dev/null || true
    php artisan config:clear 2>/dev/null || true
    php artisan cache:clear 2>/dev/null || true
    php artisan route:clear 2>/dev/null || true
    php artisan optimize:clear 2>/dev/null || true
    if [ ! -d "$PANEL_DIR/public/build" ] || [ -z "$(ls -A "$PANEL_DIR/public/build" 2>/dev/null)" ]; then
        st WAIT "Rebuilding assets..."
        export NODE_OPTIONS=--openssl-legacy-provider
        run_live "yarn-install" yarn install || true
        run_live "yarn-build" yarn build:production || true
    fi
    st OK "Error fixing complete"
}

do_install() {
    local VERSION="$1" DIRNAME="$2"
    local URL="$ARIX_URL/$DIRNAME/pterodactyl.zip"
    st INFO "Installing Arix $VERSION"
    validate_panel || return 1
    backup_panel

    ensure_sys_deps
    if ! command -v unzip >/dev/null 2>&1; then
        st WAIT "Installing dependencies..."
        run_live "apt-update" env DEBIAN_FRONTEND=noninteractive apt-get update -y -q || true
        install_steps "System packages" unzip curl wget || true
    fi

    if [ -f "$LOCAL_ARIX/$DIRNAME/pterodactyl.zip" ]; then
        st OK "Local file: $DIRNAME/pterodactyl.zip"
        cp "$LOCAL_ARIX/$DIRNAME/pterodactyl.zip" "$TMP_DIR/pterodactyl.zip"
    else
        if ! run_dl "Arix $VERSION" "$URL" "$TMP_DIR/pterodactyl.zip"; then
            st WARN "Primary failed — trying fallback..."
            if ! run_dl "Arix fallback" "$ARIX_FALLBACK/$DIRNAME/pterodactyl.zip" "$TMP_DIR/pterodactyl.zip"; then
                st ERR "All download sources failed"; return 1
            fi
        fi
    fi
    if ! head -c 2 "$TMP_DIR/pterodactyl.zip" | grep -q 'PK'; then
        st ERR "Corrupted ZIP"; return 1
    fi
    st OK "ZIP verified"

    st WAIT "Extracting..."
    if ! run_live "unzip" unzip -oq "$TMP_DIR/pterodactyl.zip" -d "$TMP_DIR/extracted"; then
        st ERR "Extraction failed"; return 1
    fi
    local INNER="$TMP_DIR/extracted"
    [ -d "$TMP_DIR/extracted/pterodactyl" ] && INNER="$TMP_DIR/extracted/pterodactyl"

    st INFO "Security scan..."
    local badfile scanned=0
    for badfile in \
        "$INNER/app/Console/Commands/Arix.php" \
        "$INNER/arix/ins/ins.php" \
        "$INNER/arix/up/up.php"; do
        if [ -f "$badfile" ]; then
            rm -f "$badfile"
            st WARN "Removed $(basename "$badfile")"
            scanned=$((scanned+1))
        fi
    done
    [ $scanned -eq 0 ] && st OK "Clean"

    st WAIT "Installing theme files..."
    local d
    for d in resources public app routes config database; do
        if [ -d "$INNER/$d" ]; then
            cp -rf "$INNER/$d"/* "$PANEL_DIR/$d/" 2>/dev/null
            st OK "$d/"
        fi
    done
    [ -d "$INNER/arix" ] && cp -rf "$INNER/arix" "$PANEL_DIR/" 2>/dev/null && st OK "arix/"
    [ -d "$INNER/bootstrap" ] && cp -rf "$INNER/bootstrap"/* "$PANEL_DIR/bootstrap/" 2>/dev/null && st OK "bootstrap/"

    local NODE_VER
    NODE_VER=$(node -v 2>/dev/null | cut -d'.' -f1 | sed 's/v//')
    if [ "$NODE_VER" != "22" ]; then
        st WAIT "Installing Node.js 22..."
        run_live "nodesource" bash -c 'curl -fsSL https://deb.nodesource.com/setup_22.x | bash -'
        run_live "nodejs" env DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
    fi
    command -v yarn >/dev/null 2>&1 || run_live "yarn" npm install -g yarn
    st WAIT "Building panel..."
    export NODE_OPTIONS=--openssl-legacy-provider
    run_live "yarn-add" yarn add xterm-addon-unicode11 || true
    run_live "yarn-install" yarn install || true
    run_live "yarn-build" yarn build:production || true
    st OK "Build complete"

    st WAIT "Fixing permissions..."
    chown -R www-data:www-data "$PANEL_DIR" 2>/dev/null
    chmod -R 755 storage/* bootstrap/cache/ 2>/dev/null
    fix_errors
    rm -rf "$TMP_DIR"
    st OK "Arix $VERSION installed successfully"
}

do_uninstall() {
    st WARN "Uninstalling Arix..."
    read -rp "  Confirm? (y/N): " cf
    if [[ "$cf" =~ ^[Yy]$ ]]; then
        cd "$PANEL_DIR" 2>/dev/null || { st ERR "Panel not found"; return 1; }
        php artisan arix:uninstall 2>/dev/null || php artisan arix uninstall 2>/dev/null || true
        rm -rf arix/ 2>/dev/null
        rm -f app/Console/Commands/Arix.php app/Console/Commands/ArixLang.php 2>/dev/null
        rm -f "$PANEL_DIR/storage/.hn_theme_arix"* 2>/dev/null
        php artisan view:clear 2>/dev/null
        php artisan optimize:clear 2>/dev/null
        chown -R www-data:www-data "$PANEL_DIR" 2>/dev/null
        st OK "Arix uninstalled"
    else
        st INFO "Cancelled"
    fi
    pause
}

do_info() {
    echo ""
    if [ -d "$PANEL_DIR/arix" ]; then
        echo -e "  ${W}Status:${NC}   ${G}Installed${NC}"
        echo -e "  ${W}Panel:${NC}    ${PANEL_DIR}"
        if [ -f "$PANEL_DIR/arix/package.json" ]; then
            local arix_ver
            arix_ver=$(grep '"version"' "$PANEL_DIR/arix/package.json" 2>/dev/null | head -1 | cut -d'"' -f4)
            echo -e "  ${W}Version:${NC}  ${arix_ver:-Unknown}"
        fi
        local arix_files arix_size
        arix_files=$(find "$PANEL_DIR/arix" -type f 2>/dev/null | wc -l)
        arix_size=$(du -sh "$PANEL_DIR/arix" 2>/dev/null | awk '{print $1}')
        echo -e "  ${W}Files:${NC}    ${arix_files}"
        echo -e "  ${W}Size:${NC}     ${arix_size:-Unknown}"
    else
        echo -e "  ${W}Status:${NC}   ${R}Not Installed${NC}"
        echo -e "  ${W}Available:${NC} v2.1.0 | v2.0.8 | v1.3.1 | AV1"
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
    echo -e "  ${C}◆ ARIX OPERATIONS${NC}"
    echo -e "     ${GR}[1]${NC} Install / Update    ${DG}•${NC} Choose version"
    echo -e "     ${GR}[2]${NC} Uninstall           ${DG}•${NC} Remove Arix"
    echo -e "     ${GR}[3]${NC} Info                ${DG}•${NC} Version / files"
    echo ""
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Option${NC} ${DG}(0-3):${NC} "
    read -r choice
    case "$choice" in
        1)
            if choose_version; then
                do_install "$ARIX_VER" "$ARIX_DIR"
                pause
            fi
            ;;
        2) do_uninstall ;;
        3) do_info ;;
        0) rm -rf "$TMP_DIR" 2>/dev/null; clear; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.7 ;;
    esac
done
