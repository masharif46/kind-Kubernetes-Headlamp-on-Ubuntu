#!/usr/bin/env bash
set -Eeuo pipefail

KUBERNETES_VERSION="v1.37.0"
CLUSTER_NAME="k8s-137"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 <command> [options]

Commands:
  create single       Create one control-plane node (default)
  create multinode    Create one control-plane and two workers
  create ha           Create three control-plane and three worker nodes
  remove              Delete the cluster
  list                List kind clusters
  status              Show nodes and cluster information

Options:
  --name NAME         Cluster name (default: ${CLUSTER_NAME})
  --help              Show this help

Examples:
  $0 create single
  $0 create multinode --name dev
  $0 create ha --name ha
  $0 remove --name dev
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

require_commands() {
    command -v kind >/dev/null 2>&1 || die "kind is not installed. Run ./install-kind.sh first."
    command -v kubectl >/dev/null 2>&1 || die "kubectl is not installed. Run ./install-kind.sh first."
}

create_cluster() {
    local mode="${1:-single}"
    local config=""

    case "${mode}" in
        single) ;;
        multinode) config="${SCRIPT_DIR}/kind-multinode.yaml" ;;
        ha) config="${SCRIPT_DIR}/kind-ha.yaml" ;;
        *) die "Unknown cluster type: ${mode}. Use single, multinode, or ha." ;;
    esac

    if kind get clusters 2>/dev/null | grep -Fxq "${CLUSTER_NAME}"; then
        die "Cluster '${CLUSTER_NAME}' already exists. Remove it first or choose another name with --name."
    fi

    local args=(create cluster --name "${CLUSTER_NAME}" --image "kindest/node:${KUBERNETES_VERSION}")
    if [ -n "${config}" ]; then
        args+=(--config "${config}")
    fi

    kind "${args[@]}" --wait 5m
    kubectl config use-context "kind-${CLUSTER_NAME}"
    kubectl wait --for=condition=Ready nodes --all --timeout=5m
    kubectl get nodes -o wide
}

remove_cluster() {
    if kind get clusters 2>/dev/null | grep -Fxq "${CLUSTER_NAME}"; then
        kind delete cluster --name "${CLUSTER_NAME}"
    else
        echo "Cluster '${CLUSTER_NAME}' does not exist."
    fi
}

main() {
    local command="${1:-}"
    local mode="single"
    shift || true

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --name)
                [ "$#" -ge 2 ] || die "--name requires a value."
                CLUSTER_NAME="$2"
                shift 2
                ;;
            --help|-h)
                usage
                return 0
                ;;
            single|multinode|ha)
                mode="$1"
                shift
                ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    require_commands

    case "${command}" in
        create) create_cluster "${mode}" ;;
        remove|delete) remove_cluster ;;
        list) kind get clusters ;;
        status)
            kubectl config use-context "kind-${CLUSTER_NAME}"
            kubectl cluster-info
            kubectl get nodes -o wide
            ;;
        help|-h) usage ;;
        *) usage; exit 1 ;;
    esac
}

main "$@"
