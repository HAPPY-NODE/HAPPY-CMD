#!/bin/bash

set -e

echo "🧠 Detecting OS..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "❌ OS detect nahi hua"
    exit 1
fi

echo "📌 OS Detected: $OS"

# Auto run based on OS
if [[ "$OS" == "ubuntu" ]]; then
    echo "🚀 Running Ubuntu installer..."
    bash <(curl -s $(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 --decode)/panel/mythical/Ubuntu.sh) 

elif [[ "$OS" == "debian" ]]; then
    echo "🚀 Running Debian installer..."
    bash <(curl -s $(printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 -d 2>/dev/null || printf '%s' 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL0hBUFBZLU5PREUvSEFQUFktQ01EL21haW4=' | base64 --decode)/panel/mythical/Debian.sh) 
else
    echo "❌ Unsupported OS: $OS"
    exit 1
fi

echo "✅ Done! System ready."
