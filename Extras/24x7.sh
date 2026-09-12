#!/usr/bin/env bash

# ============================================================
#  HAPPY-NODE  |  24/7 Activity Launcher
# ============================================================

HN_BASE_URL="$(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 --decode)"

R='\033[1;38;5;196m'; G='\033[1;38;5;82m'; Y='\033[1;38;5;220m'
C='\033[1;38;5;51m'; NC='\033[0m'

hn_info()  { echo -e "${C}[INFO]${NC}  $*"; }
hn_ok()    { echo -e "${G}[ OK ]${NC}  $*"; }
hn_err()   { echo -e "${R}[FAIL]${NC}  $*"; }

# Check Python
if ! command -v python3 >/dev/null 2>&1; then
    hn_info "Python3 not found. Installing..."
    apt-get update -y >/dev/null 2>&1 && apt-get install -y python3 >/dev/null 2>&1 || \
    yum install -y python3 >/dev/null 2>&1 || \
    dnf install -y python3 >/dev/null 2>&1 || \
    { hn_err "Cannot install Python3. Install manually: apt install python3"; exit 1; }
fi

# Download script
TMP=$(mktemp /tmp/hn_24x7_XXXXXX.py)
URL="$HN_BASE_URL/Extras/24x7.py"
HTTP_CODE=$(curl -w '%{http_code}' -fsSL "$URL" -o "$TMP" 2>/dev/null)

if [ "$HTTP_CODE" = "200" ] && [ -s "$TMP" ]; then
    chmod +x "$TMP"
    python3 "$TMP"
    rm -f "$TMP"
else
    rm -f "$TMP"
    hn_err "Cannot download 24/7 script (HTTP $HTTP_CODE)"
fi
