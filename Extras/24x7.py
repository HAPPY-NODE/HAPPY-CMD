#!/usr/bin/env python3

# ============================================================
#  HAPPY-NODE  |  24/7 Activity Generator
#  Keeps VPS active with simulated file operations
# ============================================================

import os
import sys
import random
import string
import time
import signal
import subprocess
from datetime import datetime

# ==========================================
#  COLORS
# ==========================================
class Colors:
    RED = '\033[1;91m'
    GREEN = '\033[1;92m'
    YELLOW = '\033[1;93m'
    BLUE = '\033[1;94m'
    PURPLE = '\033[1;95m'
    CYAN = '\033[1;96m'
    WHITE = '\033[1;97m'
    RESET = '\033[0m'

C = Colors()

# ==========================================
#  BANNER
# ==========================================
def banner():
    os.system('clear' if os.name != 'nt' else 'cls')
    print(f"""
{C.CYAN}╔══════════════════════════════════════════════════════════╗
║{C.WHITE}           ██╗  ██╗ █████╗ ██████╗ ██████╗ ██╗   ██╗     {C.CYAN}║
║{C.WHITE}           ██║  ██║██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝     {C.CYAN}║
║{C.WHITE}           ███████║███████║██████╔╝██████╔╝ ╚████╔╝      {C.CYAN}║
║{C.WHITE}           ██╔══██║██╔══██║██╔═══╝ ██╔═══╝   ╚██╔╝       {C.CYAN}║
║{C.WHITE}           ██║  ██║██║  ██║██║     ██║        ██║        {C.CYAN}║
║{C.WHITE}           ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝        ╚═╝        {C.CYAN}║
║{C.CYAN}                    ── 24/7 ACTIVITY GENERATOR ──          {C.CYAN}║
║{C.PURPLE}                    VPS Idle Prevention System              {C.CYAN}║
╚══════════════════════════════════════════════════════════╝{C.RESET}
""")

# ==========================================
#  STATS
# ==========================================
class Stats:
    files_created = 0
    files_edited = 0
    files_deleted = 0
    start_time = None
    running = True

stats = Stats()

def signal_handler(sig, frame):
    stats.running = False
    print(f"\n{C.YELLOW}[!] Stopping...{C.RESET}")
    cleanup()
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

# ==========================================
#  HELPERS
# ==========================================
def random_string(length=10):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

def random_filename(length=8):
    return f"{random_string(length)}.txt"

def get_uptime():
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_sec = float(f.readline().split()[0])
        hours = int(uptime_sec // 3600)
        minutes = int((uptime_sec % 3600) // 60)
        return f"{hours}h {minutes}m"
    except:
        return "N/A"

def get_disk_usage():
    try:
        st = os.statvfs('/')
        total = st.f_blocks * st.f_frsize
        free = st.f_bavail * st.f_frsize
        used = total - free
        percent = (used / total) * 100
        return f"{percent:.1f}%"
    except:
        return "N/A"

def show_stats():
    elapsed = time.time() - stats.start_time
    hours = int(elapsed // 3600)
    minutes = int((elapsed % 3600) // 60)
    seconds = int(elapsed % 60)
    
    print(f"\r{C.CYAN}┌─────────────────────────────────────────────────────┐{C.RESET}")
    print(f"{C.CYAN}│{C.WHITE}  Runtime: {C.GREEN}{hours:02d}:{minutes:02d}:{seconds:02d}{C.RESET}"
          f"{C.CYAN}  │{C.WHITE}  Created: {C.GREEN}{stats.files_created}{C.RESET}"
          f"{C.CYAN}  │{C.WHITE}  Deleted: {C.RED}{stats.files_deleted}{C.RESET}{C.CYAN}  │{C.RESET}")
    print(f"{C.CYAN}│{C.WHITE}  Disk: {C.YELLOW}{get_disk_usage()}{C.RESET}"
          f"{C.CYAN}  │{C.WHITE}  Uptime: {C.GREEN}{get_uptime()}{C.RESET}"
          f"{C.CYAN}  │{C.WHITE}  Status: {C.GREEN}ACTIVE{C.RESET}{C.CYAN}     │{C.RESET}")
    print(f"{C.CYAN}└─────────────────────────────────────────────────────┘{C.RESET}", end='')

# ==========================================
#  MAIN ACTIVITY
# ==========================================
def generate_activity(folder, interval=2):
    while stats.running:
        filename = os.path.join(folder, random_filename())
        
        # CREATE
        lines = random.randint(10, 100)
        with open(filename, 'w') as f:
            for _ in range(lines):
                f.write(random_string(100) + "\n")
        stats.files_created += 1
        
        os.system('clear' if os.name != 'nt' else 'cls')
        banner()
        show_stats()
        print(f"\n{C.GREEN}[+] Created:{C.WHITE} {os.path.basename(filename)} {C.GREEN}({lines} lines){C.RESET}")
        
        time.sleep(interval)
        
        # EDIT
        if not stats.running:
            break
        lines = random.randint(10, 100)
        with open(filename, 'w') as f:
            for _ in range(lines):
                f.write(random_string(100) + "\n")
        stats.files_edited += 1
        
        os.system('clear' if os.name != 'nt' else 'cls')
        banner()
        show_stats()
        print(f"\n{C.YELLOW}[~] Edited:{C.WHITE} {os.path.basename(filename)} {C.YELLOW}({lines} lines){C.RESET}")
        
        time.sleep(interval)
        
        # DELETE
        if not stats.running:
            break
        os.remove(filename)
        stats.files_deleted += 1
        
        os.system('clear' if os.name != 'nt' else 'cls')
        banner()
        show_stats()
        print(f"\n{C.RED}[-] Deleted:{C.WHITE} {os.path.basename(filename)}{C.RESET}")
        
        time.sleep(interval)

def cleanup():
    folder = "24"
    if os.path.exists(folder):
        for f in os.listdir(folder):
            try:
                os.remove(os.path.join(folder, f))
            except:
                pass
        try:
            os.rmdir(folder)
        except:
            pass

# ==========================================
#  MENU
# ==========================================
def main():
    banner()
    
    print(f"{C.WHITE}  Welcome to HAPPY-NODE 24/7 Activity Generator{C.RESET}")
    print(f"{C.CYAN}  ─────────────────────────────────────────────{C.RESET}")
    print()
    print(f"  {C.GREEN}[1]{C.WHITE} Start Activity Generator{C.RESET}")
    print(f"  {C.GREEN}[2]{C.WHITE} Start with Custom Interval{C.RESET}")
    print(f"  {C.RED}[0]{C.WHITE} Exit{C.RESET}")
    print()
    
    choice = input(f"  {C.CYAN}➜{C.WHITE} Select Option: {C.RESET}")
    
    if choice == "1":
        folder = "24"
        os.makedirs(folder, exist_ok=True)
        stats.start_time = time.time()
        print(f"\n{C.GREEN}[OK]{C.WHITE} Starting 24/7 activity... Press Ctrl+C to stop{C.RESET}")
        time.sleep(1)
        generate_activity(folder, interval=2)
        
    elif choice == "2":
        folder = "24"
        os.makedirs(folder, exist_ok=True)
        try:
            interval = int(input(f"  {C.CYAN}Enter interval in seconds (1-60): {C.RESET}"))
            interval = max(1, min(60, interval))
        except:
            interval = 2
        stats.start_time = time.time()
        print(f"\n{C.GREEN}[OK]{C.WHITE} Starting with {interval}s interval... Press Ctrl+C to stop{C.RESET}")
        time.sleep(1)
        generate_activity(folder, interval=interval)
        
    else:
        print(f"{C.YELLOW}Goodbye from HAPPY-NODE!{C.RESET}")
        sys.exit(0)

if __name__ == "__main__":
    main()
