#!/usr/bin/env bash

log_info() {
    echo "[INFO] $*"
}

log_warn() {
    echo "[WARN] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

require_sudo() {
    log_info "Requesting administrator privileges..."
    sudo -v
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

print_header() {
    echo
    echo "==========================================="
    echo "MedusaLab Installer: $1"
    echo "==========================================="
}

detect_os() {
    if [[ ! -r /etc/os-release ]]; then
        log_error "Unable to determine operating system."
        return 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    OS_ID="${ID:-unknown}"
    OS_ID_LIKE="${ID_LIKE:-}"
    OS_VERSION_ID="${VERSION_ID:-unknown}"
}

is_rhel_family() {
    detect_os

    [[ "$OS_ID" == "rhel" ]] ||
    [[ "$OS_ID" == "centos" ]] ||
    [[ "$OS_ID" == "rocky" ]] ||
    [[ "$OS_ID" == "almalinux" ]] ||
    [[ "$OS_ID_LIKE" == *"rhel"* ]] ||
    [[ "$OS_ID_LIKE" == *"fedora"* ]]
}

is_debian_family() {
    detect_os

    [[ "$OS_ID" == "debian" ]] ||
    [[ "$OS_ID" == "ubuntu" ]] ||
    [[ "$OS_ID_LIKE" == *"debian"* ]]
}

print_os_info() {
    detect_os
    log_info "Detected OS: ${OS_ID} ${OS_VERSION_ID}"
}
