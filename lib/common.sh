#!/usr/bin/env bash

# ============================================================
#  HAPPY-NODE  |  Common Library
#  Universal VPS Panel — Debian / Ubuntu / Alpine / RHEL
# ============================================================

# ---------- Colors ----------
if [ -t 1 ]; then
    R='\033[1;38;5;196m'
    G='\033[1;38;5;82m'
    Y='\033[1;38;5;220m'
    C='\033[1;38;5;51m'
    P='\033[1;38;5;201m'
    V='\033[1;38;5;135m'
    W='\033[1;38;5;255m'
    DG='\033[0;38;5;244m'
    NC='\033[0m'
else
    R=''; G=''; Y=''; C=''; P=''; V=''; W=''; DG=''; NC=''
fi

# ---------- Output helpers ----------
hn_info()  { echo -e "${C}[INFO]${NC}  $*"; }
hn_ok()    { echo -e "${G}[ OK ]${NC}  $*"; }
hn_warn()  { echo -e "${Y}[WARN]${NC}  $*"; }
hn_err()   { echo -e "${R}[FAIL]${NC}  $*"; }
hn_line()  { echo -e "${DG}------------------------------------------------------------${NC}"; }
hn_pause() { echo ""; read -rp "$(echo -e "${DG}Press Enter to continue...${NC}")" _; }
hn_clear() { clear 2>/dev/null || printf '\033c'; }

# Run command, warn on failure without aborting
hn_run() { "$@" || hn_warn "Command failed: $*"; }

# ---------- Platform detection ----------
hn_detect() {
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64)  ARCH_ALT="amd64" ;;
        aarch64|arm64) ARCH_ALT="arm64" ;;
        *)             ARCH_ALT="$ARCH" ;;
    esac

    OS_NAME="Linux"; OS_VER=""
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="${NAME:-Linux}"
        OS_VER="${VERSION_ID:-}"
    fi

    if command -v apt-get >/dev/null 2>&1; then
        PM="apt";  PM_INSTALL="apt-get install -y"; PM_UPDATE="apt-get update -y"; PM_UPGRADE="apt-get upgrade -y"
    elif command -v apk >/dev/null 2>&1; then
        PM="apk";  PM_INSTALL="apk add";           PM_UPDATE="apk update";       PM_UPGRADE="apk upgrade"
    elif command -v dnf >/dev/null 2>&1; then
        PM="dnf";  PM_INSTALL="dnf install -y";    PM_UPDATE="dnf makecache";    PM_UPGRADE="dnf upgrade -y"
    elif command -v yum >/dev/null 2>&1; then
        PM="yum";  PM_INSTALL="yum install -y";    PM_UPDATE="yum makecache";    PM_UPGRADE="yum update -y"
    else
        PM="unknown"; PM_INSTALL=""; PM_UPDATE=""; PM_UPGRADE=""
    fi
}

# ---------- Dependency check ----------
hn_need() {
    for bin in "$@"; do
        if ! command -v "$bin" >/dev/null 2>&1; then
            hn_warn "Missing dependency: $bin (install it from Toolbox)"
            return 1
        fi
    done
    return 0
}

hn_detect