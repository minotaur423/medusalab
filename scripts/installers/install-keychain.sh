#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "SSH Agent Keychain"

require_sudo

if command_exists keychain; then
    log_info "keychain is already installed."
else
    sudo apt-get update
    sudo apt-get install -y keychain
fi

keychain --version
