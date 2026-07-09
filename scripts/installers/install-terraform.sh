#!/usr/bin/env bash
set -euo pipefail

echo "Installing Terraform..."

if command -v terraform >/dev/null 2>&1; then
    echo "Terraform already installed: $(terraform version | head -1)"
    exit 0
fi

wget -O- https://apt.releases.hashicorp.com/gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt install -y terraform

terraform version
