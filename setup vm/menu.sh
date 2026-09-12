#!/usr/bin/env bash
HN_BASE_URL="$(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 --decode)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -f "$SCRIPT_DIR/../lib/common.sh" ]; then . "$SCRIPT_DIR/../lib/common.sh"
else _tmp_c="$(mktemp)"; curl -fsSL "$HN_BASE_URL/lib/common.sh" -o "$_tmp_c" 2>/dev/null; [ -s "$_tmp_c" ] && . "$_tmp_c" && rm -f "$_tmp_c" || { rm -f "$_tmp_c"; echo "[FAIL] Cannot load common.sh"; exit 1; }; fi

vm_header() {
    hn_clear
    hn_metrics
    echo -e "${V}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${V}║${W}                  HAPPY-NODE                        ${V}║${NC}"
    echo -e "${V}║${W}               VPS CONTROL PANEL                    ${V}║${NC}"
    echo -e "${V}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${V}║${NC}                                                      ${V}║${NC}"
    echo -e "${V}║${C}   VM MANAGEMENT                                    ${V}║${NC}"
    echo -e "${V}║${NC}                                                      ${V}║${NC}"
    echo -e "${V}║${G}   [1]${NC}  RDX Tool                                    ${V}║${NC}"
    echo -e "${V}║${G}   [2]${NC}  Run VM       ${DG}•${NC} KVM                         ${V}║${NC}"
    echo -e "${V}║${G}   [3]${NC}  Run VM       ${DG}•${NC} No KVM                      ${V}║${NC}"
    echo -e "${V}║${G}   [4]${NC}  Run VM       ${DG}•${NC} All Setup                   ${V}║${NC}"
    echo -e "${V}║${NC}                                                      ${V}║${NC}"
    echo -e "${V}║${DG}   ────────────────────────────────────────────────   ${V}║${NC}"
    echo -e "${V}║${NC}                                                      ${V}║${NC}"
    echo -e "${V}║${R}   [5]${NC}  Exit                                        ${V}║${NC}"
    echo -e "${V}║${NC}                                                      ${V}║${NC}"
    echo -e "${V}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${V}║${NC}   ${DG}Status:${NC} ${G}● Online${NC}          ${DG}HAPPY-NODE VPS${NC}         ${V}║${NC}"
    echo -e "${V}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

vm_rdx() {
    hn_clear
    echo -e "${Y}▶▶ Running RDX Tool Setup...${NC}"
    hn_line
    hn_info "Cleaning up old files..."
    cd "$HOME" 2>/dev/null || true
    rm -rf myapp flutter 2>/dev/null
    mkdir -p vm && cd vm || { hn_err "Cannot create vm dir."; hn_pause; return; }

    if [ ! -d ".idx" ]; then
        hn_info "Creating .idx directory..."
        mkdir .idx && cd .idx || return
        hn_info "Creating dev.nix configuration..."
        cat <<'EOF' > dev.nix
{ pkgs, ... }: {
  channel = "stable-24.05";

  packages = with pkgs; [
    unzip
    openssh
    git
    qemu_kvm
    sudo
    cdrkit
    cloud-utils
    qemu
  ];

  env = {
    EDITOR = "nano";
  };

  idx = {
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];

    workspace = {
      onCreate = { };
      onStart = { };
    };

    previews = {
      enable = false;
    };
  };
}
EOF
        hn_ok "IDX Tool setup complete!"
        echo -e "${W}┌──────────────────────────────────────┐${NC}"
        echo -e "${W}│ ${G}Status${W}: ${Y}Ready to use${W}                 │${NC}"
        echo -e "${W}│ ${G}Location${W}: ${Y}~/vm/.idx${W}                    │${NC}"
        echo -e "${W}└──────────────────────────────────────┘${NC}"
    else
        hn_warn "Directory .idx already exists — skipping."
    fi
    hn_line
    hn_pause
}

vm_run() {
    local label="$1" file="$2"
    hn_clear
    echo -e "${B}▶▶ Starting ${label}...${NC}"
    hn_line
    hn_info "Fetching script from GitHub..."
    bash <(curl -s "$(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 --decode)/setup%20vm/${file}")
    hn_line
    hn_pause
}

while true; do
    vm_header
    echo -ne "  ${W}Select → ${NC}"
    read -r op
    case "$op" in
        1) vm_rdx ;;
        2) vm_run "VM 1 KVM" "vm-1.sh" ;;
        3) vm_run "VM 2 No KVM" "vm-2.sh" ;;
        4) vm_run "VM 3 All Setup" "vm-3.sh" ;;
        5)
            hn_clear
            echo -e "${Y}👋 Thank you for using HAPPY-NODE!${NC}"
            exit 0 ;;
        *) hn_err "Invalid option. Try again."; sleep 0.8 ;;
    esac
done