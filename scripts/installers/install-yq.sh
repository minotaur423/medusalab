#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "yq"

if command_exists yq; then
    log_info "yq already installed: $(yq --version)"
    exit 0
fi

require_sudo

log_info "Downloading yq latest Linux AMD64 binary..."
curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /tmp/yq

log_info "Installing yq to /usr/local/bin..."
sudo install -m 0755 /tmp/yq /usr/local/bin/yq

rm -f /tmp/yq

log_info "Installed: $(yq --version)"
