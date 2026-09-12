#!/usr/bin/env bash
HN_BASE_URL="$(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 --decode)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then . "$SCRIPT_DIR/common.sh"
else _tmp_c="$(mktemp)"; curl -fsSL "$HN_BASE_URL/lib/common.sh" -o "$_tmp_c" 2>/dev/null; [ -s "$_tmp_c" ] && . "$_tmp_c" && rm -f "$_tmp_c" || { rm -f "$_tmp_c"; echo "[FAIL] Cannot load common.sh"; exit 1; }; fi

sy_header() {
    hn_clear
    hn_metrics
    echo -e " ${V}┌─${NC} ${C}Uptime:${NC} ${W}${HN_UPT}${NC}  ${DG}|${NC} ${C}Disk:${NC} ${W}${HN_DISK}${NC}  ${DG}|${NC} ${C}CPU:${NC} ${W}${HN_CPU}%${NC} ${C}RAM:${NC} ${W}${HN_RAM}%${NC} ${V}─┐${NC}"
    echo -e " ${C}◆ HAPPY-NODE SYSTEM MANAGER${NC}"
    echo -e " ${DG}────────────────────────────────────────────────────────────${NC}"
    echo -e " ${W}System:${NC} ${G}${OS_NAME} ${OS_VER}${NC}   ${W}Arch:${NC} ${G}${ARCH}${NC}   ${W}PM:${NC} ${G}${PM}${NC}"
    hn_line
}

sy_update() {
    hn_clear
    hn_info "Updating package lists..."
    eval "$PM_UPDATE" || hn_warn "Update failed."
    hn_info "Upgrading packages..."
    eval "$PM_UPGRADE" || hn_warn "Upgrade failed."
    hn_ok "System update complete."
    hn_pause
}

sy_info() {
    hn_clear
    echo -e "${C}◆ SYSTEM INFORMATION${NC}"
    hn_line
    echo -e " ${DG}Hostname :${NC} ${W}$(hostname)${NC}"
    echo -e " ${DG}Kernel   :${NC} ${W}$(uname -r)${NC}"
    echo -e " ${DG}OS       :${NC} ${W}${OS_NAME} ${OS_VER}${NC}"
    echo -e " ${DG}Arch     :${NC} ${W}${ARCH}${NC}"
    echo -e " ${DG}CPU      :${NC} ${W}$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo N/A)${NC}"
    echo -e " ${DG}Uptime   :${NC} ${W}${HN_UPT}${NC}"
    echo -e " ${DG}Memory   :${NC} ${W}$(free -h 2>/dev/null | awk '/^Mem:/ {print $3"/"$2}' || echo N/A)${NC}"
    echo -e " ${DG}Disk /   :${NC} ${W}$(df -h / 2>/dev/null | awk 'NR==2 {print $3"/"$2" ("$5")"}' || echo N/A)${NC}"
    hn_line
    hn_pause
}

sy_procs() {
    hn_clear
    echo -e "${C}◆ TOP PROCESSES${NC}"
    hn_line
    ps aux --sort=-%cpu 2>/dev/null | head -n 11
    hn_line
    hn_pause
}

sy_cleanup() {
    hn_clear
    hn_info "Cleaning package cache and temp files..."
    case "$PM" in
        apt) apt-get autoremove -y >/dev/null 2>&1; apt-get clean >/dev/null 2>&1 ;;
        apk) apk cache clean >/dev/null 2>&1 ;;
        dnf) dnf clean all >/dev/null 2>&1 ;;
        yum) yum clean all >/dev/null 2>&1 ;;
    esac
    hn_ok "Cleanup complete."
    hn_pause
}

sy_reboot() {
    hn_clear
    hn_warn "This will reboot the server."
    read -rp "$(echo -e "${Y}Continue? [y/N]: ${NC}")" c
    case "$c" in
        y|Y) hn_info "Rebooting..."; reboot ;;
        *) hn_info "Cancelled."; hn_pause ;;
    esac
}

while true; do
    sy_header
    echo -e "  ${G}[1]${NC} Update system"
    echo -e "  ${G}[2]${NC} System information"
    echo -e "  ${G}[3]${NC} Running processes"
    echo -e "  ${G}[4]${NC} Cleanup cache/temp"
    echo -e "  ${R}[5]${NC} Reboot server"
    echo -e "  ${R}[0]${NC} Back"
    hn_line
    read -rp "$(echo -e "${Y}Select: ${NC}")" o
    case "$o" in
        1) sy_update ;;
        2) sy_info ;;
        3) sy_procs ;;
        4) sy_cleanup ;;
        5) sy_reboot ;;
        0) break ;;
        *) hn_err "Invalid option."; sleep 0.8 ;;
    esac
done