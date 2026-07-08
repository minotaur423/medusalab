#!/usr/bin/env bash
set -euo pipefail

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

echo "Bootstrap complete."
