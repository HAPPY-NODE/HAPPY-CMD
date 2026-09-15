#!/bin/bash

# ==========================================
# HAPPY-NODE THEME MANAGER v2.0
# Shows all themes with type labels
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
URL_ARIX="$_HN_BASE/thame/arix"
URL_ARIX_FALLBACK="https://raw.githubusercontent.com/sdgamer8263-sketch/pterodactyl_extention1/main/sd"

trap 'echo -e "\n${R}[!] Force exit detected.${N}"; exit 1' SIGINT

STEP_OK="[${G}OK${N}]"
STEP_FAIL="[${R}FAIL${N}]"
STEP_FIX="[${Y}FIX${N}]"

# ==========================================
# ALL THEMES DATABASE
# Format: "Name|Type|Payload"
# Types: bp (Blueprint), zip (ZIP), arix (Arix Version)
# ==========================================
ALL_THEMES=(
  # === BLUEPRINT THEMES [BP] ===
  "Nebula|bp|nebula.blueprint"
  "Euphoria|bp|euphoriatheme.blueprint"
  "BetterAdmin|bp|BetterAdmin.blueprint"
  "Abyss Purple|bp|abysspurple.blueprint"
  "Abyss Amber|bp|amberabyss.blueprint"
  "Catppuccindactyl|bp|catppuccindactyl.blueprint"
  "Abyss Crimson|bp|crimsonabyss.blueprint"
  "Abyss Emerald|bp|emeraldabyss.blueprint"
  "NightAdmin|bp|nightadmin.blueprint"
  "Refresh|bp|refreshtheme.blueprint"
  "Slice|bp|slice.blueprint"
  "Darkenate|bp|darkenate.blueprint"
  "Recolor|bp|recolor.blueprint"
  "BlueTables|bp|bluetables.blueprint"
  "UltraDarkAdmin|bp|ultradarkadmin.blueprint"
  "Xlpanel|bp|xlpaneltheme.blueprint"
  "Lemem|bp|lememtheme.blueprint"
  "Slate|bp|slate.blueprint"
  "KaelixPrime|bp|kaelixprime.blueprint"
  "M3dactyl|bp|m3dactyl.blueprint"
  "Catppuccin V1|bp|catppuccindactyl1.blueprint"
  "Catppuccin V2|bp|catppuccindactyl2.blueprint"
  "Lu Theme|bp|lutheme.blueprint"
  "Navy Seals Slice|bp|Navy.seals.slice.blueprint"
  "Navy Seals|bp|navyseals.blueprint"
  "Nebula V1.8|bp|nebula1.8.blueprint"
  "Nebula V2.0|bp|nebula2.0.blueprint"
  "Tailwind Palette|bp|tailwindfourpalette.blueprint"
  "Xlpanel V2.0|bp|xlpaneltheme2.0.blueprint"
  
  # === ZIP THEMES [ZIP] ===
  "Billing|zip|billing.zip"
  "Stellar|zip|stellar.zip"
  "Unix|zip|unix.zip"
  "Carbon Theme|zip|Carbon Theme.zip"
  "Elysium|zip|elysium.zip"
  "Enigma|zip|enigma.zip"
  "Nightcore|zip|nightcore.zip"
  "IceMinecraft|zip|iceMinecraft.zip"
  "Nookure|zip|nookure.zip"
  "NoraTheme|zip|NoraTheme.zip"
  "Astro Theme|zip|astro theme.zip"
  
  # === ARIX VERSIONS [ARIX] ===
  "Arix v2.1.0 (Latest)|arix|v2.1.0|v210"
  "Arix v2.0.8|arix|v2.0.8|v208"
  "Arix v1.3.1|arix|v1.3.1|v131"
  "Arix AV1|arix|av1|av1"
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
    [[ -f "$PTERO/storage/.hn_theme_${name}" ]] || \
    [[ -d "$PTERO/resources/views/vendor/$name" ]]
}

is_installed_arix() {
    local PTERO="/var/www/pterodactyl"
    [[ -d "$PTERO/arix" ]] || \
    [[ -f "$PTERO/app/Console/Commands/Arix.php" ]]
}

# ==========================================
# HEADER
# ==========================================
header() {
  clear
  echo -e "${BC} ╔══════════════════════════════════════════════════════════╗${N}"
  printf " ${BC}║${BW}%-58s${BC}║${N}\n" "  HAPPY-NODE THEME MANAGER v2.0"
  printf " ${BC}║${B}%-58s${BC}║${N}\n" "    Blueprint + ZIP + Arix - All Themes    "
  echo -e "${BC} ╚══════════════════════════════════════════════════════════╝${N}"
  echo -e " ${B}User:${N} $(whoami)  ${B}Host:${N} $(hostname)  ${B}Time:${N} $(date +'%H:%M')"
  echo -e "${C} ──────────────────────────────────────────────────────────${N}"
}

# ==========================================
# SHOW ALL THEMES
# ==========================================
show_themes() {
  header
  echo -e "${BW} ALL THEMES:${N}\n"
  
  local count=0
  for i in "${!ALL_THEMES[@]}"; do
    num=$((i+1))
    IFS='|' read -r t_name t_type t_payload <<< "${ALL_THEMES[$i]}"
    
    # Determine status and label
    case "$t_type" in
      bp)
        slug="${t_payload%.blueprint}"
        if is_installed_bp "$slug"; then
            status="${BG}INSTALLED${N}"
        else
            status="${R}NOT INSTALLED${N}"
        fi
        label="${C}[BP]${N}"
        ;;
      zip)
        clean="${t_payload%.zip}"
        if is_installed_zip "$clean"; then
            status="${BG}INSTALLED${N}"
        else
            status="${R}NOT INSTALLED${N}"
        fi
        label="${M}[ZIP]${N}"
        ;;
      arix)
        slug="${SEL_PAYLOAD}"
        if is_installed_arix; then
            status="${BG}INSTALLED${N}"
        else
            status="${R}NOT INSTALLED${N}"
        fi
        label="${Y}[ARIX]${N}"
        ;;
    esac
    
    # Show version for Arix
    local extra=""
    if [[ "$t_type" == "arix" ]]; then
        extra=" (${t_payload})"
    fi
    
    printf "  ${BG}%2d${N} %-20s %b %-8b %b %s\n" "$num" "$t_name" "$label" "" "$status" "$extra"
    
    ((count++))
  done

  echo -e "\n\n  ${BR} 0 ${N} Exit"
  echo -e "${C} ──────────────────────────────────────────────────────────${N}"
}

# ==========================================
# INSTALL BLUEPRINT THEME
# ==========================================
install_blueprint() {
    local NAME="$1"
    local SLUG="${NAME%.blueprint}"
    local PTERO_DIR="/var/www/pterodactyl"
    local BPURL="$URL_BP/$(echo "$NAME" | sed 's/ /%20/g')"

    echo -e "\n${BC}=======================================${N}"
    echo -e "${BW}  Installing Blueprint: ${BC}${SLUG}${N}"
    echo -e "${BC}=======================================${N}\n"

    if [[ ! -d "$PTERO_DIR" ]]; then
        echo -e "${STEP_FAIL} Pterodactyl not found at ${PTERO_DIR}"
        return 1
    fi
    cd "$PTERO_DIR" || return 1

    # Clear locks
    echo -e "${G}Clearing locks...${N}"
    pkill -9 -f "blueprint" 2>/dev/null || true
    sleep 2
    rm -f "$PTERO_DIR/.blueprint/lock" 2>/dev/null
    rm -f "$PTERO_DIR/.blueprint.lock" 2>/dev/null
    blueprint -unlock 2>/dev/null || true

    # Download
    echo -e "${G}Downloading ${SLUG}...${N}"
    rm -f "$NAME"
    if ! curl -fL --progress-bar "$BPURL" -o "$NAME" 2>/dev/null; then
        rm -f "$NAME"
        echo -e "${STEP_FAIL} Download failed"
        return 1
    fi

    # Verify
    if head -c 15 "$NAME" 2>/dev/null | grep -qi "<!DOCTYPE\|<html"; then
        rm -f "$NAME"
        echo -e "${STEP_FAIL} Server returned HTML, not a blueprint"
        return 1
    fi

    # Install
    echo -e "${G}Installing via Blueprint...${N}"
    if ! command -v blueprint &>/dev/null; then
        rm -f "$NAME"
        echo -e "${STEP_FAIL} 'blueprint' command not found"
        return 1
    fi
    
    blueprint -i "$NAME"
    local rc=$?
    rm -f "$NAME"

    if [[ $rc -ne 0 ]]; then
        echo -e "${STEP_FAIL} Blueprint installation failed (exit: $rc)"
        return 1
    fi

    # Marker
    sudo touch "$PTERO_DIR/storage/.hn_theme_${SLUG}" 2>/dev/null

    # Post-install
    php artisan optimize:clear 2>/dev/null
    sudo chown -R www-data:www-data "$PTERO_DIR/storage" 2>/dev/null
    sudo chown -R www-data:www-data "$PTERO_DIR/bootstrap/cache" 2>/dev/null

    echo -e "${STEP_OK} ${SLUG} installed successfully!"
}

# ==========================================
# INSTALL ZIP THEME
# ==========================================
install_zip() {
    local ZIPNAME="$1"
    local SLUG="${ZIPNAME%.zip}"
    local ZIPURL="$URL_ZIP/$(echo "$ZIPNAME" | sed 's/ /%20/g')"
    local PTERO_DIR="/var/www/pterodactyl"

    echo -e "\n${BC}=======================================${N}"
    echo -e "${BW}  Installing ZIP Theme: ${BC}${SLUG}${N}"
    echo -e "${BC}=======================================${N}\n"

    if [[ ! -d "$PTERO_DIR" ]]; then
        echo -e "${STEP_FAIL} Pterodactyl not found"
        return 1
    fi

    local TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    # Download
    echo -e "${G}Downloading ${SLUG}...${N}"
    if ! curl -fL --progress-bar --max-time 120 "$ZIPURL" -o "download.zip" 2>/dev/null; then
        echo -e "${STEP_FAIL} Download failed"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Verify
    if ! head -c 2 "download.zip" | grep -q 'PK'; then
        echo -e "${STEP_FAIL} Not a valid ZIP file"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Extract
    echo -e "${G}Extracting...${N}"
    local EXTRACT_DIR="$TEMP_DIR/extracted"
    mkdir -p "$EXTRACT_DIR"
    if ! unzip -oq "download.zip" -d "$EXTRACT_DIR" 2>/dev/null; then
        echo -e "${STEP_FAIL} Extraction failed"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Find pterodactyl folder
    local INNER_ROOT="$EXTRACT_DIR"
    if [[ -d "$EXTRACT_DIR/pterodactyl" ]]; then
        INNER_ROOT="$EXTRACT_DIR/pterodactyl"
    elif [[ -d "$EXTRACT_DIR/resources" ]] || [[ -d "$EXTRACT_DIR/public" ]]; then
        INNER_ROOT="$EXTRACT_DIR"
    else
        local TOP_DIRS=($(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d))
        if [[ ${#TOP_DIRS[@]} -eq 1 ]] && [[ -d "${TOP_DIRS[0]}" ]]; then
            INNER_ROOT="${TOP_DIRS[0]}"
        fi
    fi

    # Copy files
    echo -e "${G}Installing theme files...${N}"
    cd "$PTERO_DIR"
    
    for d in resources public; do
        if [[ -d "$INNER_ROOT/$d" ]]; then
            sudo cp -a "$INNER_ROOT/$d"/* "$PTERO_DIR/$d/" 2>/dev/null
            echo -e "  ${STEP_OK} Copied ${d}/"
        fi
    done

    # Build
    export NODE_OPTIONS=--openssl-legacy-provider
    yarn --ignore-engines install 2>&1 | tail -n 3 || true
    yarn --ignore-engines build:production 2>&1 | tail -n 5

    # Clear cache
    php artisan optimize:clear 2>/dev/null
    sudo chown -R www-data:www-data "$PTERO_DIR/storage" 2>/dev/null
    sudo chown -R www-data:www-data "$PTERO_DIR/bootstrap/cache" 2>/dev/null

    # Marker
    sudo touch "$PTERO_DIR/storage/.hn_theme_${SLUG}" 2>/dev/null

    cd /
    rm -rf "$TEMP_DIR"

    echo -e "${STEP_OK} ${SLUG} installed successfully!"
}

# ==========================================
# INSTALL ARIX THEME
# ==========================================
install_arix() {
    local VERSION="$1"
    local DIR="$2"
    local PTERO_DIR="/var/www/pterodactyl"
    local TEMP_DIR=$(mktemp -d)

    echo -e "\n${BC}=======================================${N}"
    echo -e "${BW}  Installing Arix: ${BC}${VERSION}${N}"
    echo -e "${BC}=======================================${N}\n"

    if [[ ! -d "$PTERO_DIR" ]]; then
        echo -e "${STEP_FAIL} Pterodactyl not found"
        return 1
    fi
    cd "$PTERO_DIR"

    # Dependencies
    echo -e "${G}Installing dependencies...${N}"
    apt-get update -y >/dev/null 2>&1
    apt-get install -y unzip curl wget >/dev/null 2>&1

    # Download from our repo (with fallback)
    echo -e "${G}Downloading Arix ${VERSION} from HAPPY-NODE repo...${N}"
    local ARIX_URL="$URL_ARIX/$DIR/pterodactyl.zip"
    if ! curl -fL --progress-bar --max-time 180 "$ARIX_URL" -o "$TEMP_DIR/pterodactyl.zip" 2>/dev/null; then
        echo -e "${Y}Trying fallback source...${N}"
        local FALLBACK="$URL_ARIX_FALLBACK/$DIR/pterodactyl.zip"
        if ! curl -fL --progress-bar --max-time 180 "$FALLBACK" -o "$TEMP_DIR/pterodactyl.zip" 2>/dev/null; then
            echo -e "${STEP_FAIL} Download failed from all sources"
            rm -rf "$TEMP_DIR"
            return 1
        fi
    fi
    local FSIZE=$(du -sh "$TEMP_DIR/pterodactyl.zip" | cut -f1)
    echo -e "  ${STEP_OK} Downloaded (${FSIZE})"

    # Verify ZIP
    if ! head -c 2 "$TEMP_DIR/pterodactyl.zip" | grep -q 'PK'; then
        echo -e "${STEP_FAIL} Not a valid ZIP file"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Extract
    echo -e "${G}Extracting...${N}"
    if ! unzip -oq "$TEMP_DIR/pterodactyl.zip" -d "$TEMP_DIR/extracted" > /dev/null 2>&1; then
        echo -e "${STEP_FAIL} Extraction failed"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    local INNER="$TEMP_DIR/extracted"
    if [[ -d "$TEMP_DIR/extracted/pterodactyl" ]]; then
        INNER="$TEMP_DIR/extracted/pterodactyl"
    fi

    # Security scan - remove backdoor files
    echo -e "${G}Security scan...${N}"
    local SCANNED=0
    for badfile in \
        "$INNER/app/Console/Commands/Arix.php" \
        "$INNER/arix/ins/ins.php" \
        "$INNER/arix/up/up.php"; do
        if [[ -f "$badfile" ]]; then
            rm -f "$badfile"
            echo -e "  ${STEP_FIX} Removed: $(basename "$badfile")"
            ((SCANNED++))
        fi
    done
    [[ $SCANNED -eq 0 ]] && echo -e "  ${STEP_OK} Clean"

    # Copy files (safe copy)
    echo -e "${G}Installing theme files...${N}"
    for d in resources public app routes config database; do
        if [[ -d "$INNER/$d" ]]; then
            cp -rf "$INNER/$d"/* "$PTERO_DIR/$d/" 2>/dev/null
            echo -e "  ${STEP_OK} ${d}/"
        fi
    done
    [[ -d "$INNER/arix" ]] && cp -rf "$INNER/arix" "$PTERO_DIR/" 2>/dev/null && echo -e "  ${STEP_OK} arix/"
    [[ -d "$INNER/bootstrap" ]] && cp -rf "$INNER/bootstrap"/* "$PTERO_DIR/bootstrap/" 2>/dev/null && echo -e "  ${STEP_OK} bootstrap/"

    # Node.js
    echo -e "${G}Checking Node.js...${N}"
    local NODE_VER=$(node -v 2>/dev/null | cut -d'.' -f1 | sed 's/v//')
    if [[ "$NODE_VER" != "22" ]]; then
        echo -e "${Y}Installing Node.js 22...${N}"
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null 2>&1
        apt-get install -y nodejs > /dev/null 2>&1
    fi

    # Yarn + Build
    if ! command -v yarn &>/dev/null; then
        npm install -g yarn > /dev/null 2>&1
    fi
    echo -e "${G}Building panel...${N}"
    export NODE_OPTIONS=--openssl-legacy-provider
    yarn add xterm-addon-unicode11 > /dev/null 2>&1 || true
    yarn install > /dev/null 2>&1 || true
    yarn build:production > /dev/null 2>&1 || true

    # Error fixing
    echo -e "${G}Fixing errors...${N}"
    cd "$PTERO_DIR"
    php artisan migrate --force 2>/dev/null || true
    php artisan storage:link --force 2>/dev/null || true
    php artisan config:cache 2>/dev/null || true
    php artisan view:cache 2>/dev/null || true
    php artisan event:cache 2>/dev/null || true
    php artisan queue:restart 2>/dev/null || true

    # Permissions
    echo -e "${G}Fixing permissions...${N}"
    chown -R www-data:www-data "$PTERO_DIR" 2>/dev/null
    chmod -R 755 storage/* bootstrap/cache/ 2>/dev/null

    # Clear cache
    php artisan view:clear 2>/dev/null
    php artisan optimize:clear 2>/dev/null

    # Cleanup
    rm -rf "$TEMP_DIR"

    echo -e "${STEP_OK} Arix ${VERSION} installed successfully!"
}

# ==========================================
# UNINSTALL
# ==========================================
uninstall_theme() {
    local NAME="$1"
    local TYPE="$2"
    local PTERO_DIR="/var/www/pterodactyl"

    echo -e "\n${R}Uninstalling ${NAME}...${N}"

    case "$TYPE" in
      bp)
        local slug="${NAME%.blueprint}"
        cd "$PTERO_DIR" 2>/dev/null || return 1
        yes | blueprint -r "$slug" 2>/dev/null
        rm -f "$PTERO_DIR/storage/.hn_theme_${slug}" 2>/dev/null
        ;;
      zip)
        local clean="${NAME%.zip}"
        rm -rf "$PTERO_DIR/resources/views/vendor/$clean" 2>/dev/null
        rm -f "$PTERO_DIR/storage/.hn_theme_${clean}" 2>/dev/null
        cd "$PTERO_DIR" 2>/dev/null && php artisan view:clear 2>/dev/null
        ;;
      arix)
        cd "$PTERO_DIR" 2>/dev/null || return 1
        php artisan arix uninstall 2>/dev/null || true
        rm -rf arix/ 2>/dev/null
        rm -f app/Console/Commands/Arix.php 2>/dev/null
        ;;
    esac

    php artisan optimize:clear 2>/dev/null
    echo -e "${BG}${NAME} uninstalled!${N}"
}

# ==========================================
# MAIN LOOP
# ==========================================
while true; do
  show_themes
  read -p " Enter choice (0 to exit): " opt

  if [[ "$opt" == "0" ]]; then
      echo -e "\n${M} Goodbye from HAPPY-NODE!${N}"
      exit
  fi

  if [[ "$opt" -lt 1 ]] || [[ "$opt" -gt "${#ALL_THEMES[@]}" ]]; then
      echo -e "\n${R}Invalid Option${N}"
      sleep 1
      continue
  fi

  index=$((opt - 1))
  IFS='|' read -r SEL_NAME SEL_TYPE SEL_PAYLOAD SEL_DIR <<< "${ALL_THEMES[$index]}"

  clear
  header

  # Show selected theme info
  echo -e " ${BW}SELECTED:${N} ${BC}${SEL_NAME}${N}"
  case "$SEL_TYPE" in
    bp)   echo -e " ${BW}TYPE:${N}     ${C}Blueprint${N}" ;;
    zip)  echo -e " ${BW}TYPE:${N}     ${M}ZIP Theme${N}" ;;
    arix) echo -e " ${BW}TYPE:${N}     ${Y}Arix Version${N}" ;;
  esac

  # Check status
  case "$SEL_TYPE" in
    bp)
      slug="${SEL_PAYLOAD%.blueprint}"
      if is_installed_bp "$slug"; then
          echo -e " ${BW}STATUS:${N}   ${BG}INSTALLED${N}"
      else
          echo -e " ${BW}STATUS:${N}   ${R}NOT INSTALLED${N}"
      fi
      ;;
    zip)
      clean="${SEL_PAYLOAD%.zip}"
      if is_installed_zip "$clean"; then
          echo -e " ${BW}STATUS:${N}   ${BG}INSTALLED${N}"
      else
          echo -e " ${BW}STATUS:${N}   ${R}NOT INSTALLED${N}"
      fi
      ;;
    arix)
      if is_installed_arix; then
          echo -e " ${BW}STATUS:${N}   ${BG}INSTALLED${N}"
      else
          echo -e " ${BW}STATUS:${N}   ${R}NOT INSTALLED${N}"
      fi
      ;;
  esac

  echo -e "${C} ──────────────────────────────────────────────────────────${N}"
  echo -e "  ${BG}[ 1 ]${N} Install"
  echo -e "  ${BR}[ 2 ]${N} Uninstall"
  echo -e "  ${BY}[ 0 ]${N} Back to Menu"
  echo -e "${C} ──────────────────────────────────────────────────────────${N}"

  read -p " Action: " action

  case $action in
      1)
          case "$SEL_TYPE" in
            bp)   install_blueprint "$SEL_PAYLOAD" ;;
            zip)  install_zip "$SEL_PAYLOAD" ;;
            arix)
                IFS='|' read -r _ _ SEL_VERSION SEL_DIR <<< "${ALL_THEMES[$index]}"
                install_arix "$SEL_VERSION" "$SEL_DIR"
                ;;
          esac
          ;;
      2)
          case "$SEL_TYPE" in
            bp)   uninstall_theme "$SEL_PAYLOAD" "$SEL_TYPE" ;;
            zip)  uninstall_theme "$SEL_PAYLOAD" "$SEL_TYPE" ;;
            arix) uninstall_theme "$SEL_PAYLOAD" "$SEL_TYPE" ;;
          esac
          ;;
      0) continue ;;
      *) echo -e "${R}Invalid Choice${N}" ;;
  esac

  echo
  read -p " Press [Enter] to return..."
done
