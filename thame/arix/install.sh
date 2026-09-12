#!/usr/bin/env bash

# ==========================================
#  ARIX THEME INSTALLER | HAPPY-NODE
#  Supports v1.3.1 and v2.1.0
#  Safe installation with backups
# ==========================================

[[ $EUID -ne 0 ]] && echo "Run as root!" && exit 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
LIB_FILE="$SCRIPT_DIR/../../lib/common.sh"

if [ -f "$LIB_FILE" ]; then
    . "$LIB_FILE"
else
    R='\033[1;38;5;196m'; G='\033[1;38;5;82m'; Y='\033[1;38;5;220m'
    C='\033[1;38;5;51m'; NC='\033[0m'
    hn_info()  { echo -e "${C}[INFO]${NC}  $*"; }
    hn_ok()    { echo -e "${G}[ OK ]${NC}  $*"; }
    hn_warn()  { echo -e "${Y}[WARN]${NC}  $*"; }
    hn_err()   { echo -e "${R}[FAIL]${NC}  $*"; }
    hn_line()  { echo "------------------------------------------------------------"; }
    hn_pause() { echo ""; read -rp "Press Enter to continue..." _; }
    hn_clear() { clear 2>/dev/null || printf '\033c'; }
    PM=""
    command -v apt-get >/dev/null 2>&1 && PM="apt"
    [ -z "$PM" ] && { command -v apk >/dev/null 2>&1 && PM="apk"; }
    [ -z "$PM" ] && { command -v dnf >/dev/null 2>&1 && PM="dnf"; }
    [ -z "$PM" ] && { command -v yum >/dev/null 2>&1 && PM="yum"; }
fi

PANEL_DIR="/var/www/pterodactyl"
BASE_URL="$(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4vdGhhbWUvYXJpeA==' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4vdGhhbWUvYXJpeA==' | base64 --decode)"
BACKUP_DIR="/tmp/hn_backups"
TMP_DIR="$(mktemp -d)"
ARIX_VER=""
STEP_OK="[${G}\xe2\x9c\x93${NC}]"
STEP_FAIL="[${R}\xe2\x9c\x97${NC}]"

arx_header() {
    hn_clear
    echo -e "${C}◆ HAPPY-NODE  |  ARIX THEME INSTALLER${NC}"
    echo -e "${C}  Safe install with backup & verification${NC}"
    hn_line
}

arx_cleanup() { rm -rf "$TMP_DIR" 2>/dev/null; }

arx_choose_version() {
    echo -e "  ${G}[1]${NC} ARIX v1.3.1  (Stable, lightweight)"
    echo -e "  ${G}[2]${NC} ARIX v2.1.0  (Latest, more features)"
    hn_line
    read -rp "$(echo -e "${Y}Select version [1-2]: ${NC}")" ver_choice
    case "$ver_choice" in
        2) ARIX_VER="v2.1.0" ;;
        *) ARIX_VER="v1.3.1" ;;
    esac
    hn_info "Selected: ARIX ${ARIX_VER}"
}

# ── Step 1: Validate Pterodactyl installation ──
arx_validate_panel() {
    echo ""
    if [ ! -d "$PANEL_DIR" ]; then
        hn_err "Step 1 — Pterodactyl not found at $PANEL_DIR"
        return 1
    fi
    if [ ! -f "$PANEL_DIR/artisan" ]; then
        hn_err "Step 1 — $PANEL_DIR is not a valid Pterodactyl installation (no artisan)"
        return 1
    fi
    if [ ! -d "$PANEL_DIR/resources" ]; then
        hn_err "Step 1 — $PANEL_DIR is missing resources/ directory"
        return 1
    fi
    hn_ok "Step 1 — Pterodactyl installation verified"
}

# ── Step 2: Get ARIX source (local or download) ──
arx_source() {
    # Check local folder first
    if [ -d "$SCRIPT_DIR/arix-${ARIX_VER}/pterodactyl/arix" ]; then
        ARIX_SRC="$SCRIPT_DIR/arix-${ARIX_VER}"
        hn_ok "Step 2 — Using local package: $ARIX_SRC"
        return 0
    fi
    # Check if already installed
    if [ -d "$PANEL_DIR/arix" ]; then
        ARIX_SRC="$PANEL_DIR"
        hn_ok "Step 2 — Using existing installation: $PANEL_DIR"
        return 0
    fi
    # Download package — try .zip first, fallback to .tar.gz
    hn_info "Step 2 — Downloading ARIX ${ARIX_VER}..."
    local pkg_url=""
    local pkg=""
    local extracted=false

    # Try .zip first (actual format on GitHub)
    pkg_url="${BASE_URL}/arix-${ARIX_VER}.zip"
    pkg="$TMP_DIR/arix-${ARIX_VER}.zip"
    if curl -fL --progress-bar --max-time 120 "$pkg_url" -o "$pkg" 2>/dev/null; then
        [ -s "$pkg" ] || { rm -f "$pkg"; hn_err "Step 2 — Downloaded file is empty"; return 1; }
        # Verify PK signature
        if head -c 2 "$pkg" | grep -q 'PK'; then
            hn_ok "Step 2 — Downloaded arix-${ARIX_VER}.zip"
            if unzip -oq "$pkg" -d "$TMP_DIR" 2>/dev/null; then
                extracted=true
            fi
        fi
    fi

    # Fallback to .tar.gz
    if [ "$extracted" = false ]; then
        pkg_url="${BASE_URL}/arix-${ARIX_VER}.tar.gz"
        pkg="$TMP_DIR/arix-${ARIX_VER}.tar.gz"
        rm -f "$pkg"
        if curl -fL --progress-bar --max-time 120 "$pkg_url" -o "$pkg" 2>/dev/null; then
            [ -s "$pkg" ] || { rm -f "$pkg"; hn_err "Step 2 — Downloaded file is empty"; return 1; }
            if tar -xzf "$pkg" -C "$TMP_DIR" 2>/dev/null; then
                extracted=true
                hn_ok "Step 2 — Downloaded arix-${ARIX_VER}.tar.gz"
            fi
        fi
    fi

    if [ "$extracted" = false ]; then
        hn_err "Step 2 — Download failed (tried .zip and .tar.gz)"
        return 1
    fi

    # Find pterodactyl directory in extracted tree
    if [ ! -d "$TMP_DIR/pterodactyl" ]; then
        local found
        found="$(find "$TMP_DIR" -maxdepth 3 -type d -name pterodactyl 2>/dev/null | head -n 1)"
        if [ -n "$found" ]; then
            mv "$found" "$TMP_DIR/pterodactyl" 2>/dev/null || true
        fi
    fi
    if [ ! -d "$TMP_DIR/pterodactyl/arix" ]; then
        hn_err "Step 2 — Could not find pterodactyl/arix in extracted package"
        return 1
    fi
    ARIX_SRC="$TMP_DIR"
    return 0
}

# ── Step 3: Install dependencies ──
arx_deps() {
    hn_info "Step 3 — Installing dependencies..."

    case "$PM" in
        apt) apt-get update -y -q >/dev/null 2>&1
             apt-get install -y rsync curl unzip >/dev/null 2>&1 ;;
        apk) apk add rsync curl unzip >/dev/null 2>&1 ;;
        dnf) dnf install -y rsync curl unzip >/dev/null 2>&1 ;;
        yum) yum install -y rsync curl unzip >/dev/null 2>&1 ;;
    esac

    local need_node_install=false
    if ! command -v node >/dev/null 2>&1; then
        need_node_install=true
    else
        local node_ver
        node_ver="$(node -v 2>/dev/null | sed 's/^v\([0-9][0-9]*\).*/\1/')"
        if [ -n "$node_ver" ] && [ "$node_ver" -lt 22 ] 2>/dev/null; then
            hn_warn "Node.js v${node_ver} found, but v22+ required. Upgrading..."
            need_node_install=true
        fi
    fi

    if [ "$need_node_install" = true ]; then
        if [ "$PM" = "apt" ]; then
            hn_info "Installing Node.js 22..."
            rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null
            mkdir -p /etc/apt/keyrings
            curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg 2>/dev/null
            echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
            apt-get update -y -q >/dev/null 2>&1
            apt-get install -y nodejs -q
        elif [ "$PM" = "dnf" ] || [ "$PM" = "yum" ]; then
            hn_info "Installing Node.js 22..."
            curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
            $PM install -y nodejs
        else
            hn_warn "Please install Node.js 22+ manually, then retry."
            return 1
        fi
    fi

    if ! command -v yarn >/dev/null 2>&1; then
        hn_info "Installing Yarn..."
        npm i -g yarn >/dev/null 2>&1
    fi

    hn_ok "Step 3 — Node.js $(node -v 2>/dev/null) | Yarn $(yarn -v 2>/dev/null)"
}

# ── Step 4: Create backup ──
arx_backup() {
    mkdir -p "$BACKUP_DIR"
    local BPATH="$BACKUP_DIR/arix_backup_${ARIX_VER}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BPATH"

    for d in app config database routes resources public; do
        [ -d "$PANEL_DIR/$d" ] && cp -a "$PANEL_DIR/$d" "$BPATH/" 2>/dev/null
    done
    [ -f "$PANEL_DIR/.env" ] && cp -a "$PANEL_DIR/.env" "$BPATH/" 2>/dev/null
    [ -d "$PANEL_DIR/arix" ] && cp -a "$PANEL_DIR/arix" "$BPATH/" 2>/dev/null

    ARIX_BACKUP="$BPATH"
    hn_ok "Step 4 — Backup created: $BPATH"
}

# ── Step 5: Apply ARIX files ──
arx_apply() {
    local MODE="${1:-install}"
    local SRC="$ARIX_SRC/pterodactyl"
    [ -d "$SRC/arix" ] || { hn_err "Step 5 — ARIX version directory missing"; return 1; }

    hn_info "Step 5 — Copying ARIX ${ARIX_VER} files..."

    # Copy app/ (Console/Commands — arix.php, ArixLang.php)
    if [ -d "$SRC/app" ]; then
        rsync -a "$SRC/app/" "$PANEL_DIR/app/"
        hn_ok "Step 5 — Copied app/ (Console Commands)"
    fi

    # Copy arix/ (theme files)
    mkdir -p "$PANEL_DIR/arix"
    if [ "$MODE" = "update" ]; then
        rsync -a \
            --exclude='routes.ts' \
            --exclude='getServer.ts' \
            --exclude='admin.blade.php' \
            --exclude='admin.php' \
            --exclude='ServerTransformer.php' \
            "$SRC/arix/" "$PANEL_DIR/arix/"
    else
        rsync -a "$SRC/arix/" "$PANEL_DIR/arix/"
    fi
    hn_ok "Step 5 — Copied arix/"

    # Copy config/ (arixTheme.php for v2.1.0)
    if [ -d "$SRC/config" ]; then
        rsync -a "$SRC/config/" "$PANEL_DIR/config/"
        hn_ok "Step 5 — Copied config/"
    fi

    # Verify copied files exist
    if [ ! -d "$PANEL_DIR/arix" ]; then
        hn_err "Step 5 — arix/ directory missing after copy"
        return 1
    fi
    if [ ! -f "$PANEL_DIR/app/Console/Commands/arix.php" ] && [ ! -f "$PANEL_DIR/app/Console/Commands/Arix.php" ]; then
        hn_warn "Step 5 — arix.php command not found (may be expected for some versions)"
    fi
}

# ── Step 6: Database migrations ──
arx_migrate() {
    cd "$PANEL_DIR" || { hn_err "Step 6 — Cannot enter panel dir"; return 1; }

    hn_info "Step 6 — Running database migrations..."
    local migrate_out
    migrate_out=$(php artisan migrate --force 2>&1)
    local rc=$?

    if [ $rc -ne 0 ]; then
        # Check if it's "nothing to migrate" (not a real error)
        if echo "$migrate_out" | grep -qi "nothing to migrate\|already exist"; then
            hn_ok "Step 6 — Database already up to date"
        else
            hn_err "Step 6 — Migration failed:"
            echo "$migrate_out" | head -n 10
            hn_warn "Step 6 — Restoring backup..."
            [ -d "$ARIX_BACKUP" ] && {
                for d in app config database routes resources public; do
                    [ -d "$ARIX_BACKUP/$d" ] && rsync -a "$ARIX_BACKUP/$d/" "$PANEL_DIR/$d/" 2>/dev/null
                done
                hn_info "Step 6 — Backup restored"
            }
            return 1
        fi
    else
        hn_ok "Step 6 — Migrations completed"
    fi
}

# ── Step 7: Install frontend dependencies ──
arx_yarn_deps() {
    cd "$PANEL_DIR" || return 1

    hn_info "Step 7 — Installing dependencies..."
    yarn --ignore-engines 2>&1 | tail -n 3 || true

    if [ "$ARIX_VER" = "v2.1.0" ]; then
        hn_info "Step 7 — Installing ARIX v2.1.0 packages..."
        yarn add --ignore-engines react-email-editor react-colorful recharts ua-parser-js cronstrue react-day-picker jszip react-turnstile @dnd-kit/core @dnd-kit/sortable @dnd-kit/utilities @types/md5 md5 react-icons@5.4.0 markdown-to-jsx i18next-browser-languagedetector@7.2.1 2>&1 | tail -n 3 || true
    else
        hn_info "Step 7 — Installing ARIX v1.3.1 packages..."
        yarn add --ignore-engines @types/md5 md5 react-icons@5.4.0 @types/bbcode-to-react bbcode-to-react i18next-browser-languagedetector@7.2.1 2>&1 | tail -n 3 || true
    fi

    hn_ok "Step 7 — Dependencies installed"
}

# ── Step 8: Build frontend assets ──
arx_build() {
    cd "$PANEL_DIR" || return 1

    export NODE_OPTIONS=--openssl-legacy-provider
    hn_info "Step 8 — Building panel assets (this can take a few minutes)..."

    local build_out
    build_out=$(yarn --ignore-engines build:production 2>&1)
    local rc=$?

    if [ $rc -ne 0 ]; then
        hn_err "Step 8 — Build failed:"
        echo "$build_out" | tail -n 15
        return 1
    fi
    hn_ok "Step 8 — Assets built successfully"
}

# ── Step 9: Post-install tasks ──
arx_post_install() {
    cd "$PANEL_DIR" || return 1

    hn_info "Step 9 — Compiling translations..."
    php artisan language:compile 2>/dev/null && \
        hn_ok "Step 9 — Translations compiled" || \
        hn_warn "Step 9 — Translation compile skipped"

    hn_info "Step 9 — Setting permissions..."
    chmod -R 755 storage/* bootstrap/cache 2>/dev/null || true
    # Only fix ownership on specific directories, not vendor/node_modules
    chown -R www-data:www-data "$PANEL_DIR/storage" 2>/dev/null
    chown -R www-data:www-data "$PANEL_DIR/bootstrap/cache" 2>/dev/null
    chown -R www-data:www-data "$PANEL_DIR/arix" 2>/dev/null
    hn_ok "Step 9 — Permissions set"

    hn_info "Step 9 — Optimizing..."
    php artisan optimize:clear 2>/dev/null
    php artisan optimize 2>/dev/null
    hn_ok "Step 9 — Optimization complete"
}

# ── Step 10: Verify installation ──
arx_verify() {
    cd "$PANEL_DIR" || return 1
    local all_ok=true

    echo ""
    hn_info "Step 10 — Verifying installation..."

    [ -d "$PANEL_DIR/arix" ] && hn_ok "  arix/ exists" || { hn_fail "  arix/ missing"; all_ok=false; }
    [ -f "$PANEL_DIR/app/Console/Commands/arix.php" ] || [ -f "$PANEL_DIR/app/Console/Commands/Arix.php" ] && \
        hn_ok "  Console command installed" || { hn_warn "  Console command not found"; }

    if [ "$ARIX_VER" = "v2.1.0" ]; then
        [ -f "$PANEL_DIR/config/arixTheme.php" ] && \
            hn_ok "  arixTheme.php config" || { hn_warn "  arixTheme.php not found"; }
    fi

    # Quick artisan test
    php artisan arix --version >/dev/null 2>&1 && \
        hn_ok "  artisan arix responds" || \
        hn_warn "  artisan arix not responding (may need first login)"

    if [ "$all_ok" = true ]; then
        hn_ok "Step 10 — Installation verified successfully"
    else
        hn_warn "Step 10 — Some checks failed. Review above."
    fi
}

# ==========================================
#  MAIN FUNCTIONS
# ==========================================
arx_install() {
    arx_header
    arx_validate_panel || { hn_pause; return; }
    arx_choose_version
    arx_deps || { hn_pause; return; }
    arx_source || { hn_pause; return; }
    arx_backup
    arx_apply install || { hn_err "File copy failed."; arx_cleanup; hn_pause; return; }
    arx_migrate || { hn_err "Migration failed."; arx_cleanup; hn_pause; return; }
    arx_yarn_deps
    arx_build || { hn_err "Build failed."; arx_cleanup; hn_pause; return; }
    arx_post_install
    arx_verify
    arx_cleanup
    echo ""
    hn_ok "ARIX ${ARIX_VER} installed successfully!"
    hn_pause
}

arx_update() {
    arx_header
    arx_validate_panel || { hn_pause; return; }
    arx_deps || { hn_pause; return; }
    arx_source || { hn_pause; return; }
    arx_backup
    arx_apply update || { hn_err "Update failed."; arx_cleanup; hn_pause; return; }
    arx_migrate || { hn_err "Migration failed."; arx_cleanup; hn_pause; return; }
    arx_yarn_deps
    arx_build || { hn_err "Build failed."; arx_cleanup; hn_pause; return; }
    arx_post_install
    arx_verify
    arx_cleanup
    echo ""
    hn_ok "ARIX ${ARIX_VER} updated successfully!"
    hn_pause
}

arx_uninstall() {
    arx_header
    [ ! -d "$PANEL_DIR" ] && { hn_err "Pterodactyl not found."; hn_pause; return; }
    cd "$PANEL_DIR" || return
    hn_warn "This will revert the panel theme to default Pterodactyl."
    echo -e "${Y}   This will delete:${NC}"
    echo -e "     - arix/ directory"
    echo -e "     - app/Console/Commands/arix.php"
    echo -e "     - app/Console/Commands/ArixLang.php"
    echo -e "${Y}   A backup will NOT be created for uninstall.${N}"
    read -rp "$(echo -e "${Y}Continue? [y/N]: ${NC}")" c
    case "$c" in
        y|Y)
            hn_info "Reverting to stock panel..."
            php artisan arix uninstall 2>/dev/null || true
            rm -f app/Console/Commands/arix.php app/Console/Commands/Arix.php app/Console/Commands/ArixLang.php 2>/dev/null
            rm -rf arix/ 2>/dev/null
            php artisan optimize:clear >/dev/null 2>&1
            hn_ok "ARIX theme uninstalled."
            ;;
        *) hn_info "Cancelled." ;;
    esac
    arx_cleanup
    hn_pause
}

while true; do
    arx_header
    echo -e "  ${G}[1]${NC} Install ARIX Theme"
    echo -e "  ${G}[2]${NC} Update ARIX Theme"
    echo -e "  ${R}[3]${NC} Uninstall ARIX Theme"
    echo -e "  ${R}[0]${NC} Back"
    hn_line
    read -rp "$(echo -e "${Y}Select: ${NC}")" o
    case "$o" in
        1) arx_install ;;
        2) arx_update ;;
        3) arx_uninstall ;;
        0) break ;;
        *) hn_err "Invalid option."; sleep 0.8 ;;
    esac
done
