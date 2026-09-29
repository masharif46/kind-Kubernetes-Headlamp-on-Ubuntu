#!/usr/bin/env bash
set -Eeuo pipefail

HEADLAMP_APP="io.kinvolk.Headlamp"
FLATHUB_URL="https://flathub.org/repo/flathub.flatpakrepo"

usage() {
    cat <<EOF
Usage: $0

Installs the Headlamp Kubernetes GUI on Ubuntu using Flatpak.
Headlamp will use the existing kubeconfig at ~/.kube/config.

After installation, start it with:
  flatpak run ${HEADLAMP_APP}
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
fi

if [ "${EUID}" -eq 0 ]; then
    echo "ERROR: Run this script as your normal user, not with sudo." >&2
    exit 1
fi

if ! command -v flatpak >/dev/null 2>&1; then
    echo "Installing Flatpak..."
    sudo apt-get update
    sudo apt-get install -y flatpak
fi

if ! flatpak remotes --columns=name | grep -Fxq "flathub"; then
    echo "Adding the Flathub repository..."
    sudo flatpak remote-add --if-not-exists --system flathub "${FLATHUB_URL}"
fi

echo "Installing Headlamp..."
sudo flatpak install -y --system flathub "${HEADLAMP_APP}"

echo
echo "Headlamp installation completed."
echo "Start Headlamp with:"
echo "  flatpak run ${HEADLAMP_APP}"
echo
echo "Headlamp should detect:"
echo "  ${KUBECONFIG:-${HOME}/.kube/config}"
echo "Select context: kind-k8s-137"
