#!/usr/bin/env bash
set -euo pipefail

cd "$HOME/lab/medusalab/ansible"

ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook "$@"
