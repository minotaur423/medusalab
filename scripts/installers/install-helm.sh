#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "Helm"
print_os_info

if command_exists helm; then
    log_info "Helm already installed: $(helm version --short)"
    exit 0
fi

if is_rhel_family; then
    log_info "Installing Helm from the official Helm project installer..."

    if ! command_exists curl; then
        require_sudo
        sudo dnf install -y curl
    fi

    TMP_SCRIPT="$(mktemp)"
    trap 'rm -f "$TMP_SCRIPT"' EXIT

    log_info "Downloading official Helm installer..."
    curl -fsSL \
        https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
        -o "$TMP_SCRIPT"

    chmod 700 "$TMP_SCRIPT"

    log_info "Running Helm installer..."
    "$TMP_SCRIPT"

elif is_debian_family; then
    require_sudo

    KEYRING="/usr/share/keyrings/helm.gpg"
    SOURCE_LIST="/etc/apt/sources.list.d/helm-stable-debian.list"
    HELM_APT_KEY_ID="DDF78C3E6EBB2D2CC223C95C62BA89D07698DBC6"

    log_info "Installing Helm prerequisites..."
    sudo apt update
    sudo apt install -y curl gpg apt-transport-https

    log_info "Downloading Helm signing key..."
    curl -fsSL \
        https://packages.buildkite.com/helm-linux/helm-debian/gpgkey \
        -o /tmp/helm.gpg

    log_info "Validating Helm signing key fingerprint..."
    ACTUAL_KEY_ID="$(
        gpg --show-keys --with-colons /tmp/helm.gpg |
        awk -F: '$1 == "fpr" {print $10}' |
        head -n 1
    )"

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
    echo "deb [signed-by=$KEYRING] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" |
        sudo tee "$SOURCE_LIST" >/dev/null

    sudo apt update
    sudo apt install -y helm

else
    log_error "Unsupported operating system."
    exit 1
fi

if ! command_exists helm; then
    log_error "Helm installation completed but helm was not found in PATH."
    exit 1
fi

log_info "Installed: $(helm version --short)"
