#!/usr/bin/env bash
set -euo pipefail

echo "Installing Ansible..."

if command -v ansible >/dev/null 2>&1; then
    echo "Ansible already installed: $(ansible --version | head -1)"
    exit 0
fi

sudo add-apt-repository --yes ppa:ansible/ansible

sudo apt update

sudo apt install -y ansible

echo "Installed:"
ansible --version | head -3
