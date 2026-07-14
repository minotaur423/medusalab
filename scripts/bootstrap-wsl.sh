#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

print_header "WSL Bootstrap"
require_sudo

echo "Bootstrapping MedusaLab WSL workstation..."

sudo apt update
sudo apt install -y \
  build-essential \
  curl \
  wget \
  unzip \
  zip \
  git \
  vim \
  tmux \
  jq \
  tree \
  htop \
  ca-certificates \
  gnupg \
  software-properties-common \
  bash-completion

echo "Linking dotfiles..."

ln -sf "$HOME/lab/medusalab/dotfiles/vimrc" "$HOME/.vimrc"
ln -sf "$HOME/lab/medusalab/dotfiles/tmux.conf" "$HOME/.tmux.conf"
ln -sf "$HOME/lab/medusalab/dotfiles/inputrc" "$HOME/.inputrc"

echo "Installing vendor-managed tools..."
"$HOME/lab/medusalab/scripts/installers/install-powershell.sh"
"$HOME/lab/medusalab/scripts/installers/install-ansible.sh"
"$HOME/lab/medusalab/scripts/installers/install-terraform.sh"
"$HOME/lab/medusalab/scripts/installers/install-kubectl.sh"
"$HOME/lab/medusalab/scripts/installers/install-helm.sh"
"$HOME/lab/medusalab/scripts/installers/install-k9s.sh"
"$HOME/lab/medusalab/scripts/installers/install-yq.sh"
"$HOME/lab/medusalab/scripts/installers/install-oc.sh"
"$HOME/lab/medusalab/scripts/installers/install-keychain.sh"

echo "Bootstrap complete."
