#!/usr/bin/env bash
set -Eeuo pipefail

CLUSTER_NAME="k8s-137"
KEEP_TOOLS="false"
PURGE_KUBECONFIG="false"

usage() {
    cat <<EOF
Usage: $0 [options]

Deletes the kind cluster and, unless --keep-tools is supplied, removes the
kubectl and kind binaries installed by install-kind.sh.

Options:
  --name NAME          Cluster name (default: ${CLUSTER_NAME})
  --keep-tools         Keep /usr/local/bin/kind and kubectl
  --purge-kubeconfig   Remove the kind-${CLUSTER_NAME} context and cluster entry
  --help               Show this help
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --name)
            [ "$#" -ge 2 ] || { echo "ERROR: --name requires a value." >&2; exit 1; }
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --keep-tools) KEEP_TOOLS="true"; shift ;;
        --purge-kubeconfig) PURGE_KUBECONFIG="true"; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "ERROR: Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

command -v kind >/dev/null 2>&1 || {
    echo "kind is not installed; nothing to remove from the cluster."
    exit 0
}

if kind get clusters 2>/dev/null | grep -Fxq "${CLUSTER_NAME}"; then
    kind delete cluster --name "${CLUSTER_NAME}"
else
    echo "Cluster '${CLUSTER_NAME}' does not exist."
fi

if [ "${PURGE_KUBECONFIG}" = "true" ] && command -v kubectl >/dev/null 2>&1; then
    kubectl config delete-context "kind-${CLUSTER_NAME}" 2>/dev/null || true
    kubectl config delete-cluster "kind-${CLUSTER_NAME}" 2>/dev/null || true
    kubectl config unset "users.kind-${CLUSTER_NAME}" 2>/dev/null || true
fi

if [ "${KEEP_TOOLS}" != "true" ]; then
    sudo rm -f /usr/local/bin/kind /usr/local/bin/kubectl
    echo "Removed /usr/local/bin/kind and /usr/local/bin/kubectl."
else
    echo "Kept kind and kubectl because --keep-tools was supplied."
fi

echo "Uninstall completed. Docker was left unchanged."
