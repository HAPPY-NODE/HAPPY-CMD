#!/usr/bin/env bash
HN_BASE_URL="$(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 --decode)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -f "$SCRIPT_DIR/../lib/common.sh" ]; then
    . "$SCRIPT_DIR/../lib/common.sh"
else
    _tmp_c="$(mktemp)"
    curl -fsSL "$HN_BASE_URL/lib/common.sh" -o "$_tmp_c" 2>/dev/null
    if [ -s "$_tmp_c" ]; then
        . "$_tmp_c"
        rm -f "$_tmp_c"
    else
        rm -f "$_tmp_c"
        echo "[FAIL] Cannot load common.sh"
        exit 1
    fi
fi

PANEL_BASE="$(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 --decode)/panel"

pl_header() {
    hn_clear
    hn_metrics
    echo -e "${C}  HAPPY-NODE${NC}                                             ${DG}v15.0${NC}"
    echo -e "  ${DG}SYSTEM${NC}  ${G}● ONLINE${NC}     ${DG}UPTIME${NC} ${W}${HN_UPT}${NC}     ${DG}LOAD${NC} ${W}$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)${NC}"
    echo -e "  ${DG}─────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${C}AVAILABLE MODULES${NC}"
    echo ""
    echo -e "  ${G}[01]${NC} Pterodactyl        ${G}[07]${NC} Convoy"
    echo -e "  ${G}[02]${NC} Jexactyl           ${G}[08]${NC} FeatherPanel"
    echo -e "  ${G}[03]${NC} JexPanel           ${G}[09]${NC} MythicalDash"
    echo -e "  ${G}[04]${NC} Reviactyl          ${G}[10]${NC} MythicalDash v3"
    echo -e "  ${G}[05]${NC} CtrlPanel          ${G}[11]${NC} VPS Panel"
    echo -e "  ${G}[06]${NC} Paymenter          ${R}[00]${NC} Exit"
    echo ""
    echo -e "  ${DG}─────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${W}Select › ${NC}"
}

pl_run() {
    local label="$1" url="$2"
    if [ -z "$url" ]; then
        hn_warn "${label} is coming soon."
        sleep 1.2
        return
    fi
    echo -e "  ${C}➜ Executing ${label} Routine...${NC}"
    bash <(curl -s "$url")
    hn_pause
}

while true; do
    pl_header
    read -r p
    case "$p" in
        1|01) pl_run "Pterodactyl" "$PANEL_BASE/pterodactyl/run.sh" ;;
        2|02) pl_run "Jexactyl" "$PANEL_BASE/Jexactyl/install.sh" ;;
        3|03) pl_run "JexPanel" "" ;;
        4|04) pl_run "Reviactyl" "$PANEL_BASE/reviactyl/run.sh" ;;
        5|05) pl_run "CtrlPanel" "" ;;
        6|06) pl_run "Paymenter" "$PANEL_BASE/paymenter/run.sh" ;;
        7|07) pl_run "Convoy" "$PANEL_BASE/Convoy/install.sh" ;;
        8|08) pl_run "FeatherPanel" "" ;;
        9|09) pl_run "MythicalDash" "$PANEL_BASE/mythical/run.sh" ;;
        10) pl_run "MythicalDash v3" "$PANEL_BASE/mythical/run.sh" ;;
        11) pl_run "VPS Panel" "" ;;
        0|00|exit|quit)
            echo -e "\n  ${R}Goodbye from HAPPY-NODE!${NC}"
            exit 0 ;;
        *) hn_err "Invalid Selection"; sleep 1 ;;
    esac
done
