#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "kubectl"

echo "Installing kubectl..."

if command_exists kubectl; then
    echo "kubectl already installed: $(kubectl version --client --output=yaml | grep gitVersion | head -1 | awk '{print $2}')"
    exit 0
fi

KUBERNETES_MINOR_VERSION="v1.36"
KEYRING="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
SOURCE_LIST="/etc/apt/sources.list.d/kubernetes.list"

sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gnupg

sudo mkdir -p /etc/apt/keyrings

echo "Adding Kubernetes signing key..."
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR_VERSION}/deb/Release.key" | \
    sudo gpg --dearmor --yes -o "$KEYRING"

echo "Adding Kubernetes APT repository..."
echo "deb [signed-by=$KEYRING] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR_VERSION}/deb/ /" | \
    sudo tee "$SOURCE_LIST" >/dev/null

sudo apt update
sudo apt install -y kubectl

echo "Installed:"
kubectl version --client
