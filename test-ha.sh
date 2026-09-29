#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="${HA_TEST_CLUSTER_NAME:-ha-test}"
NODE_IMAGE="kindest/node:v1.37.0"

cleanup() {
    if command -v kind >/dev/null 2>&1 && kind get clusters 2>/dev/null | grep -Fxq "${CLUSTER_NAME}"; then
        echo "Cleaning up HA test cluster '${CLUSTER_NAME}'..."
        kind delete cluster --name "${CLUSTER_NAME}"
    fi
}
trap cleanup EXIT

command -v kind >/dev/null 2>&1 || { echo "ERROR: kind is not installed. Run ./install-kind.sh first." >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl is not installed. Run ./install-kind.sh first." >&2; exit 1; }

if kind get clusters 2>/dev/null | grep -Fxq "${CLUSTER_NAME}"; then
    echo "ERROR: cluster '${CLUSTER_NAME}' already exists. Set HA_TEST_CLUSTER_NAME to another name." >&2
    exit 1
fi

echo "Creating temporary HA cluster '${CLUSTER_NAME}'..."
kind create cluster \
    --name "${CLUSTER_NAME}" \
    --image "${NODE_IMAGE}" \
    --config "${SCRIPT_DIR}/kind-ha.yaml" \
    --wait 5m

kubectl config use-context "kind-${CLUSTER_NAME}"
kubectl wait --for=condition=Ready nodes --all --timeout=5m

CONTROL_PLANES="$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers | wc -l)"
WORKERS="$(kubectl get nodes --selector='!node-role.kubernetes.io/control-plane' --no-headers | wc -l)"
TOTAL="$(kubectl get nodes --no-headers | wc -l)"

echo "Control-plane nodes: ${CONTROL_PLANES}"
echo "Worker nodes:        ${WORKERS}"
echo "Total Ready nodes:   ${TOTAL}"
kubectl get nodes -o wide

[ "${CONTROL_PLANES}" -eq 3 ] || { echo "ERROR: expected 3 control-plane nodes." >&2; exit 1; }
[ "${WORKERS}" -eq 3 ] || { echo "ERROR: expected 3 worker nodes." >&2; exit 1; }
[ "${TOTAL}" -eq 6 ] || { echo "ERROR: expected 6 total nodes." >&2; exit 1; }

echo "HA test passed."
