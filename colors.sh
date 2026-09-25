#!/bin/bash
# HAPPY NODE — professional color palette ($'' form for echo -e + read -p)
# Primary: steel/cyan · Accent: soft violet · Success: mint · Dim: slate

# ---------- GitHub base (everything streams from here, nothing saved) ----------
HN_BASE_URL="${HN_BASE_URL:-https://raw.githubusercontent.com/HAPPY-NODE/HAPPY-CMD/main}"

# Run a repo script: local clone copy if present, else stream from GitHub.
# Usage: hn_run "panel/panel.sh"   (repo-root relative path)
# Stream -> temp file (RAM) -> run -> auto-delete. VPS par kuch nahi rehta.
hn_run() (
    local rel="$1" tmp
    if [ -n "${HN_ROOT:-}" ] && [ -f "$HN_ROOT/$rel" ]; then
        bash "$HN_ROOT/$rel"
        exit $?
    fi
    tmp="$(mktemp /tmp/hn_run.XXXXXX)" || { echo "  x mktemp failed"; exit 1; }
    trap 'rm -f "$tmp"' EXIT
    if ! curl -fsSL --max-time 60 "$HN_BASE_URL/$rel" -o "$tmp" || [ ! -s "$tmp" ]; then
        printf "  \033[1;91mx\033[0m cannot fetch: %s\n" "$rel"
        exit 1
    fi
    bash "$tmp"
    exit $?
)

R=$'\033[0;31m'       # red
G=$'\033[0;32m'       # green
Y=$'\033[0;33m'       # amber
B=$'\033[0;34m'       # blue
P=$'\033[0;35m'       # violet
C=$'\033[0;36m'       # cyan
W=$'\033[0;37m'       # white
NC=$'\033[0m'         # reset
M=$'\033[0;95m'       # bright magenta
GR=$'\033[1;92m'      # bright green
CB=$'\033[1;96m'      # bright cyan
DG=$'\033[2m'         # dim
V=$'\033[0;35m'       # violet (alias)
# Professional extras
FB=$'\033[1;34m'      # bold blue
FC=$'\033[1;36m'      # bold cyan
FW=$'\033[1;37m'      # bold white
FG=$'\033[1;32m'      # bold green
FY=$'\033[1;33m'      # bold amber
FR=$'\033[1;31m'      # bold red
SL=$'\033[38;5;245m'  # slate gray
TE=$'\033[1;96m'      # bright teal (glow)
VI=$'\033[1;95m'      # bright violet (glow)
GY=$'\033[38;5;240m'  # dark gray
BG1=$'\033[48;5;235m' # dark bg
BG2=$'\033[48;5;236m' # darker bg
# Extra glow brights
CY=$'\033[1;96m'      # bright cyan glow (alias CB)
MG=$'\033[1;95m'      # bright magenta glow
YP=$'\033[1;93m'      # bright yellow glow
GN=$'\033[1;92m'      # bright green glow (alias GR)
RD=$'\033[1;91m'      # bright red glow

# ---------- Live install progress ----------
disp_len() {
    printf '%s' "$1" | sed $'s/\x1b\\[[0-9;]*[a-zA-Z]//g' | \
        od -An -tu1 -v | awk '{for(i=1;i<=NF;i++) if($i<128 || $i>191) n++} END{print n+0}'
}

# Animated progress bar: progress_bar <pct 0-100>
progress_bar() {
    local pct="${1:-0}" width=28 filled i bar=""
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    filled=$(( pct * width / 100 ))
    for ((i=0; i<width; i++)); do
        if [ $i -lt $filled ]; then bar+="█"; else bar+="░"; fi
    done
    printf "\r   ${FC}[%s]${NC} %3d%%" "$bar" "$pct"
}

# Download file with live progress bar.
# Usage: run_dl "Message" URL OUTPUT
run_dl() {
    local msg="$1" url="$2" out="$3" rc
    echo -e "  ${FC}↓${NC} $msg"
    if command -v curl >/dev/null 2>&1; then
        curl -fL --progress-bar --retry 3 --connect-timeout 15 "$url" -o "$out"
        rc=$?
    else
        wget --progress=bar:force:noscroll -t 3 --timeout=30 "$url" -O "$out"
        rc=$?
    fi
    echo ""
    if [ $rc -eq 0 ] && [ -s "$out" ]; then
        local sz; sz=$(wc -c <"$out" 2>/dev/null || echo 0)
        sz=$((sz + 0))
        if [ "$sz" -ge 1048576 ]; then
            echo -e "  ${FG}✓${NC} Downloaded $((sz / 1048576))MB"
        else
            echo -e "  ${FG}✓${NC} Downloaded ${sz}B"
        fi
        return 0
    fi
    echo -e "  ${FR}✗${NC} Download failed"
    return 1
}

# Run a long command with live spinner + last interesting log line.
# Usage: run_live "Message" cmd args...
run_live() {
    local msg="$1"; shift
    local log; log="$(mktemp /tmp/hn_live.XXXXXX)" || { printf "  \033[1;91mx\033[0m mktemp failed\n"; return 1; }
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0 rc line
    # stdin /dev/null: interactive commands ko background me hang hone se bachata hai
    "$@" >"$log" 2>&1 </dev/null &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        line=$(grep -E '^(Get:|Hit:|Ign:|Unpacking:|Setting up:|Selecting:|Preparing:|Downloading:|Extracting:|Processing:|Building:|Rebuilding:|Adding:|Enabling:|Synchronizing:|Created symlink|update-alternatives)' "$log" 2>/dev/null | tail -1)
        [ -z "$line" ] && line=$(grep -Ei 'install|download|unpack|setup|extract|config' "$log" 2>/dev/null | tail -1)
        [ -z "$line" ] && line=$(tail -1 "$log" 2>/dev/null)
        line="${line//[$'\r\n']/}"
        if [ ${#line} -gt 58 ]; then line="…${line: -57}"; fi
        printf "\r   ${FC}%s${NC} %-58s" "${frames[i]}" "$line"
        i=$(( (i+1) % ${#frames[@]} ))
        sleep 0.12
    done
    wait "$pid"; rc=$?
    printf "\r\033[K"
    rm -f "$log"
    return $rc
}

# Step-by-step install: show each package as it processes.
# Usage: install_steps "Title" pkg1 pkg2 ...
install_steps() {
    local title="$1"; shift
    local pkgs=("$@")
    echo -e "  ${FC}◆${NC} $title"
    local p
    for p in "${pkgs[@]}"; do
        echo -e "     ${SL}•${NC} $p"
    done
    echo ""
    if command -v apt-get >/dev/null 2>&1; then
        run_live "apt-update" env DEBIAN_FRONTEND=noninteractive apt-get update -y -q || true
        run_live "apt" env DEBIAN_FRONTEND=noninteractive apt-get install -y -q "${pkgs[@]}"
    elif command -v yum >/dev/null 2>&1; then
        run_live "yum" yum install -y "${pkgs[@]}"
    else
        return 1
    fi
}

# Auto-install missing system deps with live package list.
ensure_sys_deps() {
    local pkgs=()
    command -v unzip  >/dev/null 2>&1 || pkgs+=(unzip)
    command -v curl   >/dev/null 2>&1 || pkgs+=(curl)
    command -v wget   >/dev/null 2>&1 || pkgs+=(wget)
    command -v git    >/dev/null 2>&1 || pkgs+=(git)
    command -v node   >/dev/null 2>&1 || pkgs+=(nodejs npm)
    command -v php    >/dev/null 2>&1 || pkgs+=(php)
    if [ ${#pkgs[@]} -gt 0 ]; then
        st WARN "Missing: ${pkgs[*]}"
        run_live "apt-update" env DEBIAN_FRONTEND=noninteractive apt-get update -y -q || true
        install_steps "Installing missing packages" "${pkgs[@]}" || st WARN "Some packages may need retry"
    fi
    if ! command -v yarn >/dev/null 2>&1; then
        st WAIT "Installing yarn..."
        run_live "yarn" npm install -g yarn || true
    fi
    return 0
}

# Auto-install Blueprint CLI if missing (non-interactive).
# Usage: ensure_blueprint [panel_dir]
ensure_blueprint() {
    command -v blueprint >/dev/null 2>&1 && return 0
    local pdir="${1:-/var/www/pterodactyl}"
    st WARN "Blueprint CLI missing — auto-installing..."
    ensure_sys_deps
    if [ ! -d "$pdir" ]; then
        st ERR "Panel not found at $pdir"
        return 1
    fi
    local tmp url
    tmp=$(mktemp -d)
    url=$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest 2>/dev/null \
        | grep 'browser_download_url' | grep 'release.zip' | head -1 | cut -d '"' -f 4)
    if [ -z "$url" ]; then
        rm -rf "$tmp"
        st ERR "Could not resolve Blueprint release URL"
        return 1
    fi
    run_dl "Blueprint framework" "$url" "$tmp/release.zip" || { rm -rf "$tmp"; return 1; }
    cd "$pdir" || { rm -rf "$tmp"; return 1; }
    run_live "extract" unzip -o -q "$tmp/release.zip" || { rm -rf "$tmp"; st ERR "Extract failed"; return 1; }
    cat <<EOF > "$pdir/.blueprintrc"
WEBUSER="www-data";
OWNERSHIP="www-data:www-data";
USERSHELL="/bin/bash";
EOF
    chmod +x "$pdir/blueprint.sh" 2>/dev/null
    chown -R www-data:www-data "$pdir" 2>/dev/null || true
    run_live "blueprint-install" bash -c "yes | bash '$pdir/blueprint.sh'" || true
    rm -rf "$tmp"
    if command -v blueprint >/dev/null 2>&1; then
        st OK "Blueprint CLI ready"
        return 0
    fi
    st ERR "Blueprint install incomplete — run Themes → [1] Blueprint"
    return 1
}
