#!/usr/bin/env bash
set -euo pipefail

echo "Installing PowerShell 7..."

if command -v pwsh >/dev/null 2>&1; then
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
