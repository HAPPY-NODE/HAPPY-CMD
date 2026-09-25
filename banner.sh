#!/bin/bash
if [ -z "${NC:-}" ]; then
    _bdir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
    if [ -n "$_bdir" ] && [ -f "$_bdir/colors.sh" ]; then
        source "$_bdir/colors.sh"
    else
        source <(curl -fsSL --max-time 30 "${HN_BASE_URL:-https://raw.githubusercontent.com/HAPPY-NODE/HAPPY-CMD/main}/colors.sh")
    fi
fi

get_width() {
    tput cols 2>/dev/null || echo 80
}

banner() {
    local width=$(get_width)
    local lines=(
        "${CB}  ██╗  ██╗ █████╗ ██████╗ ██████╗ ██╗   ██╗      ███╗   ██╗ ██████╗ ██████╗ ███████╗${NC}"
        "${CB}  ██║  ██║██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝      ████╗  ██║██╔═══██╗██╔══██╗██╔════╝${NC}"
        "${CB}  ███████║███████║██████╔╝██████╔╝ ╚████╔╝ █████╗██╔██╗ ██║██║   ██║██║  ██║█████╗  ${NC}"
        "${CB}  ██╔══██║██╔══██║██╔═══╝ ██╔═══╝   ╚██╔╝  ╚════╝██║╚██╗██║██║   ██║██║  ██║██╔══╝  ${NC}"
        "${CB}  ██║  ██║██║  ██║██║     ██║        ██║         ██║ ╚████║╚██████╔╝██████╔╝███████╗${NC}"
        "${CB}  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝        ╚═╝         ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝${NC}"
    )

    if [ "$width" -lt 80 ]; then
        echo -e "${CB}  █████╗ ███████╗██╗  ██╗${NC}"
        echo -e "${CB} ██╔══██╗██╔════╝██║  ██║${NC}"
        echo -e "${CB} ███████║███████╗███████║${NC}"
        echo -e "${CB} ██╔══██║╚════██║██╔══██║${NC}"
        echo -e "${CB} ██║  ██║███████║██║  ██║${NC}"
        echo -e "${CB} ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝${NC}"
    else
        for line in "${lines[@]}"; do
            echo -e "$line"
        done
    fi
}
