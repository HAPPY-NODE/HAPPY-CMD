#!/usr/bin/env bash
HN_BASE_URL="$(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 --decode)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -f "$SCRIPT_DIR/../lib/common.sh" ]; then . "$SCRIPT_DIR/../lib/common.sh"
else _tmp_c="$(mktemp)"; curl -fsSL "$HN_BASE_URL/lib/common.sh" -o "$_tmp_c" 2>/dev/null; [ -s "$_tmp_c" ] && . "$_tmp_c" && rm -f "$_tmp_c" || { rm -f "$_tmp_c"; echo "[FAIL] Cannot load common.sh"; exit 1; }; fi

EXTRAS_URL="$(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 --decode)/Extras"

ex_header() {
    hn_clear
    echo -e "${DG}─────────── HAPPY-NODE EXTRAS MENU ───────────${NC}"
}

ex_docker() {
    hn_clear
    hn_info "Installing Docker..."
    bash <(curl -fsSL "$EXTRAS_URL/docker.sh")
    hn_pause
}

ex_lxd() {
    hn_clear
    hn_info "Installing LXC/LXD..."
    usermod -aG lxd root 2>/dev/null
    bash <(curl -fsSL "$EXTRAS_URL/Cockpit.sh")
    hn_pause
}

ex_vps() {
    hn_clear
    hn_info "Launching HAPPY-NODE VPS Setup..."
    bash <(curl -fsSL "$HN_BASE_URL/Extras/vps-setup.sh")
    hn_pause
}

ex_24x7() {
    hn_clear
    hn_info "Launching 24/7 Activity Generator..."
    bash <(curl -fsSL "$EXTRAS_URL/24x7.sh")
    hn_pause
}

while true; do
    ex_header
    echo -e " ${G} 1)${NC} Docker"
    echo -e " ${G} 2)${NC} LXC/LXD"
    echo -e " ${G} 3)${NC} VPS Setup ${DG}(LXDE/RDP, PufferPanel, Node.js)${NC}"
    echo -e " ${G} 4)${NC} 24/7 Activity ${DG}(VPS Idle Prevention)${NC}"
    echo -e " ${R} 0)${NC} Back${NC}"
    echo -e "${DG}────────────────────────────────────────${NC}"
    read -rp "Select → " im

    case "$im" in
        1) ex_docker ;;
        2) ex_lxd ;;
        3) ex_vps ;;
        4) ex_24x7 ;;
        0) clear; exit 0 ;;
        *) hn_err "Invalid option!"; hn_pause ;;
    esac
done
