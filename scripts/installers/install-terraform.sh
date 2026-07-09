#!/usr/bin/env bash
set -euo pipefail

echo "Installing Terraform..."

if command -v terraform >/dev/null 2>&1; then
    echo "Terraform already installed: $(terraform version | head -1)"
    exit 0
fi

KEYRING="/usr/share/keyrings/hashicorp-archive-keyring.gpg"
SOURCE_LIST="/etc/apt/sources.list.d/hashicorp.list"

echo "Adding HashiCorp signing key..."
wget -q -O /tmp/hashicorp.gpg https://apt.releases.hashicorp.com/gpg
sudo gpg --dearmor --yes -o "$KEYRING" /tmp/hashicorp.gpg
rm -f /tmp/hashicorp.gpg

echo "Adding HashiCorp APT repository..."
echo "deb [signed-by=$KEYRING] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee "$SOURCE_LIST" >/dev/null

sudo apt update
sudo apt install -y terraform

echo "Installed:"
terraform version | head -1
