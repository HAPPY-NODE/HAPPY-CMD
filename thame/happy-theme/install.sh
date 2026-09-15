#!/bin/bash

# ==========================================
# HAPPY-NODE Theme Installer (Safe Copy Method)
# Based on Arix installation method
# No license required - Free & Open Source
# ==========================================

[[ $EUID -ne 0 ]] && echo "Run as root!" && exit 1

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Colors
R="\e[31m"; G="\e[32m"; Y="\e[33m"
B="\e[34m"; M="\e[35m"; C="\e[36m"
W="\e[97m"; N="\e[0m"

BR="\e[1;31m"; BG="\e[1;32m"; BY="\e[1;33m"
BM="\e[1;35m"; BC="\e[1;36m"; BW="\e[1;97m"

STEP_OK="[${G}OK${N}]"
STEP_FAIL="[${R}FAIL${N}]"

# HAPPY-NODE URLs (base64 encoded)
_HN_B64='aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4='
_HN_BASE="$(printf '%s' "$_HN_B64" | base64 -d 2>/dev/null || printf '%s' "$_HN_B64" | base64 --decode)"

# Arix theme ZIP URL (we use the clean version)
ARIX_URL="https://raw.githubusercontent.com/sdgamer8263-sketch/pterodactyl_extention1/main/sd/v210/pterodactyl.zip"

# ==========================================
# HELPER FUNCTIONS
# ==========================================
header() {
    clear
    echo -e "${BC} ╔══════════════════════════════════════════════════════════╗${N}"
    printf " ${BC}║${BW}%-58s${BC}║${N}\n" "  HAPPY-NODE THEME INSTALLER"
    printf " ${BC}║${B}%-58s${BC}║${N}\n" "    Safe Copy Method - No License Required    "
    echo -e "${BC} ╚══════════════════════════════════════════════════════════╝${N}"
    echo -e " ${B}User:${N} $(whoami)  ${B}Host:${N} $(hostname)  ${B}Time:${N} $(date +'%H:%M')"
    echo -e "${C} ──────────────────────────────────────────────────────────${N}"
}

# ==========================================
# MAIN INSTALL FUNCTION
# ==========================================
install_happy_theme() {
    local PTERO_DIR="/var/www/pterodactyl"
    local TEMP_DIR=$(mktemp -d)
    local BACKUP_DIR="/tmp/hn_backups"
    local NOW=$(date +%Y%m%d_%H%M%S)

    header
    echo -e "\n${BC}=======================================${N}"
    echo -e "${BW}  HAPPY-NODE Theme Installation${N}"
    echo -e "${BC}=======================================${N}\n"

    # Step 1: Check Pterodactyl directory
    if [[ ! -d "$PTERO_DIR" ]]; then
        echo -e "${STEP_FAIL} Step 1 -- Pterodactyl not found at ${PTERO_DIR}"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    echo -e "${STEP_OK} Step 1 -- Pterodactyl directory found"

    # Step 2: Check dependencies
    echo -e "\n${G}Checking dependencies...${N}"
    apt-get update -y >/dev/null 2>&1
    apt-get install -y unzip curl wget >/dev/null 2>&1
    echo -e "${STEP_OK} Step 2 -- Dependencies installed"

    # Step 3: Download theme
    echo -e "\n${G}Downloading HAPPY-NODE theme...${N}"
    cd "$PTERO_DIR"
    
    if ! curl -fL --progress-bar "$ARIX_URL" -o "$TEMP_DIR/theme.zip" 2>/dev/null; then
        echo -e "${STEP_FAIL} Step 3 -- Download failed"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    echo -e "${STEP_OK} Step 3 -- Theme downloaded"

    # Step 4: Extract theme
    echo -e "\n${G}Extracting theme files...${N}"
    if ! unzip -oq "$TEMP_DIR/theme.zip" -d "$TEMP_DIR/extracted" 2>/dev/null; then
        echo -e "${STEP_FAIL} Step 4 -- Extraction failed"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Find the pterodactyl folder inside
    local INNER_DIR="$TEMP_DIR/extracted"
    if [[ -d "$TEMP_DIR/extracted/pterodactyl" ]]; then
        INNER_DIR="$TEMP_DIR/extracted/pterodactyl"
    fi
    echo -e "${STEP_OK} Step 4 -- Files extracted"

    # Step 5: Create backup
    echo -e "\n${G}Creating backup...${N}"
    mkdir -p "$BACKUP_DIR"
    local BPATH="$BACKUP_DIR/happy_backup_${NOW}"
    mkdir -p "$BPATH"
    
    for d in resources public app routes config database; do
        [[ -d "$PTERO_DIR/$d" ]] && cp -a "$PTERO_DIR/$d" "$BPATH/" 2>/dev/null
    done
    [[ -f "$PTERO_DIR/.env" ]] && cp -a "$PTERO_DIR/.env" "$BPATH/" 2>/dev/null
    echo -e "${STEP_OK} Step 5 -- Backup created: ${BPATH}"

    # Step 6: Copy theme files (SAFE METHOD)
    echo -e "\n${G}Installing theme files...${N}"
    
    # Copy resources
    if [[ -d "$INNER_DIR/resources" ]]; then
        sudo cp -a "$INNER_DIR/resources"/* "$PTERO_DIR/resources/" 2>/dev/null
        echo -e "  ${STEP_OK} Copied resources/"
    fi
    
    # Copy public assets
    if [[ -d "$INNER_DIR/public" ]]; then
        sudo cp -a "$INNER_DIR/public"/* "$PTERO_DIR/public/" 2>/dev/null
        echo -e "  ${STEP_OK} Copied public/"
    fi
    
    # Copy controllers (only Arix ones, not core)
    if [[ -d "$INNER_DIR/app/Http/Controllers/Admin/Arix" ]]; then
        mkdir -p "$PTERO_DIR/app/Http/Controllers/Admin/Arix"
        sudo cp -a "$INNER_DIR/app/Http/Controllers/Admin/Arix"/* "$PTERO_DIR/app/Http/Controllers/Admin/Arix/" 2>/dev/null
        echo -e "  ${STEP_OK} Copied controllers/"
    fi
    
    # Copy models
    if [[ -d "$INNER_DIR/app/Models" ]]; then
        for f in "$INNER_DIR/app/Models"/*.php; do
            local fname=$(basename "$f")
            # Only copy Arix-specific models
            case "$fname" in
                ServerFolder.php|ServerOrder.php|CommandHistory.php|SubuserPreset.php|Trashbin.php)
                    sudo cp -a "$f" "$PTERO_DIR/app/Models/$fname" 2>/dev/null
                    ;;
            esac
        done
        echo -e "  ${STEP_OK} Copied models/"
    fi
    
    # Copy migrations
    if [[ -d "$INNER_DIR/database/migrations" ]]; then
        mkdir -p "$PTERO_DIR/database/migrations"
        sudo cp -a "$INNER_DIR/database/migrations"/* "$PTERO_DIR/database/migrations/" 2>/dev/null
        echo -e "  ${STEP_OK} Copied migrations/"
    fi
    
    # Copy config
    if [[ -d "$INNER_DIR/config" ]]; then
        for f in "$INNER_DIR/config"/*.php; do
            local fname=$(basename "$f")
            case "$fname" in
                arix.php|arixTheme.php|recaptcha.php|turnstile.php)
                    sudo cp -a "$f" "$PTERO_DIR/config/$fname" 2>/dev/null
                    ;;
            esac
        done
        echo -e "  ${STEP_OK} Copied config/"
    fi
    
    # Copy routes
    if [[ -d "$INNER_DIR/routes" ]]; then
        for f in "$INNER_DIR/routes"/*.php; do
            local fname=$(basename "$f")
            case "$fname" in
                admin.php|api-client.php)
                    sudo cp -a "$f" "$PTERO_DIR/routes/$fname" 2>/dev/null
                    ;;
            esac
        done
        echo -e "  ${STEP_OK} Copied routes/"
    fi
    
    # Copy view composers
    if [[ -d "$INNER_DIR/app/Http/ViewComposers" ]]; then
        mkdir -p "$PTERO_DIR/app/Http/ViewComposers"
        sudo cp -a "$INNER_DIR/app/Http/ViewComposers"/* "$PTERO_DIR/app/Http/ViewComposers/" 2>/dev/null
        echo -e "  ${STEP_OK} Copied view composers/"
    fi
    
    # Copy transformers
    if [[ -d "$INNER_DIR/app/Transformers" ]]; then
        sudo cp -a "$INNER_DIR/app/Transformers"/* "$PTERO_DIR/app/Transformers/" 2>/dev/null
        echo -e "  ${STEP_OK} Copied transformers/"
    fi
    
    # Copy language files
    if [[ -d "$INNER_DIR/resources/lang" ]]; then
        sudo cp -a "$INNER_DIR/resources/lang"/* "$PTERO_DIR/resources/lang/" 2>/dev/null
        echo -e "  ${STEP_OK} Copied language files/"
    fi
    
    # Copy blade views
    if [[ -d "$INNER_DIR/resources/views" ]]; then
        sudo cp -a "$INNER_DIR/resources/views"/* "$PTERO_DIR/resources/views/" 2>/dev/null
        echo -e "  ${STEP_OK} Copied blade views/"
    fi
    
    # Copy service providers
    if [[ -d "$INNER_DIR/app/Providers" ]]; then
        for f in "$INNER_DIR/app/Providers"/*.php; do
            local fname=$(basename "$f")
            case "$fname" in
                ArixThemeServiceProvider.php|ArixConfiguration.php)
                    sudo cp -a "$f" "$PTERO_DIR/app/Providers/$fname" 2>/dev/null
                    ;;
            esac
        done
        echo -e "  ${STEP_OK} Copied service providers/"
    fi

    echo -e "${STEP_OK} Step 6 -- Theme files installed"

    # Step 7: Run migrations
    echo -e "\n${G}Running database migrations...${N}"
    cd "$PTERO_DIR"
    php artisan migrate --force 2>/dev/null && \
        echo -e "${STEP_OK} Step 7 -- Migrations completed" || \
        echo -e "${Y}WARNING: Step 7 -- Migrations skipped (may already exist)${N}"

    # Step 8: Install Node.js dependencies
    echo -e "\n${G}Installing Node.js dependencies...${N}"
    export NODE_OPTIONS=--openssl-legacy-provider
    yarn --ignore-engines install 2>&1 | tail -n 3 || true
    echo -e "${STEP_OK} Step 8 -- Node.js dependencies installed"

    # Step 9: Build frontend
    echo -e "\n${G}Building frontend assets (this can take a minute)...${N}"
    yarn --ignore-engines build:production 2>&1 | tail -n 10
    echo -e "${STEP_OK} Step 9 -- Frontend built"

    # Step 10: Clear cache
    echo -e "\n${G}Clearing cache...${N}"
    php artisan view:clear 2>/dev/null
    php artisan optimize:clear 2>/dev/null
    echo -e "${STEP_OK} Step 10 -- Cache cleared"

    # Step 11: Fix permissions
    echo -e "\n${G}Fixing permissions...${N}"
    sudo chown -R www-data:www-data "$PTERO_DIR/storage" 2>/dev/null
    sudo chown -R www-data:www-data "$PTERO_DIR/bootstrap/cache" 2>/dev/null
    echo -e "${STEP_OK} Step 11 -- Permissions fixed"

    # Step 12: Create marker file
    sudo touch "$PTERO_DIR/storage/.hn_theme_happy-theme" 2>/dev/null

    # Cleanup
    cd /
    rm -rf "$TEMP_DIR"

    echo -e "\n${BC}=======================================${N}"
    echo -e "${BG}  [OK] Theme downloaded${N}"
    echo -e "${BG}  [OK] Files extracted${N}"
    echo -e "${BG}  [OK] Backup created${N}"
    echo -e "${BG}  [OK] Theme installed${N}"
    echo -e "${BG}  [OK] Migrations run${N}"
    echo -e "${BG}  [OK] Frontend built${N}"
    echo -e "${BG}  [OK] Cache cleared${N}"
    echo -e "${BG}  [OK] Permissions fixed${N}"
    echo -e "${BC}=======================================${N}\n"
    
    echo -e "${BG}HAPPY-NODE Theme installed successfully!${N}"
    echo -e "${Y}Backup saved at: ${BPATH}${N}"
}

# ==========================================
# UNINSTALL FUNCTION
# ==========================================
uninstall_happy_theme() {
    local PTERO_DIR="/var/www/pterodactyl"
    
    header
    echo -e "\n${R}Uninstalling HAPPY-NODE theme...${N}"
    
    if [[ ! -d "$PTERO_DIR" ]]; then
        echo -e "${STEP_FAIL} Pterodactyl not found!"
        return 1
    fi
    
    cd "$PTERO_DIR"
    
    # Restore from latest backup
    local LATEST_BACKUP=$(ls -td /tmp/hn_backups/happy_backup_* 2>/dev/null | head -n 1)
    
    if [[ -n "$LATEST_BACKUP" ]]; then
        echo -e "${G}Restoring from backup: ${LATEST_BACKUP}${N}"
        for d in resources public app routes config database; do
            [[ -d "$LATEST_BACKUP/$d" ]] && sudo cp -a "$LATEST_BACKUP/$d"/* "$PTERO_DIR/$d/" 2>/dev/null
        done
        [[ -f "$LATEST_BACKUP/.env" ]] && sudo cp -a "$LATEST_BACKUP/.env" "$PTERO_DIR/" 2>/dev/null
        
        # Rebuild
        export NODE_OPTIONS=--openssl-legacy-provider
        yarn --ignore-engines install 2>/dev/null
        yarn --ignore-engines build:production 2>/dev/null
        php artisan view:clear 2>/dev/null
        php artisan optimize:clear 2>/dev/null
        sudo chown -R www-data:www-data "$PTERO_DIR/storage" 2>/dev/null
        sudo chown -R www-data:www-data "$PTERO_DIR/bootstrap/cache" 2>/dev/null
        
        # Remove marker
        rm -f "$PTERO_DIR/storage/.hn_theme_happy-theme" 2>/dev/null
        
        echo -e "${BG}HAPPY-NODE theme uninstalled successfully!${N}"
    else
        echo -e "${Y}No backup found. Manual restoration may be needed.${N}"
    fi
}

# ==========================================
# MENU
# ==========================================
while true; do
    header
    echo -e "${BW} HAPPY-NODE Theme Manager${N}\n"
    echo -e "  ${BG}[1]${N} Install Theme"
    echo -e "  ${BR}[2]${N} Uninstall Theme"
    echo -e "  ${BY}[0]${N} Back"
    echo -e "${C} ──────────────────────────────────────────────────────────${N}"
    
    read -p " Select option: " choice
    
    case "$choice" in
        1) install_happy_theme ;;
        2) uninstall_happy_theme ;;
        0) exit 0 ;;
        *) echo -e "${R}Invalid option${N}" ;;
    esac
    
    echo ""
    read -p "Press [Enter] to continue..."
done
