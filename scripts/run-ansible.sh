#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT/ansible"

ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook "$@"
