#!/bin/bash
DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
ROOT="$(dirname "$DIR")"
if [ -f "$ROOT/colors.sh" ]; then
    HN_ROOT="$ROOT"
    source "$ROOT/colors.sh"
else
    HN_BASE_URL="${HN_BASE_URL:-https://raw.githubusercontent.com/HAPPY-NODE/HAPPY-CMD/main}"
    source <(curl -fsSL --max-time 30 "$HN_BASE_URL/colors.sh")
    [ -n "${NC:-}" ] || { echo "x cannot fetch colors.sh from GitHub"; exit 1; }
fi
HN_BASE_URL="${HN_BASE_URL:-https://raw.githubusercontent.com/HAPPY-NODE/HAPPY-CMD/main}"

JTG_INSTALL_URL="https://raw.githubusercontent.com/JishnuTheGamer/Jtg/refs/heads/main/install.sh"

# Direct launch — official installer seedha khulega (menu nahi, repo link nahi)
if ! run_dl "JTG installer" "$JTG_INSTALL_URL" /tmp/jtg_install.sh; then
    echo -e "  ${R}✗${NC} Download failed — check network."
    exit 1
fi

bash /tmp/jtg_install.sh
exit 0
