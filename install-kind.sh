#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Install kind + kubectl and create Kubernetes 1.37 cluster
# OS: Ubuntu 24.04
# Existing Docker CE installation is preserved.
# ============================================================

KUBERNETES_VERSION="v1.37.0"
KIND_VERSION="v0.33.0"
CLUSTER_NAME="k8s-137"
KIND_NODE_IMAGE="kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cat <<EOF
Usage: $0

Installs kubectl ${KUBERNETES_VERSION}, kind ${KIND_VERSION}, and creates
the single-node '${CLUSTER_NAME}' cluster using the existing Docker daemon.

Run as a normal user. The script invokes sudo only for package installation
and installing binaries under /usr/local/bin.
EOF
    exit 0
fi

echo
echo "============================================================"
echo " kind + Kubernetes 1.37 installer"
echo "============================================================"
echo

if [ "${EUID}" -eq 0 ]; then
    echo "ERROR: Do not run this script with sudo."
    echo "Run: ./install-kind.sh"
    exit 1
fi

echo "[1/9] Detecting architecture..."
case "$(uname -m)" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *)
        echo "ERROR: Unsupported architecture: $(uname -m)"
        exit 1
        ;;
esac

echo "Architecture: ${ARCH}"

echo
echo "[2/9] Checking required packages..."
sudo apt-get update
sudo apt-get install -y curl ca-certificates

echo
echo "[3/9] Checking existing Docker installation..."
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not installed."
    echo "Install Docker CE first, then run this script again."
    exit 1
fi

docker --version

if ! sudo docker info >/dev/null 2>&1; then
    echo "ERROR: Docker daemon is not running or is inaccessible."
    echo "Try: sudo systemctl enable --now docker"
    exit 1
fi

echo "Docker daemon: OK"

echo
echo "[4/9] Checking Docker access for user ${USER}..."
DOCKER_WITHOUT_SUDO="false"

if docker info >/dev/null 2>&1; then
    echo "Docker access without sudo: OK"
    DOCKER_WITHOUT_SUDO="true"
else
    echo "Docker currently requires sudo."

    if ! getent group docker >/dev/null 2>&1; then
        echo "Creating docker group..."
        sudo groupadd docker
    fi

    if id -nG "${USER}" | grep -qw docker; then
        echo "${USER} is already configured for docker group."
    else
        echo "Adding ${USER} to docker group..."
        sudo usermod -aG docker "${USER}"
    fi

    echo "Docker group membership will be used immediately via 'sg docker'."
    echo "Log out and log back in once after the script finishes."
fi

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

echo
echo "[5/9] Installing kubectl ${KUBERNETES_VERSION}..."
curl -fL -o "${TMP_DIR}/kubectl" \
    "https://dl.k8s.io/release/${KUBERNETES_VERSION}/bin/linux/${ARCH}/kubectl"
curl -fL -o "${TMP_DIR}/kubectl.sha256" \
    "https://dl.k8s.io/release/${KUBERNETES_VERSION}/bin/linux/${ARCH}/kubectl.sha256"

EXPECTED_SHA="$(cat "${TMP_DIR}/kubectl.sha256")"
ACTUAL_SHA="$(sha256sum "${TMP_DIR}/kubectl" | awk '{print $1}')"

if [ "${EXPECTED_SHA}" != "${ACTUAL_SHA}" ]; then
    echo "ERROR: kubectl SHA256 verification failed."
    echo "Expected: ${EXPECTED_SHA}"
    echo "Actual:   ${ACTUAL_SHA}"
    exit 1
fi

echo "kubectl checksum: OK"
sudo install -o root -g root -m 0755 "${TMP_DIR}/kubectl" /usr/local/bin/kubectl
kubectl version --client

echo
echo "[6/9] Installing kind ${KIND_VERSION}..."
curl -fL -o "${TMP_DIR}/kind" \
    "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"
sudo install -o root -g root -m 0755 "${TMP_DIR}/kind" /usr/local/bin/kind
kind version

echo
echo "[7/9] Cleaning stale k3d shell state..."
hash -r 2>/dev/null || true
if command -v k3d >/dev/null 2>&1; then
    echo "WARNING: k3d still exists at: $(command -v k3d)"
else
    echo "k3d binary is not present. Good."
fi

echo
echo "Backing up kubeconfig..."
mkdir -p "${HOME}/.kube"
if [ -f "${HOME}/.kube/config" ]; then
    BACKUP_FILE="${HOME}/.kube/config.backup.$(date +%Y%m%d-%H%M%S)"
    cp "${HOME}/.kube/config" "${BACKUP_FILE}"
    echo "Backup created: ${BACKUP_FILE}"
else
    echo "No existing ~/.kube/config found."
fi

echo
echo "[8/9] Creating Kubernetes ${KUBERNETES_VERSION} cluster..."
if [ "${DOCKER_WITHOUT_SUDO}" = "true" ]; then
    EXISTING_CLUSTERS="$(kind get clusters 2>/dev/null || true)"
else
    EXISTING_CLUSTERS="$(sg docker -c 'kind get clusters' 2>/dev/null || true)"
fi

if echo "${EXISTING_CLUSTERS}" | grep -Fxq "${CLUSTER_NAME}"; then
    echo "Cluster '${CLUSTER_NAME}' already exists. Keeping it."
else
    if [ "${DOCKER_WITHOUT_SUDO}" = "true" ]; then
        kind create cluster \
            --name "${CLUSTER_NAME}" \
            --image "${KIND_NODE_IMAGE}" \
            --wait 5m
    else
        sg docker -c "kind create cluster --name ${CLUSTER_NAME} --image '${KIND_NODE_IMAGE}' --wait 5m"
    fi
fi

kubectl config use-context "kind-${CLUSTER_NAME}"

echo
echo "[9/9] Verifying Kubernetes cluster..."
echo
kubectl config current-context
kubectl cluster-info
kubectl get nodes -o wide
kubectl get nodes -o custom-columns='NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion'
kubectl get pods -n kube-system -o wide

echo
echo "============================================================"
echo " Installation completed"
echo "============================================================"
echo "Cluster:    ${CLUSTER_NAME}"
echo "Context:    kind-${CLUSTER_NAME}"
echo "Kubernetes: ${KUBERNETES_VERSION}"
echo
echo "Useful commands:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  kubectl cluster-info"
echo "  kubectl config get-contexts"
echo "  kind get clusters"
echo
echo "Delete cluster:"
echo "  kind delete cluster --name ${CLUSTER_NAME}"

if [ "${DOCKER_WITHOUT_SUDO}" != "true" ]; then
    echo
    echo "IMPORTANT: Log out and back in once so Docker group membership is active in your shell."
fi
