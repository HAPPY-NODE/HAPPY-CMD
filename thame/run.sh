#!/bin/bash

# 🎨 Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
MAGENTA="\e[35m"
RESET="\e[0m"

PANEL_DIR="/var/www/pterodactyl"

draw_box() {
    echo -e "${CYAN}╔══════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}     HAPPY-NODE UI MANAGER     ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════╝${RESET}"
}

pause() {
    echo ""
    read -p "   Press Enter to continue..." dummy
}

# ─── Status Checks ───
check_blueprint() {
    if command -v blueprint >/dev/null 2>&1; then
        echo -e "${GREEN}● ONLINE${RESET}"
        return 0
    fi
    echo -e "${RED}● OFFLINE${RESET}"
    return 1
}

check_arix() {
    if [ -d "$PANEL_DIR/arix" ]; then
        echo -e "${GREEN}● INSTALLED${RESET}"
        return 0
    fi
    echo -e "${RED}● NOT INSTALLED${RESET}"
    return 1
}

check_thames() {
    if [ -d "$PANEL_DIR/resources/views/vendor/blueprint" ]; then
        echo -e "${GREEN}● INSTALLED${RESET}"
        return 0
    fi
    echo -e "${RED}● NOT INSTALLED${RESET}"
    return 1
}

check_extensions() {
    if [ -d "$PANEL_DIR/extensions" ] && [ "$(ls -A $PANEL_DIR/extensions 2>/dev/null)" ]; then
        echo -e "${GREEN}● INSTALLED${RESET}"
        return 0
    fi
    echo -e "${RED}● NOT INSTALLED${RESET}"
    return 1
}

check_hyper() {
    if [ -d "$PANEL_DIR/resources/views/vendor/hyper" ]; then
        echo -e "${GREEN}● INSTALLED${RESET}"
        return 0
    fi
    echo -e "${RED}● NOT INSTALLED${RESET}"
    return 1
}

get_hyper_version() {
    if [ -f "$PANEL_DIR/resources/views/vendor/hyper/hyper.blade.php" ]; then
        grep -oP 'Hyper V[0-9.]+' "$PANEL_DIR/resources/views/vendor/hyper/hyper.blade.php" 2>/dev/null | head -1 || echo "Unknown"
    else
        echo "Not installed"
    fi
}

panel_clear() {
    cd "$PANEL_DIR" 2>/dev/null || return
    php artisan view:clear 2>/dev/null
    php artisan config:clear 2>/dev/null
    php artisan cache:clear 2>/dev/null
    php artisan route:clear 2>/dev/null
    php artisan optimize:clear 2>/dev/null
    chown -R www-data:www-data "$PANEL_DIR"/* 2>/dev/null
    php artisan queue:restart 2>/dev/null
}

# ════════════════════════════════════════════════════
#  MAIN MENU
# ════════════════════════════════════════════════════
while true; do
    clear
    draw_box
    echo ""
    echo -e "   ${YELLOW}[1]${NC} Blueprint         : $(check_blueprint)"
    echo -e "   ${YELLOW}[2]${NC} Theme             : $(check_thames)"
    echo -e "   ${YELLOW}[3]${NC} Extensions        : $(check_extensions)"
    echo -e "   ${YELLOW}[4]${NC} Hyper V1          : $(check_hyper)"
    echo -e "   ${YELLOW}[5]${NC} ARIX Theme        : $(check_arix)"
    echo ""
    echo -e "   ${RED}[0] Exit${RESET}"
    echo ""
    read -p "   ➤ Select Option : " main

    case $main in

    # ══════════════ BLUEPRINT ══════════════
    1)
        while true; do
            clear
            draw_box
            echo ""
            echo -e "   ${CYAN}BLUEPRINT PANEL${RESET}"
            echo -e "   Status : $(check_blueprint)"
            echo ""
            if ! check_blueprint >/dev/null 2>&1; then
                echo -e "   ${GREEN}[1] Install${RESET}"
            else
                echo -e "   ${GREEN}[1] Reinstall${RESET}"
                echo -e "   ${GREEN}[2] Update${RESET}"
                echo -e "   ${GREEN}[3] Info${RESET}"
                echo -e "   ${GREEN}[4] Version${RESET}"
                echo -e "   ${RED}[5] Uninstall${RESET}"
            fi
            echo -e "   ${RED}[0] Back${RESET}"
            echo ""
            read -p "   ➤ Select : " bp
            case $bp in
                1)
                    if ! check_blueprint >/dev/null 2>&1; then
                        echo -e "${CYAN}Installing Blueprint...${RESET}"
                        rm -f /etc/apt/keyrings/nodesource.gpg 2>/dev/null
                        yes | bash <(curl -s $(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 --decode)/thame/install.sh)
                    else
                        echo -e "${CYAN}Reinstalling Blueprint...${RESET}"
                        yes | blueprint -rerun-install
                    fi
                    pause ;;
                2) echo -e "${CYAN}Updating Blueprint...${RESET}"; yes | blueprint -upgrade; pause ;;
                3) blueprint -info; pause ;;
                4) blueprint -version; pause ;;
                5)
                    echo -e "${RED}Uninstalling Blueprint Framework + Extensions...${RESET}"
                    read -rp "$(echo -e "${YELLOW}Are you sure? [y/N]: ${NC}")" confirm
                    if [[ "$confirm" =~ ^[yY]$ ]]; then
                        path=$(which blueprint 2>/dev/null)
                        if [ -n "$path" ]; then
                            systemctl stop pterodactyl-queue 2>/dev/null || true
                            rm -f "$path"
                            rm -rf ~/.blueprint ~/.config/blueprint /var/www/pterodactyl/.blueprint
                            rm -rf /var/www/pterodactyl/app/BlueprintFramework /var/www/pterodactyl/extensions
                            rm -rf /etc/blueprint /etc/systemd/system/blueprint* /etc/systemd/system/pteroq.service
                            rm -f /var/www/pterodactyl/blueprint.backup.tar.gz 2>/dev/null
                            command -v mysql >/dev/null 2>&1 && mysql -e "DROP TABLE IF EXISTS pterodactyl.blueprint_extensions;" 2>/dev/null || true
                            systemctl daemon-reload 2>/dev/null || true
                            echo -e "${GREEN}Blueprint fully uninstalled ✔${RESET}"
                        else
                            echo -e "${RED}Not installed ❌${RESET}"
                        fi
                    else
                        echo -e "${CYAN}Cancelled.${RESET}"
                    fi
                    pause ;;
                0) break ;;
                *) echo -e "${RED}Invalid option${RESET}"; sleep 1 ;;
            esac
        done
        ;;

    # ══════════════ THEME ══════════════
    2)
        while true; do
            clear
            draw_box
            echo ""
            echo -e "   ${CYAN}THEME${RESET}"
            echo -e "   Status : $(check_thames)"
            echo ""
            if ! check_thames >/dev/null 2>&1; then
                echo -e "   ${GREEN}[1] Install${RESET}"
            else
                echo -e "   ${GREEN}[1] Reinstall${RESET}"
                echo -e "   ${GREEN}[2] Uninstall${RESET}"
            fi
            echo -e "   ${RED}[0] Back${RESET}"
            echo ""
            read -p "   ➤ Select : " th
            case $th in
                1)
                    echo -e "${CYAN}Launching Theme Installer...${RESET}"
                    bash <(curl -s $(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 --decode)/thame/thames.sh)
                    pause ;;
                2)
                    echo -e "${RED}Uninstalling Theme...${RESET}"
                    read -rp "$(echo -e "${YELLOW}Are you sure? [y/N]: ${NC}")" confirm
                    if [[ "$confirm" =~ ^[yY]$ ]]; then
                        rm -f "$PANEL_DIR/resources/views/vendor/blueprint/core.blade.php" 2>/dev/null
                        rm -f "$PANEL_DIR/resources/views/vendor/blueprint/admin.blade.php" 2>/dev/null
                        rm -rf "$PANEL_DIR/app/Http/Controllers/Admin/Theme" 2>/dev/null
                        panel_clear
                        echo -e "${GREEN}Theme uninstalled ✔${RESET}"
                    else
                        echo -e "${CYAN}Cancelled.${RESET}"
                    fi
                    pause ;;
                0) break ;;
                *) echo -e "${RED}Invalid option${RESET}"; sleep 1 ;;
            esac
        done
        ;;

    # ══════════════ EXTENSIONS ══════════════
    3)
        while true; do
            clear
            draw_box
            echo ""
            echo -e "   ${CYAN}EXTENSIONS${RESET}"
            echo -e "   Status : $(check_extensions)"
            echo ""
            if ! check_extensions >/dev/null 2>&1; then
                echo -e "   ${GREEN}[1] Install${RESET}"
            else
                echo -e "   ${GREEN}[1] Reinstall${RESET}"
                echo -e "   ${GREEN}[2] Uninstall${RESET}"
            fi
            echo -e "   ${RED}[0] Back${RESET}"
            echo ""
            read -p "   ➤ Select : " ex
            case $ex in
                1)
                    echo -e "${CYAN}Launching Extensions Installer...${RESET}"
                    bash <(curl -s $(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 --decode)/thame/Extension2.sh)
                    pause ;;
                2)
                    echo -e "${RED}Uninstalling Extensions...${RESET}"
                    read -rp "$(echo -e "${YELLOW}Are you sure? [y/N]: ${NC}")" confirm
                    if [[ "$confirm" =~ ^[yY]$ ]]; then
                        rm -rf "$PANEL_DIR/extensions" 2>/dev/null
                        rm -rf "$PANEL_DIR/app/BlueprintFramework" 2>/dev/null
                        panel_clear
                        echo -e "${GREEN}Extensions uninstalled ✔${RESET}"
                    else
                        echo -e "${CYAN}Cancelled.${RESET}"
                    fi
                    pause ;;
                0) break ;;
                *) echo -e "${RED}Invalid option${RESET}"; sleep 1 ;;
            esac
        done
        ;;

    # ══════════════ HYPER V1 ══════════════
    4)
        while true; do
            clear
            draw_box
            echo ""
            echo -e "   ${CYAN}HYPER V1${RESET}"
            echo -e "   Status : $(check_hyper)"

            if check_hyper >/dev/null 2>&1; then
                local_hver=$(get_hyper_version)
                echo -e "   Version : ${GREEN}${local_hver}${RESET}"
            fi
            echo ""

            if ! check_hyper >/dev/null 2>&1; then
                echo -e "   ${GREEN}[1] Install${RESET}"
            else
                echo -e "   ${GREEN}[1] Reinstall${RESET}"
                echo -e "   ${GREEN}[2] Update${RESET}"
                echo -e "   ${GREEN}[3] Info${RESET}"
                echo -e "   ${RED}[4] Uninstall${RESET}"
            fi
            echo -e "   ${RED}[0] Back${RESET}"
            echo ""
            read -p "   ➤ Select : " hy
            case $hy in
                1)
                    echo -e "${MAGENTA}Installing Hyper V1...${RESET}"
                    if ! command -v wget >/dev/null 2>&1; then
                        echo -e "${YELLOW}Installing wget...${RESET}"
                        apt-get install -y wget >/dev/null 2>&1 || yum install -y wget >/dev/null 2>&1 || true
                    fi
                    wget -O /tmp/hyper-installer.sh https://r2.rolexdev.tech/hyperv1/installer.sh 2>/dev/null
                    if [ -f /tmp/hyper-installer.sh ]; then
                        chmod +x /tmp/hyper-installer.sh
                        bash /tmp/hyper-installer.sh
                        rm -f /tmp/hyper-installer.sh
                        panel_clear
                        echo -e "${GREEN}Hyper V1 installed ✔${RESET}"
                    else
                        echo -e "${RED}Download failed! Check your internet connection.${RESET}"
                    fi
                    pause ;;
                2)
                    echo -e "${CYAN}Updating Hyper V1...${RESET}"
                    if ! command -v wget >/dev/null 2>&1; then
                        echo -e "${YELLOW}Installing wget...${RESET}"
                        apt-get install -y wget >/dev/null 2>&1 || yum install -y wget >/dev/null 2>&1 || true
                    fi
                    wget -O /tmp/hyper-installer.sh https://r2.rolexdev.tech/hyperv1/installer.sh 2>/dev/null
                    if [ -f /tmp/hyper-installer.sh ]; then
                        chmod +x /tmp/hyper-installer.sh
                        bash /tmp/hyper-installer.sh
                        rm -f /tmp/hyper-installer.sh
                        panel_clear
                        echo -e "${GREEN}Hyper V1 updated ✔${RESET}"
                    else
                        echo -e "${RED}Download failed!${RESET}"
                    fi
                    pause ;;
                3)
                    echo ""
                    echo -e "   ${CYAN}══════════════════════════════${RESET}"
                    echo -e "   ${CYAN}       HYPER V1 INFO         ${RESET}"
                    echo -e "   ${CYAN}══════════════════════════════${RESET}"
                    echo ""
                    if check_hyper >/dev/null 2>&1; then
                        echo -e "   Status    : ${GREEN}Installed${RESET}"
                        echo -e "   Version   : $(get_hyper_version)"
                        echo -e "   Panel     : $PANEL_DIR"
                        hyper_views=$(find "$PANEL_DIR/resources/views/vendor/hyper" -name "*.blade.php" 2>/dev/null | wc -l)
                        echo -e "   Views     : ${hyper_views} blade files"
                        hyper_controllers=$(find "$PANEL_DIR/app/Http/Controllers/Admin/Hyper" -name "*.php" 2>/dev/null | wc -l)
                        echo -e "   Controllers : ${hyper_controllers} php files"
                    else
                        echo -e "   Status    : ${RED}Not Installed${RESET}"
                        echo -e "   Info      : Install Hyper V1 to see details"
                    fi
                    echo ""
                    echo -e "   ${CYAN}Source     : https://r2.rolexdev.tech/hyperv1/${RESET}"
                    echo -e "   ${CYAN}══════════════════════════════${RESET}"
                    pause ;;
                4)
                    echo -e "${RED}Uninstalling Hyper V1...${RESET}"
                    read -rp "$(echo -e "${YELLOW}Are you sure? [y/N]: ${NC}")" confirm
                    if [[ "$confirm" =~ ^[yY]$ ]]; then
                        rm -rf "$PANEL_DIR/resources/views/vendor/hyper" 2>/dev/null
                        rm -rf "$PANEL_DIR/app/Http/Controllers/Admin/Hyper" 2>/dev/null
                        rm -f "$PANEL_DIR/app/Http/Controllers/Admin/HyperController.php" 2>/dev/null
                        rm -f "$PANEL_DIR/public/hyper" 2>/dev/null
                        rm -rf "$PANEL_DIR/public/vendor/hyper" 2>/dev/null
                        panel_clear
                        echo -e "${GREEN}Hyper V1 uninstalled ✔${RESET}"
                    else
                        echo -e "${CYAN}Cancelled.${RESET}"
                    fi
                    pause ;;
                0) break ;;
                *) echo -e "${RED}Invalid option${RESET}"; sleep 1 ;;
            esac
        done
        ;;

    # ══════════════ ARIX ══════════════
    5)
        while true; do
            clear
            draw_box
            echo ""
            echo -e "   ${CYAN}ARIX THEME${RESET}"
            echo -e "   Status : $(check_arix)"
            echo ""
            if ! check_arix >/dev/null 2>&1; then
                echo -e "   ${GREEN}[1] Install${RESET}"
            else
                echo -e "   ${GREEN}[1] Reinstall${RESET}"
                echo -e "   ${GREEN}[2] Update${RESET}"
                echo -e "   ${GREEN}[3] Info${RESET}"
                echo -e "   ${RED}[4] Uninstall${RESET}"
            fi
            echo -e "   ${RED}[0] Back${RESET}"
            echo ""
            read -p "   ➤ Select : " ar
            case $ar in
                1)
                    echo -e "${MAGENTA}Installing ARIX Theme...${RESET}"
                    bash <(curl -fsSL $(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 --decode)/thame/arix/install.sh)
                    pause ;;
                2)
                    echo -e "${CYAN}Updating ARIX Theme...${RESET}"
                    bash <(curl -fsSL $(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 --decode)/thame/arix/install.sh)
                    pause ;;
                3)
                    echo ""
                    echo -e "   ${CYAN}══════════════════════════════${RESET}"
                    echo -e "   ${CYAN}       ARIX THEME INFO       ${RESET}"
                    echo -e "   ${CYAN}══════════════════════════════${RESET}"
                    echo ""
                    if check_arix >/dev/null 2>&1; then
                        echo -e "   Status    : ${GREEN}Installed${RESET}"
                        echo -e "   Panel     : $PANEL_DIR"
                        if [ -f "$PANEL_DIR/arix/package.json" ]; then
                            arix_ver=$(grep '"version"' "$PANEL_DIR/arix/package.json" 2>/dev/null | head -1 | cut -d'"' -f4)
                            echo -e "   Version   : ${arix_ver:-Unknown}"
                        fi
                        arix_files=$(find "$PANEL_DIR/arix" -type f 2>/dev/null | wc -l)
                        echo -e "   Files     : ${arix_files} files"
                        arix_size=$(du -sh "$PANEL_DIR/arix" 2>/dev/null | awk '{print $1}')
                        echo -e "   Size      : ${arix_size:-Unknown}"
                    else
                        echo -e "   Status    : ${RED}Not Installed${RESET}"
                        echo -e "   Available : v1.3.1 (Stable) | v2.1.0 (Latest)"
                    fi
                    echo ""
                    echo -e "   ${CYAN}══════════════════════════════${RESET}"
                    pause ;;
                4)
                    echo -e "${RED}Uninstalling ARIX Theme...${RESET}"
                    read -rp "$(echo -e "${YELLOW}Are you sure? [y/N]: ${NC}")" confirm
                    if [[ "$confirm" =~ ^[yY]$ ]]; then
                        cd "$PANEL_DIR" 2>/dev/null || { echo "Panel not found!"; pause; continue; }
                        php artisan arix uninstall 2>/dev/null || true
                        rm -f app/Console/Commands/arix.php app/Console/Commands/ArixLang.php 2>/dev/null
                        rm -rf arix/ 2>/dev/null
                        panel_clear
                        echo -e "${GREEN}ARIX Theme uninstalled ✔${RESET}"
                    else
                        echo -e "${CYAN}Cancelled.${RESET}"
                    fi
                    pause ;;
                0) break ;;
                *) echo -e "${RED}Invalid option${RESET}"; sleep 1 ;;
            esac
        done
        ;;

    0)
        clear
        echo -e "${RED}Exiting...${RESET}"
        exit ;;
    *)
        echo -e "${RED}Invalid option${RESET}"; sleep 1 ;;
    esac
done
