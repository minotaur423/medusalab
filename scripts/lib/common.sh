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
