#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "ansible"

echo "Installing Ansible..."

if command_exists ansible; then
    echo "Ansible already installed: $(ansible --version | head -1)"
    exit 0
fi

sudo add-apt-repository --yes ppa:ansible/ansible

sudo apt update

sudo apt install -y ansible

echo "Installed:"
ansible --version | head -3
