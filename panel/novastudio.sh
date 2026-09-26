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

NOVA_RUN_URL="https://raw.githubusercontent.com/nobita329/NobitaHost/refs/heads/main/panel/NovaStudio/run.sh"
NOVA_REPO="https://github.com/nobita329/NobitaHost/blob/main/panel/NovaStudio/run.sh"

# Direct launch — koi intermediate menu nahi.
# Hub ke options: [1] Vpanel [2] Mpanel [5] Dpanel [6] Apanel [8] Exit
echo -e "  ${C}→${NC} Nova Studio hub launching... ${DG}(V/M/D/A panels inside)${NC}"
echo -e "  ${SL}Command: bash <(curl -s $NOVA_RUN_URL)${NC}"
echo -e "  ${SL}Repo: $NOVA_REPO${NC}"
echo ""

if ! run_dl "Nova Studio run.sh" "$NOVA_RUN_URL" /tmp/nova_run.sh; then
    echo -e "  ${R}✗${NC} Download failed — check network."
    exit 1
fi

bash /tmp/nova_run.sh
exit 0
