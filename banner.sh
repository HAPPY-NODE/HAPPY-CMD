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
    # Cyan → violet gradient (6 lines, brand colors)
    local grad=(
        $'\033[38;5;51m'
        $'\033[38;5;45m'
        $'\033[38;5;39m'
        $'\033[38;5;69m'
        $'\033[38;5;63m'
        $'\033[38;5;135m'
    )
    local art=(
        "  ██╗  ██╗ █████╗ ██████╗ ██████╗ ██╗   ██╗      ███╗   ██╗ ██████╗ ██████╗ ███████╗"
        "  ██║  ██║██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝      ████╗  ██║██╔═══██╗██╔══██╗██╔════╝"
        "  ███████║███████║██████╔╝██████╔╝ ╚████╔╝ █████╗██╔██╗ ██║██║   ██║██║  ██║█████╗  "
        "  ██╔══██║██╔══██║██╔═══╝ ██╔═══╝   ╚██╔╝  ╚════╝██║╚██╗██║██║   ██║██║  ██║██╔══╝  "
        "  ██║  ██║██║  ██║██║     ██║        ██║         ██║ ╚████║╚██████╔╝██████╔╝███████╗"
        "  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝        ╚═╝         ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝"
    )
    local i

    if [ "$width" -lt 80 ]; then
        local small=(
            "  █████╗ ███████╗██╗  ██╗"
            " ██╔══██╗██╔════╝██║  ██║"
            " ███████║███████╗███████║"
            " ██╔══██║╚════██║██╔══██║"
            " ██║  ██║███████║██║  ██║"
            " ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝"
        )
        for i in "${!small[@]}"; do
            printf '%s%s%s\n' "${grad[$i]}" "${small[$i]}" "${NC}"
        done
    else
        for i in "${!art[@]}"; do
            printf '%s%s%s\n' "${grad[$i]}" "${art[$i]}" "${NC}"
        done
    fi
}
