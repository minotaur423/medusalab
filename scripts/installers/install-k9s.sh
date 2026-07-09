#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "k9s"

if command_exists k9s; then
    log_info "k9s already installed: $(k9s version --short 2>/dev/null || k9s version)"
    exit 0
fi

require_sudo

K9S_VERSION="v0.51.0"
ARCHIVE="k9s_Linux_amd64.tar.gz"
DOWNLOAD_URL="https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/${ARCHIVE}"

log_info "Downloading k9s ${K9S_VERSION}..."
curl -fsSL "$DOWNLOAD_URL" -o "/tmp/$ARCHIVE"

log_info "Extracting k9s..."
tar -xzf "/tmp/$ARCHIVE" -C /tmp k9s

log_info "Installing k9s to /usr/local/bin..."
sudo install -m 0755 /tmp/k9s /usr/local/bin/k9s

rm -f "/tmp/$ARCHIVE" /tmp/k9s

log_info "Installed:"
k9s version
