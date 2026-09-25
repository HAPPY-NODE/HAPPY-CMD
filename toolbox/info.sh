#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"
source "$ROOT/colors.sh"

LOG_FILE="$HOME/.happy_cmd_sysinfo.log"
BACKUP_DIR="$HOME/.happy_cmd_backups"
LOG_MAX_SIZE=10485760
mkdir -p "$BACKUP_DIR"

if [ -f "$LOG_FILE" ]; then
    LOG_SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$LOG_SIZE" -gt "$LOG_MAX_SIZE" ]; then
        mv "$LOG_FILE" "$LOG_FILE.old"
    fi
fi

auto_install() {
    local PKG=$1
    if ! command -v "$PKG" >/dev/null 2>&1; then
        echo -e "  ${Y}!${NC} Missing tool: $PKG — installing..."
        if [ -f /etc/debian_version ]; then
            sudo apt-get update -qq >/dev/null 2>&1
            sudo apt-get install -y -qq "$PKG" >/dev/null 2>&1
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y -q "$PKG" >/dev/null 2>&1
        elif [ -f /etc/arch-release ]; then
            sudo pacman -S --noconfirm "$PKG" >/dev/null 2>&1
        fi
    fi
}

pause() {
    echo ""
    read -rp "  Press Enter to continue... " _
}

show_header() {
    clear
    local CPU RAM
    CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    [ -z "$CPU" ] && CPU="??"
    RAM=$(free -m 2>/dev/null | awk '/Mem/ {printf "%.1f", $3/$2*100}')
    [ -z "$RAM" ] && RAM="??"
    echo -e "  ${CB}╭──────────────────────────────────────────────╮${NC}"
    echo -e "  ${CB}│${W}     S Y S   I N F O                          ${CB}│${NC}"
    echo -e "  ${CB}│${DG}    HAPPY NODE • 100 Server Tools             ${CB}│${NC}"
    echo -e "  ${CB}╰──────────────────────────────────────────────╯${NC}"
    echo -e "  ${DG}CPU:${NC} ${W}${CPU}%${NC}  ${DG}│${NC}  ${DG}RAM:${NC} ${W}${RAM}%${NC}  ${DG}│${NC}  ${DG}Kernel:${NC} ${W}$(uname -r)${NC}  ${DG}│${NC}  ${DG}User:${NC} ${W}$(whoami)@$(hostname)${NC}"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
}

menu_sys() {
    while true; do
        show_header
        echo -e "  ${P}◆ SYSTEM & HARDWARE${NC}"
        printf "     ${G}1.${NC} %-24s ${G}11.${NC} %s\n" "OS Release" "PCI Devices"
        printf "     ${G}2.${NC} %-24s ${G}12.${NC} %s\n" "Kernel Version" "USB Devices"
        printf "     ${G}3.${NC} %-24s ${G}13.${NC} %s\n" "CPU Architecture" "Block Devices"
        printf "     ${G}4.${NC} %-24s ${G}14.${NC} %s\n" "CPU Cores/Threads" "Disk Space (df)"
        printf "     ${G}5.${NC} %-24s ${G}15.${NC} %s\n" "RAM Utilization" "Disk Inodes"
        printf "     ${G}6.${NC} %-24s ${G}16.${NC} %s\n" "Uptime Detail" "Mount Points"
        printf "     ${G}7.${NC} %-24s ${G}17.${NC} %s\n" "Load Average" "Hardware (lshw)"
        printf "     ${G}8.${NC} %-24s ${G}18.${NC} %s\n" "Hostname Info" "BIOS/Firmware"
        printf "     ${G}9.${NC} %-24s ${G}19.${NC} %s\n" "System Date/Time" "Sensor Temps"
        printf "     ${G}10.${NC} %-23s ${G}20.${NC} %s\n" "Last Reboot Log" "Battery Status"
        echo ""
        echo -e "     ${R}[0]${NC} Back"
        echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
        echo -ne "  ${C}➜${NC} ${W}Select Tool${NC} ${DG}(0-20):${NC} "
        read -r opt
        case $opt in
            1) cat /etc/*release 2>/dev/null ;;
            2) uname -a ;;
            3) lscpu 2>/dev/null | grep Architecture ;;
            4) lscpu 2>/dev/null | grep -E '^Thread|^Core|^Socket' ;;
            5) free -h ;;
            6) uptime -p 2>/dev/null || uptime ;;
            7) uptime ;;
            8) hostnamectl 2>/dev/null || hostname ;;
            9) date ;;
            10) last reboot 2>/dev/null | head -5 ;;
            11) auto_install pciutils; lspci 2>/dev/null ;;
            12) auto_install usbutils; lsusb 2>/dev/null ;;
            13) auto_install util-linux; lsblk 2>/dev/null ;;
            14) df -hT --exclude-type=tmpfs 2>/dev/null ;;
            15) df -i 2>/dev/null ;;
            16) mount 2>/dev/null | column -t ;;
            17) auto_install lshw; sudo lshw -short 2>/dev/null ;;
            18) [ -d /sys/firmware/efi ] && echo "UEFI Boot" || echo "Legacy BIOS" ;;
            19) auto_install lm-sensors; sensors 2>/dev/null || echo "sensors not available" ;;
            20) acpi -bi 2>/dev/null || echo "No battery detected" ;;
            0) return ;;
            *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.6; continue ;;
        esac
        pause
    done
}

menu_net() {
    while true; do
        show_header
        echo -e "  ${B}◆ NETWORK & INTERNET${NC}"
        printf "     ${G}21.${NC} %-24s ${G}31.${NC} %s\n" "IP Address (All)" "Ping Google"
        printf "     ${G}22.${NC} %-24s ${G}32.${NC} %s\n" "Public IP" "Ping Custom"
        printf "     ${G}23.${NC} %-24s ${G}33.${NC} %s\n" "DNS Lookup (Dig)" "Traceroute"
        printf "     ${G}24.${NC} %-24s ${G}34.${NC} %s\n" "Whois Domain" "MTR (Live Trace)"
        printf "     ${G}25.${NC} %-24s ${G}35.${NC} %s\n" "Netstat Listening" "Speedtest"
        printf "     ${G}26.${NC} %-24s ${G}36.${NC} %s\n" "SS Active Conns" "Download (Wget)"
        printf "     ${G}27.${NC} %-24s ${G}37.${NC} %s\n" "Route Table" "HTTP Headers"
        printf "     ${G}28.${NC} %-24s ${G}38.${NC} %s\n" "ARP Table" "Scan Local Net"
        printf "     ${G}29.${NC} %-24s ${G}39.${NC} %s\n" "Interface Stats" "Bandwidth (nload)"
        printf "     ${G}30.${NC} %-23s ${G}40.${NC} %s\n" "Flush DNS Cache" "Wifi Signal"
        echo ""
        echo -e "     ${R}[0]${NC} Back"
        echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
        echo -ne "  ${C}➜${NC} ${W}Select Tool${NC} ${DG}(0/21-40):${NC} "
        read -r opt
        case $opt in
            21) ip a 2>/dev/null || ifconfig ;;
            22) curl -s --max-time 5 ifconfig.me; echo "" ;;
            23) read -rp "  Domain: " d; auto_install dnsutils; dig "$d" +short 2>/dev/null ;;
            24) read -rp "  Domain: " d; auto_install whois; whois "$d" 2>/dev/null | head -20 ;;
            25) netstat -tulpn 2>/dev/null || ss -tulpn ;;
            26) ss -tuna 2>/dev/null ;;
            27) ip route 2>/dev/null || route -n ;;
            28) ip neigh 2>/dev/null || arp -a ;;
            29) ip -s link 2>/dev/null ;;
            30) sudo systemd-resolve --flush-caches 2>/dev/null && echo "Flushed." || sudo systemctl restart systemd-resolved 2>/dev/null && echo "Flushed." || echo "Nothing to flush" ;;
            31) ping -c 4 google.com ;;
            32) read -rp "  Host: " h; ping -c 4 "$h" ;;
            33) read -rp "  Host: " h; traceroute "$h" ;;
            34) read -rp "  Host: " h; auto_install mtr; mtr "$h" ;;
            35) auto_install speedtest-cli; speedtest-cli --simple 2>/dev/null || echo "Install failed" ;;
            36) read -rp "  URL: " u; wget "$u" ;;
            37) read -rp "  URL: " u; curl -I "$u" ;;
            38) auto_install nmap; nmap -sn 192.168.1.0/24 2>/dev/null ;;
            39) auto_install nload; nload ;;
            40) nmcli dev wifi 2>/dev/null || iwlist scanning 2>/dev/null | head -20 || echo "No wifi tools" ;;
            0) return ;;
            *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.6; continue ;;
        esac
        pause
    done
}

menu_sec() {
    while true; do
        show_header
        echo -e "  ${R}◆ SECURITY OPS${NC}"
        printf "     ${G}41.${NC} %-24s ${G}51.${NC} %s\n" "Firewall Status" "Check Rootkits"
        printf "     ${G}42.${NC} %-24s ${G}52.${NC} %s\n" "Fail2Ban Status" "Audit SSH Config"
        printf "     ${G}43.${NC} %-24s ${G}53.${NC} %s\n" "Last Logins" "Check Sudo Users"
        printf "     ${G}44.${NC} %-24s ${G}54.${NC} %s\n" "Failed Auth Logs" "Passwd File Check"
        printf "     ${G}45.${NC} %-24s ${G}55.${NC} %s\n" "Current Users" "Open Ports (Nmap)"
        printf "     ${G}46.${NC} %-24s ${G}56.${NC} %s\n" "Password Expiry" "File Permissions"
        printf "     ${G}47.${NC} %-24s ${G}57.${NC} %s\n" "Lock User" "Lynis Audit"
        printf "     ${G}48.${NC} %-24s ${G}58.${NC} %s\n" "Unlock User" "SELinux Status"
        printf "     ${G}49.${NC} %-24s ${G}59.${NC} %s\n" "Kick User" "AppArmor Status"
        printf "     ${G}50.${NC} %-23s ${G}60.${NC} %s\n" "Kill User Procs" "History Cleaner"
        echo ""
        echo -e "     ${R}[0]${NC} Back"
        echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
        echo -ne "  ${C}➜${NC} ${W}Select Tool${NC} ${DG}(0/41-60):${NC} "
        read -r opt
        case $opt in
            41) sudo ufw status 2>/dev/null || sudo firewall-cmd --state 2>/dev/null || echo "No firewall found" ;;
            42) sudo fail2ban-client status 2>/dev/null || echo "Fail2ban not found" ;;
            43) last -n 10 2>/dev/null ;;
            44) sudo grep "Failed" /var/log/auth.log 2>/dev/null | tail -10 || echo "No auth.log" ;;
            45) w ;;
            46) read -rp "  User: " u; sudo chage -l "$u" 2>/dev/null ;;
            47) read -rp "  User: " u; sudo passwd -l "$u" 2>/dev/null ;;
            48) read -rp "  User: " u; sudo passwd -u "$u" 2>/dev/null ;;
            49) read -rp "  User: " u; sudo pkill -u "$u" 2>/dev/null ;;
            50) read -rp "  User: " u; sudo killall -u "$u" 2>/dev/null ;;
            51) auto_install rkhunter; sudo rkhunter --check --sk 2>/dev/null ;;
            52) grep "^PermitRoot" /etc/ssh/sshd_config 2>/dev/null || echo "Not found" ;;
            53) grep sudo /etc/group 2>/dev/null ;;
            54) cat /etc/passwd ;;
            55) auto_install nmap; nmap -sT localhost 2>/dev/null ;;
            56) read -rp "  File: " f; ls -la "$f" 2>/dev/null ;;
            57) auto_install lynis; sudo lynis audit system --quick 2>/dev/null ;;
            58) sestatus 2>/dev/null || echo "Not SELinux system" ;;
            59) aa-status 2>/dev/null || echo "Not AppArmor system" ;;
            60) history -c; echo "History cleared in RAM" ;;
            0) return ;;
            *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.6; continue ;;
        esac
        pause
    done
}

menu_maint() {
    while true; do
        show_header
        echo -e "  ${Y}◆ MAINTENANCE${NC}"
        printf "     ${G}61.${NC} %-24s ${G}71.${NC} %s\n" "Update System" "Edit Crontab"
        printf "     ${G}62.${NC} %-24s ${G}72.${NC} %s\n" "Upgrade System" "List Crons"
        printf "     ${G}63.${NC} %-24s ${G}73.${NC} %s\n" "Clean Packages" "Systemd Failed"
        printf "     ${G}64.${NC} %-24s ${G}74.${NC} %s\n" "Empty Trash" "Journal Vacuum"
        printf "     ${G}65.${NC} %-24s ${G}75.${NC} %s\n" "Clear Thumbnails" "List Services"
        printf "     ${G}66.${NC} %-24s ${G}76.${NC} %s\n" "Restart Network" "Restart SSH"
        printf "     ${G}67.${NC} %-24s ${G}77.${NC} %s\n" "Sync Time (NTP)" "Stop Service"
        printf "     ${G}68.${NC} %-24s ${G}78.${NC} %s\n" "Backup Home" "Start Service"
        printf "     ${G}69.${NC} %-24s ${G}79.${NC} %s\n" "Find Large Files" "Enable Service"
        printf "     ${G}70.${NC} %-23s ${G}80.${NC} %s\n" "Memory Cache Drop" "Disable Service"
        echo ""
        echo -e "     ${R}[0]${NC} Back"
        echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
        echo -ne "  ${C}➜${NC} ${W}Select Tool${NC} ${DG}(0/61-80):${NC} "
        read -r opt
        case $opt in
            61) sudo apt update 2>/dev/null || sudo yum check-update 2>/dev/null ;;
            62) sudo apt upgrade -y 2>/dev/null || sudo yum update -y 2>/dev/null ;;
            63) sudo apt autoremove -y 2>/dev/null || sudo yum autoremove 2>/dev/null ;;
            64) rm -rf ~/.local/share/Trash/* 2>/dev/null; echo "Trash cleared" ;;
            65) rm -rf ~/.cache/thumbnails/* 2>/dev/null; echo "Thumbnails cleared" ;;
            66) sudo systemctl restart networking 2>/dev/null || sudo systemctl restart NetworkManager 2>/dev/null ;;
            67) sudo timedatectl set-ntp on 2>/dev/null && echo "NTP on" ;;
            68) tar -czf "$BACKUP_DIR/home_bkp.tar.gz" /home/ 2>/dev/null && echo "Backup: $BACKUP_DIR/home_bkp.tar.gz" ;;
            69) sudo find / -type f -size +100M 2>/dev/null | head -30 ;;
            70) sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null && echo "Cache dropped" ;;
            71) crontab -e ;;
            72) crontab -l 2>/dev/null || echo "No crontab" ;;
            73) systemctl --failed 2>/dev/null ;;
            74) sudo journalctl --vacuum-time=2d 2>/dev/null ;;
            75) systemctl list-units --type=service 2>/dev/null | head -30 ;;
            76) sudo systemctl restart ssh 2>/dev/null || sudo systemctl restart sshd 2>/dev/null ;;
            77) read -rp "  Service: " s; sudo systemctl stop "$s" 2>/dev/null ;;
            78) read -rp "  Service: " s; sudo systemctl start "$s" 2>/dev/null ;;
            79) read -rp "  Service: " s; sudo systemctl enable "$s" 2>/dev/null ;;
            80) read -rp "  Service: " s; sudo systemctl disable "$s" 2>/dev/null ;;
            0) return ;;
            *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.6; continue ;;
        esac
        pause
    done
}

menu_web() {
    while true; do
        show_header
        echo -e "  ${C}◆ DOCKER & WEB OPS${NC}"
        printf "     ${G}81.${NC} %-24s ${G}91.${NC} %s\n" "Docker Version" "Nginx Status"
        printf "     ${G}82.${NC} %-24s ${G}92.${NC} %s\n" "List Containers" "Apache Status"
        printf "     ${G}83.${NC} %-24s ${G}93.${NC} %s\n" "Running Containers" "MySQL Status"
        printf "     ${G}84.${NC} %-24s ${G}94.${NC} %s\n" "Docker Images" "PHP Version"
        printf "     ${G}85.${NC} %-24s ${G}95.${NC} %s\n" "System Prune" "NodeJS Version"
        printf "     ${G}86.${NC} %-24s ${G}96.${NC} %s\n" "Stop All Containers" "Python Version"
        printf "     ${G}87.${NC} %-24s ${G}97.${NC} %s\n" "Kill All Containers" "Check Site SSL"
        printf "     ${G}88.${NC} %-24s ${G}98.${NC} %s\n" "Container Logs" "Nginx Access Logs"
        printf "     ${G}89.${NC} %-24s ${G}99.${NC} %s\n" "Docker Stats" "Nginx Error Logs"
        printf "     ${G}100.${NC} %-22s ${G}    ${NC} %s\n" "Compose Up" "Certbot Renew"
        echo ""
        echo -e "     ${R}[0]${NC} Back"
        echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
        echo -ne "  ${C}➜${NC} ${W}Select Tool${NC} ${DG}(0/81-100):${NC} "
        read -r opt
        case $opt in
            81) docker --version 2>/dev/null || echo "Docker not installed" ;;
            82) docker ps -a 2>/dev/null || echo "Docker not installed" ;;
            83) docker ps 2>/dev/null ;;
            84) docker images 2>/dev/null ;;
            85) docker system prune -f 2>/dev/null ;;
            86) docker stop $(docker ps -a -q) 2>/dev/null ;;
            87) docker kill $(docker ps -a -q) 2>/dev/null ;;
            88) read -rp "  Container ID: " i; docker logs "$i" 2>/dev/null | tail -30 ;;
            89) docker stats --no-stream 2>/dev/null ;;
            90) docker-compose up -d 2>/dev/null || docker compose up -d 2>/dev/null ;;
            91) systemctl status nginx --no-pager 2>/dev/null || echo "Nginx not found" ;;
            92) systemctl status apache2 --no-pager 2>/dev/null || systemctl status httpd --no-pager 2>/dev/null || echo "Apache not found" ;;
            93) systemctl status mysql --no-pager 2>/dev/null || systemctl status mariadb --no-pager 2>/dev/null || echo "MySQL not found" ;;
            94) php -v 2>/dev/null || echo "PHP not installed" ;;
            95) node -v 2>/dev/null || echo "Node not installed" ;;
            96) python3 --version 2>/dev/null || echo "Python3 not installed" ;;
            97) read -rp "  Domain: " d; curl -vI https://"$d" 2>&1 | grep -i "expire" ;;
            98) tail -n 20 /var/log/nginx/access.log 2>/dev/null || echo "No Nginx log" ;;
            99) tail -n 20 /var/log/nginx/error.log 2>/dev/null || echo "No Nginx log" ;;
            100) sudo certbot renew --dry-run 2>/dev/null || echo "Certbot not installed" ;;
            0) return ;;
            *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.6; continue ;;
        esac
        pause
    done
}

while true; do
    show_header
    echo -e "  ${W}SELECT A MODULE:${NC}"
    echo ""
    echo -e "     ${GR}[1]${NC} System & Hardware   ${DG}•${NC} Tools 1-20"
    echo -e "     ${GR}[2]${NC} Network & Internet  ${DG}•${NC} Tools 21-40"
    echo -e "     ${GR}[3]${NC} Security & Audit    ${DG}•${NC} Tools 41-60"
    echo -e "     ${GR}[4]${NC} Maintenance & Ops   ${DG}•${NC} Tools 61-80"
    echo -e "     ${GR}[5]${NC} Docker & Web Stack  ${DG}•${NC} Tools 81-100"
    echo ""
    echo -e "     ${R}[0]${NC} Back"
    echo -e "  ${DG}────────────────────────────────────────────────────────────────${NC}"
    echo -ne "  ${C}➜${NC} ${W}Enter Module${NC} ${DG}(0-5):${NC} "
    read -r main_opt
    case $main_opt in
        1) menu_sys ;;
        2) menu_net ;;
        3) menu_sec ;;
        4) menu_maint ;;
        5) menu_web ;;
        0) clear; exit 0 ;;
        *) echo -e "  ${R}✗ Invalid option${NC}"; sleep 0.8 ;;
    esac
done
