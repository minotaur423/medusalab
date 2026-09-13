#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "Terraform"
print_os_info

if command_exists terraform; then
    log_info "Terraform already installed: $(terraform version | head -1)"
    exit 0
fi

require_sudo

if is_rhel_family; then
    log_info "Installing Terraform from the official HashiCorp RHEL repository..."

    sudo dnf install -y yum-utils

    REPO_FILE="/etc/yum.repos.d/hashicorp.repo"

    if [[ ! -f "$REPO_FILE" ]]; then
        log_info "Adding HashiCorp RHEL repository..."

        sudo yum-config-manager --add-repo \
            https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
    else
        log_info "HashiCorp repository already configured."
    fi

    sudo dnf install -y terraform

elif is_debian_family; then
    KEYRING="/usr/share/keyrings/hashicorp-archive-keyring.gpg"
    SOURCE_LIST="/etc/apt/sources.list.d/hashicorp.list"

    sudo apt update
    sudo apt install -y wget gpg

    wget -O- https://apt.releases.hashicorp.com/gpg |
        sudo gpg --dearmor --yes -o "$KEYRING"

    echo \
        "deb [signed-by=$KEYRING] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") main" |
        sudo tee "$SOURCE_LIST" >/dev/null

    sudo apt update
    sudo apt install -y terraform

else
    log_error "Unsupported operating system."
    exit 1
fi

if ! command_exists terraform; then
    log_error "Terraform installation completed but terraform was not found in PATH."
    exit 1
fi

log_info "Installed: $(terraform version | head -1)"
