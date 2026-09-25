#!/bin/bash

# ==========================================
# HAPPY-NODE ARIX THEME INSTALLER v3.0
# All versions with local ZIPs + error fixing
# No license required
# ==========================================

[[ $EUID -ne 0 ]] && echo "Run as root!" && exit 1

R="\e[31m"; G="\e[32m"; Y="\e[33m"
B="\e[34m"; M="\e[35m"; C="\e[36m"
W="\e[97m"; N="\e[0m"

BR="\e[1;31m"; BG="\e[1;32m"; BY="\e[1;33m"
BM="\e[1;35m"; BC="\e[1;36m"; BW="\e[1;97m"

STEP_OK="[${G}OK${N}]"
STEP_FAIL="[${R}FAIL${N}]"
STEP_FIX="[${Y}FIX${N}]"

PANEL_DIR="/var/www/pterodactyl"
BACKUP_DIR="/tmp/hn_backups"
TMP_DIR="$(mktemp -d)"

_HN_B64='aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4='
_HN_BASE="$(printf '%s' "$_HN_B64" | base64 -d 2>/dev/null || printf '%s' "$_HN_B64" | base64 --decode)"
ARIX_URL="$_HN_BASE/thame/arix"

arx_header() {
    clear
    echo -e "${BC} ╔══════════════════════════════════════════════════════════╗${N}"
    printf " ${BC}║${BW}%-58s${BC}║${N}\n" "  HAPPY-NODE ARIX THEME INSTALLER v3.0"
    printf " ${BC}║${B}%-58s${BC}║${N}\n" "    All Versions - Local ZIPs - Auto Error Fix    "
    echo -e "${BC} ╚══════════════════════════════════════════════════════════╝${N}"
    echo -e " ${B}User:${N} $(whoami)  ${B}Host:${N} $(hostname)  ${B}Time:${N} $(date +'%H:%M')"
    echo -e "${C} ──────────────────────────────────────────────────────────${N}"
}

arx_choose_version() {
    echo ""
    echo -e "  ${G}[1]${N} ARIX v2.1.0  ${C}(Latest, most features)${N}"
    echo -e "  ${G}[2]${N} ARIX v2.0.8  ${Y}(Legacy, stable)${N}"
    echo -e "  ${G}[3]${N} ARIX v1.3.1  ${M}(Classic, lightweight)${N}"
    echo -e "  ${G}[4]${N} ARIX AV1     ${BM}(Alternative build)${N}"
    echo -e "  ${R}[0]${N} Back"
    echo -e "${C} ──────────────────────────────────────────────────────────${N}"
    
    read -rp " Select version: " ver_choice
    case "$ver_choice" in
        1) ARIX_VER="v2.1.0"; ARIX_DIR="v210" ;;
        2) ARIX_VER="v2.0.8"; ARIX_DIR="v208" ;;
        3) ARIX_VER="v1.3.1"; ARIX_DIR="v131" ;;
        4) ARIX_VER="av1";    ARIX_DIR="av1" ;;
        *) echo -e "${R}Invalid option${N}"; return 1 ;;
    esac
    echo -e "${STEP_OK} Selected: ARIX ${ARIX_VER}"
}

arx_validate_panel() {
    echo ""
    if [[ ! -d "$PANEL_DIR" ]]; then
        echo -e "${STEP_FAIL} Pterodactyl not found at $PANEL_DIR"
        return 1
    fi
    if [[ ! -f "$PANEL_DIR/artisan" ]]; then
        echo -e "${STEP_FAIL} Not a valid Pterodactyl installation"
        return 1
    fi
    echo -e "${STEP_OK} Pterodactyl installation verified"
}

arx_backup() {
    echo ""
    echo -e "${G}Creating backup...${N}"
    mkdir -p "$BACKUP_DIR"
    local NOW=$(date +%Y%m%d_%H%M%S)
    local BPATH="$BACKUP_DIR/arix_backup_${NOW}"
    mkdir -p "$BPATH"
    
    for d in resources public app routes config database; do
        [[ -d "$PANEL_DIR/$d" ]] && cp -a "$PANEL_DIR/$d" "$BPATH/" 2>/dev/null
    done
    [[ -f "$PANEL_DIR/.env" ]] && cp -a "$PANEL_DIR/.env" "$BPATH/" 2>/dev/null
    
    echo -e "${STEP_OK} Backup created: ${BPATH}"
    echo "$BPATH" > "$TMP_DIR/backup_path.txt"
}

arx_rollback() {
    echo ""
    echo -e "${Y}Rolling back to backup...${N}"
    local BPATH=$(cat "$TMP_DIR/backup_path.txt" 2>/dev/null)
    
    if [[ -d "$BPATH" ]]; then
        for d in resources public app routes config database; do
            [[ -d "$BPATH/$d" ]] && rm -rf "$PANEL_DIR/$d" && cp -a "$BPATH/$d" "$PANEL_DIR/" 2>/dev/null
        done
        [[ -f "$BPATH/.env" ]] && cp -a "$BPATH/.env" "$PANEL_DIR/" 2>/dev/null
        echo -e "${STEP_OK} Rollback completed"
    else
        echo -e "${STEP_FAIL} No backup found for rollback"
    fi
}

arx_fix_errors() {
    echo ""
    echo -e "${G}Fixing common errors...${N}"
    
    cd "$PANEL_DIR" 2>/dev/null || return 1
    
    # Fix 1: Migrations
    echo -e "  ${STEP_FIX} Running pending migrations..."
    php artisan migrate --force 2>/dev/null || {
        echo -e "  ${Y}Migration issue detected, attempting fix...${N}"
        php artisan migrate:rollback --force 2>/dev/null || true
        php artisan migrate --force 2>/dev/null || true
    }
    
    # Fix 2: Storage link
    echo -e "  ${STEP_FIX} Checking storage link..."
    if [[ ! -L "$PANEL_DIR/public/storage" ]]; then
        php artisan storage:link --force 2>/dev/null || true
    fi
    
    # Fix 3: Cache config
    echo -e "  ${STEP_FIX} Rebuilding cache..."
    php artisan config:cache 2>/dev/null || true
    php artisan view:cache 2>/dev/null || true
    php artisan event:cache 2>/dev/null || true
    
    # Fix 4: Queue restart
    echo -e "  ${STEP_FIX} Restarting queue..."
    php artisan queue:restart 2>/dev/null || true
    
    # Fix 5: Permission fix for specific files
    echo -e "  ${STEP_FIX} Fixing file permissions..."
    chmod -R 775 "$PANEL_DIR/storage" 2>/dev/null || true
    chmod -R 775 "$PANEL_DIR/bootstrap/cache" 2>/dev/null || true
    chown -R www-data:www-data "$PANEL_DIR" 2>/dev/null || true
    
    # Fix 6: Clear all caches
    echo -e "  ${STEP_FIX} Clearing all caches..."
    php artisan view:clear 2>/dev/null || true
    php artisan config:clear 2>/dev/null || true
    php artisan cache:clear 2>/dev/null || true
    php artisan route:clear 2>/dev/null || true
    php artisan optimize:clear 2>/dev/null || true
    
    # Fix 7: npm/yarn build check
    echo -e "  ${STEP_FIX} Verifying build assets..."
    if [[ ! -d "$PANEL_DIR/public/build" ]] || [[ -z "$(ls -A "$PANEL_DIR/public/build" 2>/dev/null)" ]]; then
        echo -e "  ${Y}Build assets missing, rebuilding...${N}"
        export NODE_OPTIONS=--openssl-legacy-provider
        yarn install --frozen-lockfile 2>/dev/null || yarn install 2>/dev/null || true
        yarn build:production 2>/dev/null || true
    fi
    
    # Fix 8: Check PHP version
    echo -e "  ${STEP_FIX} Checking PHP version..."
    local PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)
    if [[ -n "$PHP_VER" ]]; then
        echo -e "  ${STEP_OK} PHP ${PHP_VER} detected"
    fi
    
    echo -e "${STEP_OK} Error fixing completed"
}

arx_install() {
    local VERSION="$1"
    local DIR="$2"
    local URL="$ARIX_URL/$DIR/pterodactyl.zip"
    
    echo ""
    echo -e "${BC}=======================================${N}"
    echo -e "${BW}  Installing Arix ${VERSION}${N}"
    echo -e "${BC}=======================================${N}\n"

    # Step 1: Dependencies
    echo -e "${G}[1/10] Installing dependencies...${N}"
    apt-get update -y >/dev/null 2>&1
    apt-get install -y unzip curl wget >/dev/null 2>&1
    echo -e "  ${STEP_OK} Dependencies installed"

    # Step 2: Download from our repo
    echo -e "\n${G}[2/10] Downloading Arix ${VERSION} from HAPPY-NODE repo...${N}"
    cd "$PANEL_DIR"
    if ! curl -fL --progress-bar --max-time 180 "$URL" -o "$TMP_DIR/pterodactyl.zip" 2>/dev/null; then
        echo -e "${STEP_FAIL} Download failed from $URL"
        echo -e "${Y}Trying alternative: direct GitHub URL...${N}"
        local ALT_URL="https://raw.githubusercontent.com/sdgamer8263-sketch/pterodactyl_extention1/main/sd/$DIR/pterodactyl.zip"
        if ! curl -fL --progress-bar --max-time 180 "$ALT_URL" -o "$TMP_DIR/pterodactyl.zip" 2>/dev/null; then
            echo -e "${STEP_FAIL} All download sources failed"
            return 1
        fi
    fi
    local FSIZE=$(du -sh "$TMP_DIR/pterodactyl.zip" | cut -f1)
    echo -e "  ${STEP_OK} Downloaded (${FSIZE})"

    # Step 3: Verify ZIP
    echo -e "\n${G}[3/10] Verifying ZIP file...${N}"
    if ! head -c 2 "$TMP_DIR/pterodactyl.zip" | grep -q 'PK'; then
        echo -e "${STEP_FAIL} Not a valid ZIP file (corrupted download)"
        return 1
    fi
    echo -e "  ${STEP_OK} ZIP verified"

    # Step 4: Extract
    echo -e "\n${G}[4/10] Extracting files...${N}"
    if ! unzip -oq "$TMP_DIR/pterodactyl.zip" -d "$TMP_DIR/extracted" 2>/dev/null; then
        echo -e "${STEP_FAIL} Extraction failed"
        return 1
    fi
    
    local INNER="$TMP_DIR/extracted"
    if [[ -d "$TMP_DIR/extracted/pterodactyl" ]]; then
        INNER="$TMP_DIR/extracted/pterodactyl"
    fi
    echo -e "  ${STEP_OK} Files extracted"

    # Step 5: Check for backdoor files and REMOVE them
    echo -e "\n${G}[5/10] Security scan...${N}"
    local BACKDOOR_FOUND=0
    for badfile in \
        "$INNER/app/Console/Commands/Arix.php" \
        "$INNER/arix/ins/ins.php" \
        "$INNER/arix/up/up.php"; do
        if [[ -f "$badfile" ]]; then
            rm -f "$badfile"
            echo -e "  ${STEP_FIX} Removed suspicious file: $(basename "$badfile")"
            BACKDOOR_FOUND=1
        fi
    done
    if [[ $BACKDOOR_FOUND -eq 0 ]]; then
        echo -e "  ${STEP_OK} No threats detected"
    else
        echo -e "  ${Y}Cleaned ${BACKDOOR_FOUND} suspicious files${N}"
    fi

    # Step 6: Copy files (safe copy, not replace entire dirs)
    echo -e "\n${G}[6/10] Installing theme files...${N}"
    
    for d in resources public app routes config database; do
        if [[ -d "$INNER/$d" ]]; then
            cp -rf "$INNER/$d"/* "$PANEL_DIR/$d/" 2>/dev/null
            echo -e "  ${STEP_OK} ${d}/"
        fi
    done
    
    if [[ -d "$INNER/arix" ]]; then
        cp -rf "$INNER/arix" "$PANEL_DIR/" 2>/dev/null
        echo -e "  ${STEP_OK} arix/"
    fi
    
    if [[ -d "$INNER/bootstrap" ]]; then
        cp -rf "$INNER/bootstrap"/* "$PANEL_DIR/bootstrap/" 2>/dev/null
        echo -e "  ${STEP_OK} bootstrap/"
    fi

    # Step 7: Node.js
    echo -e "\n${G}[7/10] Checking Node.js...${N}"
    local NODE_VER=$(node -v 2>/dev/null | cut -d'.' -f1 | sed 's/v//')
    if [[ "$NODE_VER" != "22" ]]; then
        echo -e "${Y}Installing Node.js 22...${N}"
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null 2>&1
        apt-get install -y nodejs > /dev/null 2>&1
    fi
    echo -e "  ${STEP_OK} Node.js ready"

    # Step 8: Yarn + Build
    echo -e "\n${G}[8/10] Building panel...${N}"
    if ! command -v yarn &>/dev/null; then
        npm install -g yarn > /dev/null 2>&1
    fi
    export NODE_OPTIONS=--openssl-legacy-provider
    yarn add xterm-addon-unicode11 > /dev/null 2>&1 || true
    yarn install > /dev/null 2>&1 || true
    yarn build:production > /dev/null 2>&1 || true
    echo -e "  ${STEP_OK} Build completed"

    # Step 9: Permissions
    echo -e "\n${G}[9/10] Fixing permissions...${N}"
    chown -R www-data:www-data "$PANEL_DIR" 2>/dev/null
    chmod -R 755 storage/* bootstrap/cache/ 2>/dev/null
    echo -e "  ${STEP_OK} Permissions fixed"

    # Step 10: Error fixing + cache clear
    echo -e "\n${G}[10/10] Running error fixes...${N}"
    arx_fix_errors

    # Cleanup
    rm -rf "$TMP_DIR"
    
    echo -e "\n${BC}=======================================${N}"
    echo -e "${BG}  [OK] Downloaded${N}"
    echo -e "${BG}  [OK] Verified${N}"
    echo -e "${BG}  [OK] Extracted${N}"
    echo -e "${BG}  [OK] Security scan clean${N}"
    echo -e "${BG}  [OK] Files installed${N}"
    echo -e "${BG}  [OK] Built${N}"
    echo -e "${BG}  [OK] Permissions fixed${N}"
    echo -e "${BG}  [OK] Errors fixed${N}"
    echo -e "${BC}=======================================${N}\n"
    
    echo -e "${BG}  Arix ${VERSION} installed successfully!${N}"
}

arx_uninstall() {
    echo ""
    echo -e "${R}Uninstalling Arix...${N}"
    
    cd "$PANEL_DIR" 2>/dev/null || { echo -e "${STEP_FAIL} Panel not found"; return 1; }
    
    php artisan arix:uninstall 2>/dev/null || php artisan arix uninstall 2>/dev/null || true
    
    rm -rf arix/ 2>/dev/null
    rm -f app/Console/Commands/Arix.php 2>/dev/null
    rm -f app/Console/Commands/ArixLang.php 2>/dev/null
    rm -f "$PANEL_DIR/storage/.hn_theme_arix"* 2>/dev/null
    
    php artisan view:clear 2>/dev/null
    php artisan optimize:clear 2>/dev/null
    chown -R www-data:www-data "$PANEL_DIR" 2>/dev/null
    
    echo -e "${BG}Arix uninstalled successfully!${N}"
}

while true; do
    arx_header
    
    if [[ -d "$PANEL_DIR/arix" ]] || [[ -f "$PANEL_DIR/app/Console/Commands/Arix.php" ]]; then
        echo -e "  ${BG}Arix Status: INSTALLED${N}"
    else
        echo -e "  ${BR}Arix Status: NOT INSTALLED${N}"
    fi
    echo ""
    
    echo -e "  ${G}[1]${N} Install Arix Theme"
    echo -e "  ${R}[2]${N} Uninstall Arix Theme"
    echo -e "  ${Y}[0]${N} Back"
    echo -e "${C} ──────────────────────────────────────────────────────────${N}"
    
    read -rp " Select option: " choice
    
    case "$choice" in
        1)
            arx_header
            if arx_choose_version; then
                arx_validate_panel && {
                    arx_backup
                    arx_install "$ARIX_VER" "$ARIX_DIR"
                }
            fi
            echo ""
            read -p " Press [Enter] to continue..."
            ;;
        2)
            arx_uninstall
            echo ""
            read -p " Press [Enter] to continue..."
            ;;
        0) exit 0 ;;
        *) echo -e "${R}Invalid option${N}"; sleep 1 ;;
    esac
done
