#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "powershell"

echo "Installing PowerShell 7..."

if command_exists pwsh; then
    echo "PowerShell already installed: $(pwsh --version)"
    exit 0
fi

cd /tmp

wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb

sudo dpkg -i packages-microsoft-prod.deb

rm -f packages-microsoft-prod.deb

sudo apt update
sudo apt install -y powershell

echo "PowerShell installed: $(pwsh --version)"
