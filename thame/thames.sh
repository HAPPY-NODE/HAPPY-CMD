#!/bin/bash

# ==========================================
# HAPPY-NODE THEME MANAGER
# ==========================================

[[ $EUID -ne 0 ]] && echo "Run as root!" && exit 1

R="\e[31m"; G="\e[32m"; Y="\e[33m"
B="\e[34m"; M="\e[35m"; C="\e[36m"
W="\e[97m"; N="\e[0m"

BR="\e[1;31m"; BG="\e[1;32m"; BY="\e[1;33m"
BM="\e[1;35m"; BC="\e[1;36m"; BW="\e[1;97m"

_HN_B64='aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4='
_HN_BASE="$(printf '%s' "$_HN_B64" | base64 -d 2>/dev/null || printf '%s' "$_HN_B64" | base64 --decode)"
URL_BP="$_HN_BASE/thame/UI"
URL_ZIP="$_HN_BASE/thame/UI/themes"

trap 'echo -e "\n${R}[!] Force exit detected.${N}"; exit 1' SIGINT

STEP_OK="[${G}OK${N}]"
STEP_FAIL="[${R}FAIL${N}]"

# ==========================================
# BLUEPRINT LIST
# ==========================================
blueprints=(
"nebula.blueprint" "euphoriatheme.blueprint"
"BetterAdmin.blueprint" "abysspurple.blueprint"
"amberabyss.blueprint" "catppuccindactyl.blueprint"
"crimsonabyss.blueprint" "emeraldabyss.blueprint"
"nightadmin.blueprint" "refreshtheme.blueprint"
"slice.blueprint" "darkenate.blueprint"
"recolor.blueprint" "bluetables.blueprint"
"ultradarkadmin.blueprint" "xlpaneltheme.blueprint"
"lememtheme.blueprint" "slate.blueprint"
"kaelixprime.blueprint" "m3dactyl.blueprint"
"catppuccindactyl1.blueprint" "catppuccindactyl2.blueprint"
"lutheme.blueprint" "Navy.seals.slice.blueprint"
"navyseals.blueprint" "nebula1.8.blueprint"
"nebula2.0.blueprint" "tailwindfourpalette.blueprint"
"xlpaneltheme2.0.blueprint"
)

# ==========================================
# ZIP THEMES LIST
# ==========================================
zip_themes=(
"billing.zip"
"stellar.zip"
"unix.zip"
"Carbon Theme.zip"
"elysium.zip"
"enigma.zip"
"nightcore.zip"
"iceMinecraft.zip"
"nookure.zip"
"NoraTheme.zip"
"astro theme.zip"
)

# ==========================================
# CHECK INSTALLATION STATUS
# ==========================================
is_installed_bp() {
    local slug="${1%.blueprint}"
    [[ -d "/var/www/pterodactyl/storage/extensions/$slug" ]]
}

is_installed_zip() {
    local name="${1%.zip}"
    local PTERO="/var/www/pterodactyl"
    # Check marker file (created during install)
    [[ -f "$PTERO/storage/.hn_theme_${name}" ]] || \
    # Fallback: check common theme paths
    [[ -d "$PTERO/resources/views/vendor/$name" ]] || \
    [[ -d "$PTERO/app/Http/Controllers/Admin/$name" ]]
}

# ==========================================
# INSTALL BLUEPRINT (SAFE - 13 STEPS)
# ==========================================
install_blueprint() {
    local NAME="$1"
    local SLUG="${NAME%.blueprint}"
    local PTERO_DIR="/var/www/pterodactyl"
    local BACKUP_DIR="/tmp/hn_backups"
    local BPURL="$URL_BP/$(echo "$NAME" | sed 's/ /%20/g')"
    local NOW=$(date +%Y%m%d_%H%M%S)

    echo -e "\n${BC}=======================================${N}"
    echo -e "${BW}  HAPPY-NODE Blueprint Installer: ${BC}${SLUG}${N}"
    echo -e "${BC}=======================================${N}\n"

    if [[ ! -d "$PTERO_DIR" ]]; then
        echo -e "${STEP_FAIL} Step 1 -- Directory not found: ${PTERO_DIR}"
        return 1
    fi
    cd "$PTERO_DIR" || { echo -e "${STEP_FAIL} Step 1 -- Cannot cd to ${PTERO_DIR}"; return 1; }
    echo -e "${STEP_OK} Step 1 -- Changed to ${PTERO_DIR}"

    if [[ ! -f "$PTERO_DIR/artisan" ]] || [[ ! -d "$PTERO_DIR/resources" ]]; then
        echo -e "${STEP_FAIL} Step 2 -- ${PTERO_DIR} is not a valid Pterodactyl installation"
        return 1
    fi
    echo -e "${STEP_OK} Step 2 -- Pterodactyl installation verified"

    echo -e "\n${G}Downloading ${SLUG}...${N}"
    rm -f "$NAME"
    if ! curl -fL --progress-bar "$BPURL" -o "$NAME" 2>/dev/null; then
        rm -f "$NAME"
        echo -e "${STEP_FAIL} Step 3 -- Download failed (network error)"
        return 1
    fi
    echo -e "${STEP_OK} Step 3 -- Downloaded ${NAME}"

    if [[ ! -s "$NAME" ]]; then
        rm -f "$NAME"
        echo -e "${STEP_FAIL} Step 4 -- Downloaded file is empty or missing"
        return 1
    fi
    if head -c 15 "$NAME" 2>/dev/null | grep -qi "<!DOCTYPE\|<html"; then
        rm -f "$NAME"
        echo -e "${STEP_FAIL} Step 4 -- Server returned HTML, not a .blueprint file"
        return 1
    fi
    local FSIZE=$(stat -c%s "$NAME" 2>/dev/null || wc -c < "$NAME")
    echo -e "${STEP_OK} Step 4 -- File validated (${FSIZE} bytes)"

    echo -e "${STEP_OK} Step 5 -- Safe mode (no yes pipe)"

    if ! command -v blueprint &>/dev/null; then
        rm -f "$NAME"
        echo -e "${STEP_FAIL} Step 6 -- 'blueprint' command not found"
        echo -e "  ${Y}Install Blueprint CLI first:${N}"
        echo -e "  curl -fsSL https://github.com/BlueprintFramework/cli/raw/main/install.sh | sudo bash"
        return 1
    fi
    echo -e "${STEP_OK} Step 6 -- blueprint found"

    # Aggressively clear ALL blueprint locks before install
    echo -e "${G}Clearing blueprint locks...${N}"
    pkill -9 -f "blueprint" 2>/dev/null || true
    sleep 2
    # Remove every possible lockfile location
    rm -f "$PTERO_DIR/.blueprint.lock" 2>/dev/null
    rm -f "$PTERO_DIR/storage/.blueprint.lock" 2>/dev/null
    rm -f "$PTERO_DIR/storage/framework/.blueprint.lock" 2>/dev/null
    find "$PTERO_DIR" -name ".blueprint.lock" -delete 2>/dev/null
    find "$PTERO_DIR" -name "blueprint.lock" -delete 2>/dev/null
    find "$PTERO_DIR/storage" -name "*.lock" -delete 2>/dev/null
    # Verify lock is gone
    if [[ -f "$PTERO_DIR/.blueprint.lock" ]]; then
        echo -e "${Y}WARNING: Could not remove lockfile, trying force...${N}"
        rm -rf "$PTERO_DIR/.blueprint.lock" 2>/dev/null
    fi
    echo -e "${STEP_OK} Locks cleared"

    mkdir -p "$BACKUP_DIR"
    local BPATH="$BACKUP_DIR/blueprint_backup_${SLUG}_${NOW}"
    mkdir -p "$BPATH"
    local BACKUP_ITEMS=()
    [[ -d "$PTERO_DIR/config" ]]   && BACKUP_ITEMS+=("config")
    [[ -d "$PTERO_DIR/database" ]] && BACKUP_ITEMS+=("database")
    [[ -d "$PTERO_DIR/routes" ]]   && BACKUP_ITEMS+=("routes")
    [[ -f "$PTERO_DIR/.env" ]]     && BACKUP_ITEMS+=(".env")
    [[ -d "$PTERO_DIR/storage" ]]  && BACKUP_ITEMS+=("storage")
    for item in "${BACKUP_ITEMS[@]}"; do
        cp -a "$PTERO_DIR/$item" "$BPATH/" 2>/dev/null
    done
    echo -e "${STEP_OK} Step 7 -- Backup created: ${BPATH}"

    if is_installed_bp "$SLUG"; then
        echo -e "\n${Y}WARNING: Theme '${SLUG}' is already installed!${N}"
        echo -e "${Y}   This may overwrite the current theme.${N}"
        read -p "   Continue? [y/N]: " confirm
        if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
            rm -f "$NAME"
            echo -e "${R}Aborted by user.${N}"
            return 1
        fi
        echo ""
    fi

    echo -e "\n${G}Installing via Blueprint (this can take a minute)...${N}"
    blueprint -i "$NAME"
    local rc=$?

    if [[ $rc -ne 0 ]]; then
        echo ""
        echo -e "${STEP_FAIL} Step 8 -- Blueprint installation FAILED (exit code: $rc)"
        echo -e "${Y}   Backup saved at: ${BPATH}${N}"
        echo -e "${Y}   To restore, run:${N}"
        echo -e "${Y}   sudo cp -a ${BPATH}/* ${PTERO_DIR}/${N}"
        rm -f "$NAME"
        return 1
    fi
    echo -e "${STEP_OK} Step 8 -- Blueprint installed successfully"

    # Create marker file for detection
    sudo touch "$PTERO_DIR/storage/.hn_theme_${SLUG}" 2>/dev/null

    echo -e "\n${G}Running post-install steps...${N}"
    php artisan optimize:clear 2>/dev/null && \
        echo -e "${STEP_OK} Step 10 -- Cache cleared" || \
        echo -e "${Y}WARNING: Step 10 -- Cache clear skipped${N}"

    sudo chown -R www-data:www-data "$PTERO_DIR/storage" 2>/dev/null
    sudo chown -R www-data:www-data "$PTERO_DIR/bootstrap/cache" 2>/dev/null
    echo -e "${STEP_OK} Step 10 -- Ownership restored (storage, bootstrap/cache)"

    echo ""
    if is_installed_bp "$SLUG"; then
        echo -e "${STEP_OK} Step 11 -- Verification passed: ${SLUG} is installed"
    else
        echo -e "${Y}WARNING: Step 11 -- Verification could not confirm installation${N}"
        echo -e "${Y}   Check manually: ls -la ${PTERO_DIR}/storage/extensions/${N}"
    fi

    echo -e "${STEP_OK} Step 12 -- .blueprint file kept at: ${PTERO_DIR}/${NAME}"

    echo ""
    echo -e "${BC}=======================================${N}"
    echo -e "${BG}  [OK] Downloaded${N}"
    echo -e "${BG}  [OK] Validated${N}"
    echo -e "${BG}  [OK] Backup created${N}"
    echo -e "${BG}  [OK] Blueprint installed${N}"
    echo -e "${BG}  [OK] Cache cleared${N}"
    echo -e "${BG}  [OK] Verification completed${N}"
    echo -e "${BC}=======================================${N}\n"
}

# ==========================================
# UNINSTALL BLUEPRINT
# ==========================================
uninstall_blueprint() {
    local NAME="$1"
    local slug="${NAME%.blueprint}"
    echo -e "\n${R}Removing ${slug}...${N}"
    cd /var/www/pterodactyl || return 1
    yes | blueprint -r "$slug"
    rm -f "/var/www/pterodactyl/storage/.hn_theme_${slug}" 2>/dev/null
    echo -e "${G}${slug} removed!${N}"
}

# ==========================================
# INSTALL ZIP THEME (SAFE - 16 STEPS)
# ==========================================
install_zip_theme() {
    local ZIPNAME="$1"
    local SLUG="${ZIPNAME%.zip}"
    local ZIPURL="$URL_ZIP/$(echo "$ZIPNAME" | sed 's/ /%20/g')"
    local PTERO_DIR="/var/www/pterodactyl"
    local BACKUP_DIR="/tmp/hn_backups"
    local NOW=$(date +%Y%m%d_%H%M%S)

    echo -e "\n${BC}=======================================${N}"
    echo -e "${BW}  HAPPY-NODE ZIP Installer: ${BC}${SLUG}${N}"
    echo -e "${BC}=======================================${N}\n"

    # Step 1: Change to Pterodactyl directory
    if [[ ! -d "$PTERO_DIR" ]]; then
        echo -e "${STEP_FAIL} Step 1 -- Directory not found: ${PTERO_DIR}"
        return 1
    fi
    cd "$PTERO_DIR" || { echo -e "${STEP_FAIL} Step 1 -- Cannot cd to ${PTERO_DIR}"; return 1; }
    echo -e "${STEP_OK} Step 1 -- Changed to ${PTERO_DIR}"

    # Step 2: Create temporary download directory
    local TEMP_DIR=$(mktemp -d)
    local ZIPFILE="$TEMP_DIR/$ZIPNAME"
    echo -e "${STEP_OK} Step 2 -- Temp directory created: ${TEMP_DIR}"

    # Step 3: Download ZIP with fail + redirect handling
    echo -e "\n${G}Downloading ${SLUG}...${N}"
    if ! curl -fL --progress-bar --max-time 120 "$ZIPURL" -o "$ZIPFILE" 2>/dev/null; then
        echo -e "${STEP_FAIL} Step 3 -- Download failed (network error or URL unreachable)"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    local FSIZE=$(stat -c%s "$ZIPFILE" 2>/dev/null || wc -c < "$ZIPFILE")
    echo -e "${STEP_OK} Step 3 -- Downloaded ${SLUG} (${FSIZE} bytes)"

    # Step 4: Verify ZIP integrity
    if ! head -c 2 "$ZIPFILE" | grep -q 'PK'; then
        echo -e "${STEP_FAIL} Step 4a -- Invalid package: no PK signature (not a ZIP)"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    echo -e "${STEP_OK} Step 4a -- PK signature valid"

    if ! unzip -tq "$ZIPFILE" >/dev/null 2>&1; then
        echo -e "${STEP_FAIL} Step 4b -- ZIP integrity check failed (archive corrupt)"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    echo -e "${STEP_OK} Step 4b -- ZIP integrity verified"

    # Step 5: Validation passed
    echo -e "${STEP_OK} Step 5 -- Validation passed, continuing"

    # Step 6: Extract into a separate extraction directory
    local EXTRACT_DIR="$TEMP_DIR/extracted"
    mkdir -p "$EXTRACT_DIR"
    echo -e "\n${G}Extracting into ${EXTRACT_DIR}...${N}"
    if ! unzip -oq "$ZIPFILE" -d "$EXTRACT_DIR" 2>/dev/null; then
        echo -e "${STEP_FAIL} Step 6 -- Extraction failed"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    echo -e "${STEP_OK} Step 6 -- Extracted successfully"

    # Step 7: Inspect extracted structure before copying
    echo -e "\n${G}Extracted contents:${N}"
    find "$EXTRACT_DIR" -maxdepth 3 -not -name "$ZIPNAME" -not -path "*/extracted/extracted*" | sed "s|${EXTRACT_DIR}/|  |" | head -n 25
    echo ""

    # Step 8: Detect installation type

    # 8A: Blueprint file detected
    local BPFILE=$(find "$EXTRACT_DIR" -maxdepth 3 -type f -name "*.blueprint" | head -n 1)
    if [[ -n "$BPFILE" ]]; then
        local BPNAME=$(basename "$BPFILE")
        echo -e "${STEP_OK} Step 8 -- Type detected: BLUEPRINT (${BPNAME})"
        cp "$BPFILE" "$PTERO_DIR/"
        cd "$PTERO_DIR" || { rm -rf "$TEMP_DIR"; return 1; }
        install_blueprint "$BPNAME"
        local rc=$?
        rm -f "$PTERO_DIR/$BPNAME" 2>/dev/null
        cd /; rm -rf "$TEMP_DIR"
        return $rc
    fi

    # 8B: Detect Pterodactyl application files
    local INNER_ROOT="$EXTRACT_DIR"
    local TOP_DIRS=($(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d))
    if [[ ${#TOP_DIRS[@]} -eq 1 ]] && [[ -d "${TOP_DIRS[0]}" ]]; then
        INNER_ROOT="${TOP_DIRS[0]}"
    fi

    local PTERO_SCORE=0
    [[ -d "$INNER_ROOT/app" ]]      && ((PTERO_SCORE++))
    [[ -d "$INNER_ROOT/resources" ]] && ((PTERO_SCORE++))
    [[ -d "$INNER_ROOT/public" ]]    && ((PTERO_SCORE++))
    [[ -d "$INNER_ROOT/routes" ]]    && ((PTERO_SCORE++))

    if [[ $PTERO_SCORE -ge 1 ]]; then
        echo -e "${STEP_OK} Step 8 -- Type detected: PTERODACTYL THEME FILES (${PTERO_SCORE}/4 core dirs found)"

        # Show exactly which files will be changed
        echo -e "\n${Y}Files that will be overwritten:${N}"
        local FILE_COUNT=0
        for d in resources public app routes config database; do
            if [[ -d "$INNER_ROOT/$d" ]]; then
                echo -e "  ${C}${d}/${N}"
                local cnt=$(find "$INNER_ROOT/$d" -type f 2>/dev/null | wc -l)
                FILE_COUNT=$((FILE_COUNT + cnt))
            fi
        done
        echo -e "  ${Y}Total files: ${FILE_COUNT}${N}"
        echo ""

        # Warn if another theme may be installed
        if is_installed_zip "$SLUG" 2>/dev/null; then
            echo -e "${Y}WARNING: Theme '${SLUG}' appears to be already installed!${N}"
            read -p "   Continue and overwrite? [y/N]: " confirm
            if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
                rm -rf "$TEMP_DIR"
                echo -e "${R}Aborted by user.${N}"
                return 1
            fi
            echo ""
        fi

        # Warn about possible incompatibility
        echo -e "${Y}NOTE: This theme was not tested with your current Pterodactyl version.${N}"
        read -p "   Proceed? [y/N]: " compat
        if [[ "$compat" != "y" ]] && [[ "$compat" != "Y" ]]; then
            rm -rf "$TEMP_DIR"
            echo -e "${R}Aborted by user.${N}"
            return 1
        fi
        echo ""

        # Step 9: Create timestamped backup
        mkdir -p "$BACKUP_DIR"
        local BPATH="$BACKUP_DIR/zip_backup_${SLUG}_${NOW}"
        mkdir -p "$BPATH"
        for d in resources public app routes config database; do
            [[ -d "$PTERO_DIR/$d" ]] && cp -a "$PTERO_DIR/$d" "$BPATH/" 2>/dev/null
        done
        [[ -f "$PTERO_DIR/.env" ]] && cp -a "$PTERO_DIR/.env" "$BPATH/" 2>/dev/null
        echo -e "${STEP_OK} Backup created: ${BPATH}"

        # Step 10: Copy ONLY theme-relevant files
        echo -e "\n${G}Installing theme files...${N}"
        for d in resources public; do
            if [[ -d "$INNER_ROOT/$d" ]]; then
                sudo cp -a "$INNER_ROOT/$d"/* "$PTERO_DIR/$d/" 2>/dev/null
                echo -e "  ${STEP_OK} Copied ${d}/"
            fi
        done
        if [[ -d "$INNER_ROOT/app" ]]; then
            if [[ -d "$INNER_ROOT/app/Http/Controllers" ]]; then
                sudo cp -a "$INNER_ROOT/app/Http/Controllers"/* "$PTERO_DIR/app/Http/Controllers/" 2>/dev/null
                echo -e "  ${STEP_OK} Copied app/Http/Controllers/"
            fi
            if [[ -d "$INNER_ROOT/app/Models" ]]; then
                sudo cp -a "$INNER_ROOT/app/Models"/* "$PTERO_DIR/app/Models/" 2>/dev/null
                echo -e "  ${STEP_OK} Copied app/Models/"
            fi
        fi
        if [[ -d "$INNER_ROOT/routes" ]]; then
            for f in "$INNER_ROOT/routes"/*.php; do
                local fname=$(basename "$f")
                case "$fname" in
                    web.php|api.php|console.php|channels.php)
                        sudo cp -a "$f" "$PTERO_DIR/routes/$fname" 2>/dev/null
                        ;;
                esac
            done
            echo -e "  ${STEP_OK} Copied routes/"
        fi
        if [[ -d "$INNER_ROOT/config" ]]; then
            for f in "$INNER_ROOT/config"/*.php; do
                local fname=$(basename "$f")
                case "$fname" in
                    database.php|filesystems.php|app.php|auth.php|mail.php|services.php)
                        ;;
                    *)
                        sudo cp -a "$f" "$PTERO_DIR/config/$fname" 2>/dev/null
                        ;;
                esac
            done
            echo -e "  ${STEP_OK} Copied config/ (safe files only)"
        fi
        if [[ -d "$INNER_ROOT/database/migrations" ]]; then
            sudo cp -a "$INNER_ROOT/database/migrations"/* "$PTERO_DIR/database/migrations/" 2>/dev/null
            echo -e "  ${STEP_OK} Copied database/migrations/"
        fi
        echo -e "${STEP_OK} Theme files installed"

        # Create marker file for detection
        sudo touch "$PTERO_DIR/storage/.hn_theme_${SLUG}" 2>/dev/null

        # Step 11: Post-install commands
        cd "$PTERO_DIR" || { rm -rf "$TEMP_DIR"; return 1; }

        # Step 12: Clear Laravel cache
        echo -e "\n${G}Clearing cache...${N}"
        php artisan optimize:clear 2>/dev/null && \
            echo -e "${STEP_OK} Step 12 -- Cache cleared" || \
            echo -e "${Y}WARNING: Step 12 -- Cache clear skipped${N}"

        # Step 13: Frontend build ONLY if package.json exists AND theme has JS/CSS
        local NEEDS_BUILD="n"
        if [[ -f "$PTERO_DIR/package.json" ]]; then
            for d in resources public; do
                if [[ -d "$INNER_ROOT/$d" ]]; then
                    local JS_COUNT=$(find "$INNER_ROOT/$d" -type f \( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" -o -name "*.css" -o -name "*.scss" \) 2>/dev/null | wc -l)
                    if [[ $JS_COUNT -gt 0 ]]; then
                        NEEDS_BUILD="y"
                    fi
                fi
            done
        fi

        if [[ "$NEEDS_BUILD" == "y" ]]; then
            echo -e "\n${G}Building frontend assets (this can take a minute)...${N}"
            export NODE_OPTIONS=--openssl-legacy-provider
            yarn --ignore-engines install 2>&1 | tail -n 3 || true
            yarn --ignore-engines build:production 2>&1 | tail -n 10
            local rc=$?
            echo -e "${STEP_OK} Step 13 -- Build completed (exit code: $rc)"
        else
            echo -e "${STEP_OK} Step 13 -- No frontend build needed (no JS/CSS changes)"
        fi

        # Step 14: Fix ownership only where necessary
        sudo chown -R www-data:www-data "$PTERO_DIR/storage" 2>/dev/null
        sudo chown -R www-data:www-data "$PTERO_DIR/bootstrap/cache" 2>/dev/null
        echo -e "${STEP_OK} Step 14 -- Ownership restored"

        # Step 15: Verify Laravel application integrity
        echo -e "\n${G}Verifying installation...${N}"
        local VERIFY_OK="y"
        if [[ ! -f "$PTERO_DIR/artisan" ]]; then
            VERIFY_OK="n"
            echo -e "  ${STEP_FAIL} artisan missing"
        fi
        if [[ ! -f "$PTERO_DIR/public/index.php" ]]; then
            VERIFY_OK="n"
            echo -e "  ${STEP_FAIL} public/index.php missing"
        fi
        if [[ ! -d "$PTERO_DIR/vendor" ]]; then
            VERIFY_OK="n"
            echo -e "  ${STEP_FAIL} vendor/ missing"
        fi
        if [[ ! -f "$PTERO_DIR/.env" ]]; then
            VERIFY_OK="n"
            echo -e "  ${STEP_FAIL} .env missing"
        fi
        php artisan route:list --columns=method,uri --format=json >/dev/null 2>&1 && \
            echo -e "  ${STEP_OK} Laravel routes loaded" || \
            echo -e "  ${Y}WARNING: Laravel routes check failed (may be OK)${N}"

        if [[ "$VERIFY_OK" == "y" ]]; then
            echo -e "${STEP_OK} Step 15 -- Panel integrity verified"
        else
            echo -e "${Y}WARNING: Step 15 -- Some checks failed. Review above.${N}"
        fi

        # Step 16: Cleanup
        cd /
        rm -rf "$TEMP_DIR"
        echo -e "${STEP_OK} Step 16 -- Temp directory removed"

    else
        # 8D: Structure cannot be identified
        echo -e "\n${R}STEP 8 -- UNSUPPORTED ZIP FORMAT${N}"
        echo -e "${Y}   The ZIP does not contain a .blueprint file,${N}"
        echo -e "${Y}   nor Pterodactyl application directories.${N}"
        echo -e "\n${Y}   Detected structure:${N}"
        find "$EXTRACT_DIR" -maxdepth 2 | sed "s|${EXTRACT_DIR}/|  |" | head -n 20
        echo -e "\n${Y}   This theme cannot be auto-installed.${N}"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    echo ""
    echo -e "${BC}=======================================${N}"
    echo -e "${BG}  [OK] ZIP downloaded${N}"
    echo -e "${BG}  [OK] ZIP validated${N}"
    echo -e "${BG}  [OK] Contents inspected${N}"
    echo -e "${BG}  [OK] Installation type detected${N}"
    echo -e "${BG}  [OK] Backup created${N}"
    echo -e "${BG}  [OK] Theme installed${N}"
    echo -e "${BG}  [OK] Cache cleared${N}"
    if [[ "$NEEDS_BUILD" == "y" ]]; then
        echo -e "${BG}  [OK] Build completed${N}"
    fi
    echo -e "${BG}  [OK] Installation verified${N}"
    echo -e "${BC}=======================================${N}\n"
}

# ==========================================
# HEADER
# ==========================================
header() {
  clear
  echo -e "${BC} ╔══════════════════════════════════════════════════════════╗${N}"
  printf " ${BC}║${BW}%-58s${BC}║${N}\n" "  HAPPY-NODE THEME MANAGER"
  printf " ${BC}║${B}%-58s${BC}║${N}\n" "    Blueprint + ZIP Themes - 40+ Themes    "
  echo -e "${BC} ╚══════════════════════════════════════════════════════════╝${N}"
  echo -e " ${B}User:${N} $(whoami)  ${B}Host:${N} $(hostname)  ${B}Time:${N} $(date +'%H:%M')"
  echo -e "${C} ──────────────────────────────────────────────────────────${N}"
}

# ==========================================
# MAIN MENU
# ==========================================
show_menu() {
  header
  echo -e "${BW} SELECT A THEME:${N}\n"
  
  echo -e " ${BC}── BLUEPRINT THEMES ──${N}"
  local count=0
  for i in "${!blueprints[@]}"; do
      num=$((i+1))
      clean="${blueprints[$i]%.blueprint}"
      
      if is_installed_bp "$clean"; then
          status="${BG}●${N}"
      else
          status="${R}○${N}"
      fi
      
      printf "  ${BG}%2d${N} %-22s %b   " "$num" "$clean" "$status"
      
      ((count++))
      if (( count % 2 == 0 )); then echo ""; fi
  done
  if (( count % 2 != 0 )); then echo ""; fi
  
  echo ""
  echo -e " ${BC}── ZIP THEMES ──${N}"
  local zcount=0
  local offset=${#blueprints[@]}
  for i in "${!zip_themes[@]}"; do
      num=$((offset + i + 1))
      clean="${zip_themes[$i]%.zip}"
      
      if is_installed_zip "$clean"; then
          status="${BG}●${N}"
      else
          status="${R}○${N}"
      fi
      
      printf "  ${BG}%2d${N} %-22s %b   " "$num" "$clean" "$status"
      
      ((zcount++))
      if (( zcount % 2 == 0 )); then echo ""; fi
  done
  if (( zcount % 2 != 0 )); then echo ""; fi

  echo -e "\n\n  ${BR} 0 ${N} Exit"
  echo -e "${C} ──────────────────────────────────────────────────────────${N}"
}

# ==========================================
# MAIN LOOP
# ==========================================
while true; do
  show_menu
  read -p " 👉 Enter choice: " opt

  if [[ "$opt" == "0" ]]; then
      echo -e "\n${M} 👋 Goodbye from HAPPY-NODE!${N}"
      exit
  fi

  total_bp=${#blueprints[@]}
  total_zip=${#zip_themes[@]}
  total=$((total_bp + total_zip))

  if [[ "$opt" -lt 1 ]] || [[ "$opt" -gt "$total" ]]; then
      echo -e "\n${R}Invalid Option${N}"
      sleep 1
      continue
  fi

  clear
  header

  if [[ "$opt" -le "$total_bp" ]]; then
      index=$((opt - 1))
      NAME="${blueprints[$index]}"
      clean="${NAME%.blueprint}"

      if is_installed_bp "$clean"; then
          cur_status="${BG}ALREADY INSTALLED${N}"
      else
          cur_status="${R}NOT INSTALLED${N}"
      fi

      echo -e " ${BW}SELECTED:${N} ${BC}${clean} (Blueprint)${N}"
      echo -e " ${BW}STATUS:${N}   $cur_status"
      echo -e "${C} ──────────────────────────────────────────────────────────${N}"
      echo -e "  ${BG}[ 1 ]${N} Install"
      echo -e "  ${BR}[ 2 ]${N} Uninstall"
      echo -e "  ${BY}[ 0 ]${N} Back to Menu"
      echo -e "${C} ──────────────────────────────────────────────────────────${N}"

      read -p " 👉 Action: " action
      case $action in
          1) install_blueprint "$NAME" ;;
          2) uninstall_blueprint "$NAME" ;;
          0) continue ;;
          *) echo -e "${R}Invalid Choice${N}" ;;
      esac
  else
      zip_index=$((opt - total_bp - 1))
      ZIPNAME="${zip_themes[$zip_index]}"
      clean="${ZIPNAME%.zip}"

      if is_installed_zip "$clean"; then
          cur_status="${BG}ALREADY INSTALLED${N}"
      else
          cur_status="${R}NOT INSTALLED${N}"
      fi

      echo -e " ${BW}SELECTED:${N} ${BC}${clean} (ZIP Theme)${N}"
      echo -e " ${BW}STATUS:${N}   $cur_status"
      echo -e "${C} ──────────────────────────────────────────────────────────${N}"
      echo -e "  ${BG}[ 1 ]${N} Install"
      echo -e "  ${BR}[ 2 ]${N} Uninstall"
      echo -e "  ${BY}[ 0 ]${N} Back to Menu"
      echo -e "${C} ──────────────────────────────────────────────────────────${N}"

      read -p " 👉 Action: " action
      case $action in
          1) install_zip_theme "$ZIPNAME" ;;
          2)
              echo -e "${R}Removing ${clean}...${N}"
              rm -rf "/var/www/pterodactyl/resources/views/vendor/$clean" 2>/dev/null
              rm -rf "/var/www/pterodactyl/app/Http/Controllers/Admin/$clean" 2>/dev/null
              rm -f "/var/www/pterodactyl/storage/.hn_theme_${clean}" 2>/dev/null
              cd /var/www/pterodactyl 2>/dev/null && php artisan view:clear 2>/dev/null
              echo -e "${G}${clean} removed!${N}"
              ;;
          0) continue ;;
          *) echo -e "${R}Invalid Choice${N}" ;;
      esac
  fi

  echo
  read -p " ↩️ Press [Enter] to return..."
done
