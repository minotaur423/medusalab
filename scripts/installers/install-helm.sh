#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "Helm"

if command_exists helm; then
    log_info "Helm already installed: $(helm version --short)"
    exit 0
fi

require_sudo

KEYRING="/usr/share/keyrings/helm.gpg"
SOURCE_LIST="/etc/apt/sources.list.d/helm-stable-debian.list"
HELM_APT_KEY_ID="DDF78C3E6EBB2D2CC223C95C62BA89D07698DBC6"

log_info "Installing Helm prerequisites..."
sudo apt update
sudo apt install -y curl gpg apt-transport-https

log_info "Downloading Helm signing key..."
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey -o /tmp/helm.gpg

log_info "Validating Helm signing key fingerprint..."
ACTUAL_KEY_ID="$(gpg --show-keys --with-colons /tmp/helm.gpg | awk -F: '$1 == "fpr" {print $10}' | head -n 1)"

if [[ "$ACTUAL_KEY_ID" != "$HELM_APT_KEY_ID" ]]; then
    log_error "Unexpected Helm APT key fingerprint: $ACTUAL_KEY_ID"
    rm -f /tmp/helm.gpg
    exit 1
fi

log_info "Adding Helm signing key..."
gpg --dearmor /tmp/helm.gpg
sudo mv /tmp/helm.gpg.gpg "$KEYRING"
rm -f /tmp/helm.gpg

log_info "Adding Helm APT repository..."
echo "deb [signed-by=$KEYRING] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | \
    sudo tee "$SOURCE_LIST" >/dev/null

sudo apt update
sudo apt install -y helm

log_info "Installed: $(helm version --short)"
