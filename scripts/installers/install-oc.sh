#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "OpenShift CLI (oc)"

if command_exists oc; then
    log_info "oc already installed:"
    oc version --client
    exit 0
fi

require_sudo

OC_VERSION="4.20.5"
ARCHIVE="openshift-client-linux.tar.gz"
DOWNLOAD_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_VERSION}/${ARCHIVE}"
TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

log_info "Downloading OpenShift CLI ${OC_VERSION}..."
curl -fsSL "$DOWNLOAD_URL" -o "$TEMP_DIR/$ARCHIVE"

log_info "Extracting OpenShift CLI..."
tar -xzf "$TEMP_DIR/$ARCHIVE" -C "$TEMP_DIR"

log_info "Installing oc to /usr/local/bin..."
sudo install -m 0755 "$TEMP_DIR/oc" /usr/local/bin/oc

log_info "Installed:"
oc version --client
