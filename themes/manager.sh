#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
source "$ROOT/colors.sh"

HN_BASE_URL="https://raw.githubusercontent.com/HAPPY-NODE/HAPPY-CMD/main"
LOCAL_BP="$DIR/UI"
LOCAL_ZIP="$DIR/UI/themes"
LOCAL_ARIX="$DIR/arix"
URL_BP="$HN_BASE_URL/test/thame/UI"
URL_ZIP="$HN_BASE_URL/test/thame/UI/themes"
URL_ARIX="$HN_BASE_URL/test/thame/arix"
URL_ARIX_FALLBACK="https://raw.githubusercontent.com/sdgamer8263-sketch/pterodactyl_extention1/main/sd"
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

trap 'echo -e "\n  ${Y}!${NC} Force exit"; exit 1' SIGINT

ALL_THEMES=(
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
  "Arix v2.1.0 (Latest)|arix|v2.1.0|v210"
  "Arix v2.0.8|arix|v2.0.8|v208"
  "Arix v1.3.1|arix|v1.3.1|v131"
  "Arix AV1|arix|av1|av1"
)

is_installed_bp() {
    local slug="${1%.blueprint}"
    [ -d "$PTERO_DIR/storage/extensions/$slug" ]
}
is_installed_zip() {
    local name="${1%.zip}"
    [ -f "$PTERO_DIR/storage/.hn_theme_${name}" ] || [ -d "$PTERO_DIR/resources/views/vendor/$name" ]
}
is_installed_arix() {
    [ -d "$PTERO_DIR/arix" ] || [ -f "$PTERO_DIR/app/Console/Commands/Arix.php" ]
}

show_header() {
    clear
    echo -e "  ${B}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "  ${B}║${NC}   ${W}T H E M E   L I B R A R Y${NC}                     ${B}║${NC}"
    echo -e "  ${B}║${NC}   ${DG}HAPPY NODE • Blueprint + ZIP + ARIX${NC}            ${B}║${NC}"
    echo -e "  ${B}╚══════════════════════════════════════════════════╝${NC}"
    echo -e "  ${DG}User:${NC} ${W}$(whoami)@$(hostname)${NC}  ${DG}│${NC}  ${DG}Time:${NC} ${W}$(date +'%H:%M')${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

show_themes() {
    show_header
    echo -e "  ${C}◆ ALL THEMES (${#ALL_THEMES[@]})${NC}"
    echo ""
    local i num t_name t_type t_payload t_dir slug clean status label extra
    for i in "${!ALL_THEMES[@]}"; do
        num=$((i+1))
        IFS='|' read -r t_name t_type t_payload t_dir <<< "${ALL_THEMES[$i]}"
        extra=""
        case "$t_type" in
            bp)
                slug="${t_payload%.blueprint}"
                if is_installed_bp "$slug"; then status="${G}INSTALLED${NC}"; else status="${DG}—${NC}"; fi
                label="${C}BP${NC}"
                ;;
            zip)
                clean="${t_payload%.zip}"
                if is_installed_zip "$clean"; then status="${G}INSTALLED${NC}"; else status="${DG}—${NC}"; fi
                label="${P}ZIP${NC}"
                ;;
            arix)
                if is_installed_arix; then status="${G}INSTALLED${NC}"; else status="${DG}—${NC}"; fi
                label="${Y}ARX${NC}"
                extra=" (${t_payload})"
                ;;
        esac
        printf "     ${G}%2d${NC}  %-22s %b  %b %s\n" "$num" "$t_name" "$label" "$status" "$extra"
    done
    echo ""
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Pick Theme${NC} ${DG}(0-${#ALL_THEMES[@]}):${NC} "
}

install_blueprint() {
    local NAME="$1"
    local SLUG="${NAME%.blueprint}"
    local BPURL="$URL_BP/$(echo "$NAME" | sed 's/ /%20/g')"
    st INFO "Installing Blueprint theme: $SLUG"
    if [ ! -d "$PTERO_DIR" ]; then st ERR "Pterodactyl not found"; return 1; fi
    ensure_sys_deps
    ensure_blueprint "$PTERO_DIR" || return 1
    cd "$PTERO_DIR" || return 1
    pkill -9 -f "blueprint" 2>/dev/null || true
    sleep 1
    rm -f "$PTERO_DIR/.blueprint/lock" "$PTERO_DIR/.blueprint.lock" 2>/dev/null
    blueprint -unlock 2>/dev/null || true
    rm -f "$NAME"
    if [ -f "$LOCAL_BP/$NAME" ]; then
        st OK "Local file: $NAME"
        cp "$LOCAL_BP/$NAME" "$NAME"
    else
        if ! run_dl "$SLUG.blueprint" "$BPURL" "$NAME"; then
            rm -f "$NAME"; st ERR "Download failed"; return 1
        fi
    fi
    if head -c 15 "$NAME" 2>/dev/null | grep -qi "<!DOCTYPE\|<html"; then
        rm -f "$NAME"; st ERR "Got HTML, not a blueprint"; return 1
    fi
    st WAIT "Running blueprint -i..."
    run_live "blueprint" blueprint -i "$NAME"
    local rc=$?
    rm -f "$NAME"
    [ $rc -ne 0 ] && { st ERR "Install failed (exit $rc)"; return 1; }
    sudo touch "$PTERO_DIR/storage/.hn_theme_${SLUG}" 2>/dev/null
    run_live "artisan-clear" php artisan optimize:clear
    sudo chown -R www-data:www-data "$PTERO_DIR/storage" "$PTERO_DIR/bootstrap/cache" 2>/dev/null
    st OK "$SLUG installed"
}

install_zip() {
    local ZIPNAME="$1"
    local SLUG="${ZIPNAME%.zip}"
    local ZIPURL="$URL_ZIP/$(echo "$ZIPNAME" | sed 's/ /%20/g')"
    st INFO "Installing ZIP theme: $SLUG"
    if [ ! -d "$PTERO_DIR" ]; then st ERR "Pterodactyl not found"; return 1; fi
    ensure_sys_deps
    if ! command -v unzip >/dev/null 2>&1; then st ERR "unzip missing"; return 1; fi
    local TEMP_DIR
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR" || return 1
    if [ -f "$LOCAL_ZIP/$ZIPNAME" ]; then
        st OK "Local file: $ZIPNAME"
        cp "$LOCAL_ZIP/$ZIPNAME" "download.zip"
    else
        if ! run_dl "$SLUG.zip" "$ZIPURL" "download.zip"; then
            rm -rf "$TEMP_DIR"; st ERR "Download failed"; return 1
        fi
    fi
    if ! head -c 2 "download.zip" | grep -q 'PK'; then
        rm -rf "$TEMP_DIR"; st ERR "Not a valid ZIP"; return 1
    fi
    st WAIT "Extracting..."
    local EXTRACT_DIR="$TEMP_DIR/extracted"
    mkdir -p "$EXTRACT_DIR"
    if ! run_live "unzip" unzip -oq "download.zip" -d "$EXTRACT_DIR"; then
        rm -rf "$TEMP_DIR"; st ERR "Extraction failed"; return 1
    fi
    local INNER_ROOT="$EXTRACT_DIR"
    if [ -d "$EXTRACT_DIR/pterodactyl" ]; then
        INNER_ROOT="$EXTRACT_DIR/pterodactyl"
    elif [ ! -d "$EXTRACT_DIR/resources" ] && [ ! -d "$EXTRACT_DIR/public" ]; then
        local TOP
        TOP=$(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)
        [ -n "$TOP" ] && INNER_ROOT="$TOP"
    fi
    st WAIT "Installing files..."
    cd "$PTERO_DIR" || { rm -rf "$TEMP_DIR"; return 1; }
    local d
    for d in resources public; do
        if [ -d "$INNER_ROOT/$d" ]; then
            sudo cp -a "$INNER_ROOT/$d"/* "$PTERO_DIR/$d/" 2>/dev/null
            st OK "Copied $d/"
        fi
    done
    st WAIT "Building assets (yarn)..."
    export NODE_OPTIONS=--openssl-legacy-provider
    run_live "yarn-install" yarn --ignore-engines install || st WARN "yarn install partial"
    run_live "yarn-build" yarn --ignore-engines build:production || st WARN "yarn build partial"
    run_live "artisan-clear" php artisan optimize:clear
    sudo chown -R www-data:www-data "$PTERO_DIR/storage" "$PTERO_DIR/bootstrap/cache" 2>/dev/null
    sudo touch "$PTERO_DIR/storage/.hn_theme_${SLUG}" 2>/dev/null
    cd / || true
    rm -rf "$TEMP_DIR"
    st OK "$SLUG installed"
}

install_arix() {
    local VERSION="$1" DIRNAME="$2"
    local TEMP_DIR
    TEMP_DIR=$(mktemp -d)
    st INFO "Installing Arix: $VERSION"
    if [ ! -d "$PTERO_DIR" ]; then st ERR "Pterodactyl not found"; rm -rf "$TEMP_DIR"; return 1; fi
    ensure_sys_deps
    cd "$PTERO_DIR" || { rm -rf "$TEMP_DIR"; return 1; }
    local ARIX_URL="$URL_ARIX/$DIRNAME/pterodactyl.zip"
    if [ -f "$LOCAL_ARIX/$DIRNAME/pterodactyl.zip" ]; then
        st OK "Local file: $DIRNAME/pterodactyl.zip"
        cp "$LOCAL_ARIX/$DIRNAME/pterodactyl.zip" "$TEMP_DIR/pterodactyl.zip"
    else
        if ! run_dl "Arix $VERSION" "$ARIX_URL" "$TEMP_DIR/pterodactyl.zip"; then
            st WARN "Primary failed — trying fallback..."
            if ! run_dl "Arix fallback" "$URL_ARIX_FALLBACK/$DIRNAME/pterodactyl.zip" "$TEMP_DIR/pterodactyl.zip"; then
                rm -rf "$TEMP_DIR"; st ERR "All sources failed"; return 1
            fi
        fi
    fi
    if ! head -c 2 "$TEMP_DIR/pterodactyl.zip" | grep -q 'PK'; then
        rm -rf "$TEMP_DIR"; st ERR "Not a valid ZIP"; return 1
    fi
    st WAIT "Extracting..."
    if ! run_live "unzip" unzip -oq "$TEMP_DIR/pterodactyl.zip" -d "$TEMP_DIR/extracted"; then
        rm -rf "$TEMP_DIR"; st ERR "Extraction failed"; return 1
    fi
    local INNER="$TEMP_DIR/extracted"
    [ -d "$TEMP_DIR/extracted/pterodactyl" ] && INNER="$TEMP_DIR/extracted/pterodactyl"
    st INFO "Security scan..."
    local badfile
    for badfile in \
        "$INNER/app/Console/Commands/Arix.php" \
        "$INNER/arix/ins/ins.php" \
        "$INNER/arix/up/up.php"; do
        [ -f "$badfile" ] && rm -f "$badfile" && st WARN "Removed $(basename "$badfile")"
    done
    st WAIT "Installing files..."
    local d
    for d in resources public app routes config database; do
        if [ -d "$INNER/$d" ]; then
            cp -rf "$INNER/$d"/* "$PTERO_DIR/$d/" 2>/dev/null
            st OK "$d/"
        fi
    done
    [ -d "$INNER/arix" ] && cp -rf "$INNER/arix" "$PTERO_DIR/" 2>/dev/null && st OK "arix/"
    [ -d "$INNER/bootstrap" ] && cp -rf "$INNER/bootstrap"/* "$PTERO_DIR/bootstrap/" 2>/dev/null && st OK "bootstrap/"
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
    st WAIT "Fixing errors..."
    cd "$PTERO_DIR" || true
    run_live "migrate" php artisan migrate --force || true
    php artisan storage:link --force 2>/dev/null || true
    run_live "artisan-cache" php artisan optimize:clear || true
    chown -R www-data:www-data "$PTERO_DIR" 2>/dev/null
    chmod -R 755 storage/* bootstrap/cache/ 2>/dev/null
    rm -rf "$TEMP_DIR"
    st OK "Arix $VERSION installed successfully"
}

uninstall_theme() {
    local NAME="$1" TYPE="$2"
    st WAIT "Uninstalling $NAME..."
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
    st OK "$NAME uninstalled"
}

if [ "$EUID" -ne 0 ]; then
    st ERR "Run as root"
    sleep 1
    exit 1
fi
if [ ! -d "$PTERO_DIR" ]; then
    st ERR "Pterodactyl not found at $PTERO_DIR"
    sleep 2
    exit 1
fi

while true; do
    show_themes
    read -r opt
    if [ "$opt" = "0" ]; then
        st INFO "Goodbye from HAPPY-NODE"
        exit 0
    fi
    if ! [[ "$opt" =~ ^[0-9]+$ ]] || [ "$opt" -lt 1 ] || [ "$opt" -gt "${#ALL_THEMES[@]}" ]; then
        echo -e "  ${R}✗ Invalid option${NC}"
        sleep 0.8
        continue
    fi
    index=$((opt - 1))
    IFS='|' read -r SEL_NAME SEL_TYPE SEL_PAYLOAD SEL_DIR <<< "${ALL_THEMES[$index]}"
    clear
    show_header
    echo -e "  ${W}Selected:${NC} ${C}${SEL_NAME}${NC}"
    case "$SEL_TYPE" in
        bp)   echo -e "  ${W}Type:${NC}     Blueprint" ;;
        zip)  echo -e "  ${W}Type:${NC}     ZIP Theme" ;;
        arix) echo -e "  ${W}Type:${NC}     Arix ${SEL_PAYLOAD}" ;;
    esac
    case "$SEL_TYPE" in
        bp)
            slug="${SEL_PAYLOAD%.blueprint}"
            if is_installed_bp "$slug"; then echo -e "  ${W}Status:${NC}   ${G}INSTALLED${NC}"; else echo -e "  ${W}Status:${NC}   ${DG}NOT INSTALLED${NC}"; fi ;;
        zip)
            clean="${SEL_PAYLOAD%.zip}"
            if is_installed_zip "$clean"; then echo -e "  ${W}Status:${NC}   ${G}INSTALLED${NC}"; else echo -e "  ${W}Status:${NC}   ${DG}NOT INSTALLED${NC}"; fi ;;
        arix)
            if is_installed_arix; then echo -e "  ${W}Status:${NC}   ${G}INSTALLED${NC}"; else echo -e "  ${W}Status:${NC}   ${DG}NOT INSTALLED${NC}"; fi ;;
    esac
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -e "     ${GR}[1]${NC} Install"
    echo -e "     ${GR}[2]${NC} Uninstall"
    echo -e "     ${FR}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Action${NC} ${DG}(0-2):${NC} "
    read -r action
    case $action in
        1)
            case "$SEL_TYPE" in
                bp)   install_blueprint "$SEL_PAYLOAD" ;;
                zip)  install_zip "$SEL_PAYLOAD" ;;
                arix) install_arix "$SEL_PAYLOAD" "$SEL_DIR" ;;
            esac
            pause
            ;;
        2)
            read -rp "  Confirm uninstall? (y/N): " cf
            if [[ "$cf" =~ ^[Yy]$ ]]; then
                uninstall_theme "$SEL_PAYLOAD" "$SEL_TYPE"
            else
                st INFO "Cancelled"
            fi
            pause
            ;;
        0) continue ;;
        *) echo -e "  ${R}✗ Invalid${NC}"; sleep 0.6 ;;
    esac
done
