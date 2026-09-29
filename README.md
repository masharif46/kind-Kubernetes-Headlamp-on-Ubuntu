# kind + Kubernetes 1.37 + Headlamp on Ubuntu 24.04

A Git-ready toolkit for installing **kubectl 1.37.0** and **kind v0.33.0**, then creating and managing local Kubernetes **1.37** clusters on **Ubuntu 24.04** with an existing Docker CE installation. It supports single-node development clusters, multinode clusters, three-control-plane HA test clusters, Headlamp GUI management, cluster removal, kubeconfig cleanup, repeatable lifecycle testing, and automated GitHub/GitLab validation.

## Quick start

This is the recommended path for a new Ubuntu 24.04 workstation:

```bash
# 1. Install kind, kubectl, and the default single-node cluster
bash install-kind.sh

# 2. Optional: install the Headlamp Kubernetes GUI
bash install-headlamp.sh

# 3. Optional: start Headlamp
flatpak run io.kinvolk.Headlamp
```

The default cluster is named `k8s-137` and uses the context
`kind-k8s-137`. You do not need to run every script in this repository.

## Documentation map

| Need | Read or run |
|---|---|
| First installation | `install-kind.sh` and [Installation](#installation) |
| Choose a cluster layout | [Cluster layouts](#cluster-layouts) |
| Install a GUI | [Headlamp GUI](#headlamp-gui) |
| Run validation | [Testing](#testing) |
| Remove resources | [Cleanup](#cleanup) |
| Fix common problems | [Troubleshooting](#troubleshooting) |

> The detailed command reference and troubleshooting notes remain below for
> users who need them. Start with the sections above for the normal workflow.

> This repository intentionally does **not** install `docker.io`, `containerd`, or replace your existing Docker installation. This avoids package conflicts on systems already using Docker CE and `containerd.io`.

## What this repository contains

- `install-kind.sh` - installs `kubectl`, installs `kind`, creates a Kubernetes 1.37 cluster, and verifies it.
- `cluster-kind.sh` - creates, removes, lists, and checks single-node, multi-node, and HA clusters.
- `test-ha.sh` - creates a temporary HA cluster, validates all six nodes, and cleans it up.
- `install-headlamp.sh` - installs the Headlamp Kubernetes GUI through Flatpak on Ubuntu.
- `uninstall-kind.sh` - removes a cluster and optionally removes the installed `kind` and `kubectl` binaries.
- `kind-multinode.yaml` - sample 3-node kind cluster definition with 1 control-plane and 2 workers.
- `kind-ha.yaml` - sample HA definition with 3 control-plane and 3 worker nodes.
- `.gitignore` - basic Git ignore rules.

## Which script should I run?

You do **not** need to run every script. Use the scripts according to your
goal:

| Goal | Script | When to use it |
|---|---|---|
| First installation | `install-kind.sh` | Run once to install `kubectl`, install `kind`, and create the default `k8s-137` cluster. |
| Create or switch cluster type | `cluster-kind.sh` | Use later to create single-node, multinode, or HA clusters. |
| Test HA automatically | `test-ha.sh` | Optional. Creates a temporary HA cluster, validates it, and removes it automatically. |
| Install a GUI | `install-headlamp.sh` | Optional. Installs the Headlamp Kubernetes GUI through Flatpak. |
| Remove a cluster/tools | `uninstall-kind.sh` | Use only when you want to remove a cluster or uninstall `kind`/`kubectl`. |

## Developer commands

The Makefile provides shorter, repeatable commands for common development
tasks:

```bash
make help
make install
make gui
make create MODE=single NAME=single-dev
make create MODE=multinode NAME=dev
make create MODE=ha NAME=ha
make status NAME=dev
make clusters
make remove NAME=dev
make test-ha
make validate
```

`make validate` checks Bash syntax and runs ShellCheck when it is installed.
GitHub Actions and GitLab CI run the same validation automatically for pushes
and pull requests. Cluster creation and HA tests are intentionally not run in
CI because they require Docker and modify the runner environment.

For GitLab, the pipeline is defined in `.gitlab-ci.yml` and runs:

```text
bash -n ...
shellcheck ...
```

### Normal first-time setup

For most users, run only these commands:

```bash
bash install-kind.sh
bash install-headlamp.sh       # Optional GUI
flatpak run io.kinvolk.Headlamp # Optional GUI launch
```

After installation, use `kubectl` and Headlamp with the default context
`kind-k8s-137`.

### Choose a different cluster layout

Do not run `install-kind.sh` again just to create another layout. Use
`cluster-kind.sh` instead:

```bash
# One control-plane node
bash cluster-kind.sh create single --name single-dev

# One control-plane and two workers
bash cluster-kind.sh create multinode --name dev

# Three control-plane nodes and three workers
bash cluster-kind.sh create ha --name ha
```

Remove an extra cluster when finished:

```bash
bash cluster-kind.sh remove --name dev
bash cluster-kind.sh remove --name ha
```

The default `k8s-137` cluster is kept unless you explicitly remove it.

## Tested environment

- Ubuntu 24.04 LTS
- Linux amd64
- Existing Docker CE installation
- Kubernetes `v1.37.0`
- kind `v0.33.0`

The installer also supports Linux `arm64` / `aarch64`.

---

## Prerequisites

Docker must already be installed and the Docker daemon must be running.

Check Docker:

```bash
docker --version
sudo docker version
sudo docker info
```

Start Docker if needed:

```bash
sudo systemctl enable --now docker
```

Check its service status:

```bash
sudo systemctl status docker --no-pager
```

---

## Installation

Clone your repository:

```bash
git clone git@github.com:masharif46/kind-Kubernetes-Headlamp-on-Ubuntu.git
cd kind-Kubernetes-Headlamp-on-Ubuntu
```

Or, if GitHub CLI is installed:

```bash
gh repo clone masharif46/kind-Kubernetes-Headlamp-on-Ubuntu.git
cd kind-Kubernetes-Headlamp-on-Ubuntu
```

Make the installer executable:

```bash
chmod +x install-kind.sh
```

Run it as your **normal user**:

```bash
./install-kind.sh
```

Do **not** run the entire installer with `sudo`:

```bash
# Do not use this
sudo ./install-kind.sh
```

The script uses `sudo` only where elevated permissions are required.

---

## What the installer does

The script performs the following steps:

1. Detects `amd64` or `arm64` architecture.
2. Installs only basic prerequisites such as `curl` and `ca-certificates`.
3. Checks the existing Docker installation and Docker daemon.
4. Configures Docker group access when necessary.
5. Downloads and verifies `kubectl v1.37.0`.
6. Installs `kind v0.33.0`.
7. Clears stale Bash command cache entries left by a removed `k3d` binary.
8. Backs up the existing kubeconfig.
9. Creates a kind cluster named `k8s-137` running Kubernetes `v1.37.0`.
10. Selects the `kind-k8s-137` context and verifies the cluster.

---

## Verify installation

Check the client tools:

```bash
docker --version
kubectl version --client
kind version
```

Check clusters:

```bash
kind get clusters
```

Expected cluster:

```text
k8s-137
```

Check the current Kubernetes context:

```bash
kubectl config current-context
```

Expected:

```text
kind-k8s-137
```

Check nodes:

```bash
kubectl get nodes -o wide
```

Check Kubernetes version on the node:

```bash
kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion'
```

Expected version:

```text
v1.37.0
```

Check all pods:

```bash
kubectl get pods -A
```

Check cluster information:

```bash
kubectl cluster-info
```

## Resource usage and troubleshooting commands

Use these commands to identify the active cluster, inspect nodes and pods, and
check CPU, memory, storage, and recent Kubernetes events.

### Check the active cluster

```bash
# Current kubectl context
kubectl config current-context

# All configured contexts
kubectl config get-contexts

# All kind clusters on this Docker host
kind get clusters

# Cluster API and control-plane endpoints
kubectl cluster-info
```

Expected default context:

```text
kind-k8s-137
```

Switch context when multiple clusters exist:

```bash
kubectl config use-context kind-k8s-137
```

### Check host CPU, RAM, and disk

Run these commands on the Ubuntu host:

```bash
# Memory usage
free -h

# CPU count and load
nproc
uptime

# CPU and memory details
lscpu

# Disk usage
df -h

# Interactive process usage
top
```

For Docker container resource usage:

```bash
docker stats
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

### Check Kubernetes nodes

```bash
# Node status, roles, and Kubernetes version
kubectl get nodes -o wide

# Detailed information for one node
kubectl describe node <node-name>

# Node conditions and allocatable resources
kubectl get nodes -o custom-columns='NAME:.metadata.name,STATUS:.status.conditions[-1].type,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory'
```

### Check pods and their placement

```bash
# All pods in every namespace
kubectl get pods -A -o wide

# Pods in one namespace
kubectl get pods -n <namespace> -o wide

# Detailed pod information and recent events
kubectl describe pod <pod-name> -n <namespace>

# Logs from a pod
kubectl logs <pod-name> -n <namespace>

# Follow live logs
kubectl logs -f <pod-name> -n <namespace>
```

Find pods that are not running or ready:

```bash
kubectl get pods -A | grep -Ev 'Running|Completed'
```

### Check live CPU and memory usage

If Metrics Server is installed:

```bash
kubectl top nodes
kubectl top pods -A
kubectl top pod <pod-name> -n <namespace> --containers
```

If `kubectl top` returns `Metrics API not available`, Metrics Server is not
installed or is not ready. Check its status with:

```bash
kubectl get deployment metrics-server -n kube-system
kubectl get pods -n kube-system | grep metrics
```

The `docker stats` command can still show container CPU and memory usage when
Metrics Server is unavailable.

### Check cluster events and workload health

```bash
# Recent warning events across the cluster
kubectl get events -A --sort-by='.lastTimestamp'

# Recent events in one namespace
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Workload status
kubectl get deployments,statefulsets,daemonsets -A

# Services and endpoints
kubectl get svc,endpoints -A
```

Common status meanings:

| Status | Meaning |
|---|---|
| `Pending` | The pod cannot be scheduled or is waiting for a resource/image. |
| `ContainerCreating` | Kubernetes is creating the container or network. |
| `CrashLoopBackOff` | The container starts and repeatedly crashes. |
| `ImagePullBackOff` | Kubernetes cannot pull the requested image. |
| `NotReady` | A node or pod failed one or more readiness checks. |
| `Running` | The pod is running, but check the `READY` column as well. |

---

## Common kind commands

List kind clusters:

```bash
kind get clusters
```

Create a default cluster:

```bash
kind create cluster
```

Create a named cluster:

```bash
kind create cluster --name dev
```

Create a Kubernetes 1.37 cluster explicitly:

```bash
kind create cluster \
  --name k8s-137 \
  --image kindest/node:v1.37.0
```

Delete the main cluster:

```bash
kind delete cluster --name k8s-137
```

Delete another named cluster:

```bash
kind delete cluster --name dev
```

Export kubeconfig for an existing kind cluster:

```bash
kind export kubeconfig --name k8s-137
```

Get kind node containers:

```bash
docker ps --filter name=k8s-137
```

View all Docker containers:

```bash
docker ps -a
```

---

## Common kubectl commands

## Cluster information

```bash
kubectl cluster-info
kubectl version
kubectl get nodes
kubectl get nodes -o wide
```

## Contexts

List contexts:

```bash
kubectl config get-contexts
```

Show the current context:

```bash
kubectl config current-context
```

## Cluster layouts

The installer creates the default single-control-plane cluster named `k8s-137`.
For other layouts, use the cluster helper:

```bash
# Single node: one control-plane node
bash cluster-kind.sh create single

# Multi-node: one control-plane and two workers
bash cluster-kind.sh create multinode --name dev

# HA: three control-plane nodes and three workers
bash cluster-kind.sh create ha --name ha
```

The HA layout is intended for local high-availability testing. It is not a
production HA deployment.

Useful management commands:

```bash
bash cluster-kind.sh list
bash cluster-kind.sh status --name ha
bash cluster-kind.sh remove --name ha
```

Each cluster name must be unique. Remove an existing cluster before creating
another cluster with the same name.

## Cleanup

Remove the default cluster and the `kind`/`kubectl` binaries installed by this
repository:

```bash
bash uninstall-kind.sh
```

Remove only the cluster and keep the tools:

```bash
bash uninstall-kind.sh --keep-tools
```

Also remove the cluster's entries from kubeconfig:

```bash
bash uninstall-kind.sh --purge-kubeconfig
```

The uninstaller does not remove Docker, Docker data, or unrelated Kubernetes
contexts. It uses `sudo` only to remove `/usr/local/bin/kind` and
`/usr/local/bin/kubectl` unless `--keep-tools` is supplied.

## Testing

The scripts were tested on Ubuntu 24.04 with Docker CE, kind `v0.33.0`, and
Kubernetes `v1.37.0`.

### Installer test

```bash
bash install-kind.sh --help
bash install-kind.sh
```

Verified successfully:

- Docker daemon detected and accessible without `sudo`.
- `kubectl v1.37.0` downloaded and SHA256 verified.
- `kind v0.33.0` installed.
- Existing kubeconfig backed up before cluster work.
- Cluster `k8s-137` selected as context `kind-k8s-137`.
- Kubernetes control plane and CoreDNS reported healthy.
- Cluster node reported `Ready` with Kubernetes version `v1.37.0`.

The installer intentionally leaves an existing `k8s-137` cluster in place.

### Cluster lifecycle tests

The following temporary clusters were created and removed successfully:

```bash
bash cluster-kind.sh create single --name test-single
bash cluster-kind.sh status --name test-single
bash cluster-kind.sh remove --name test-single

bash cluster-kind.sh create multinode --name test-multinode
bash cluster-kind.sh status --name test-multinode
bash cluster-kind.sh remove --name test-multinode

bash cluster-kind.sh create ha --name test-ha
bash cluster-kind.sh status --name test-ha
bash cluster-kind.sh remove --name test-ha
```

The tested layouts were:

| Layout | Control-plane nodes | Worker nodes | Result |
|---|---:|---:|---|
| Single | 1 | 0 | All nodes Ready |
| Multinode | 1 | 2 | All nodes Ready |
| HA | 3 | 3 | All nodes Ready |

The create command waits for every node to report `Ready` before displaying
the final node status.

For an automated HA test that creates and removes its own temporary cluster,
run:

```bash
bash test-ha.sh
```

The test expects exactly three control-plane nodes and three worker nodes. To
use a different temporary cluster name:

```bash
HA_TEST_CLUSTER_NAME=my-ha-test bash test-ha.sh
```

The automated HA test was executed successfully and verified:

```text
Control-plane nodes: 3
Worker nodes:        3
Total Ready nodes:   6
HA test passed.
```

The test cleanup removed the temporary `ha-test` cluster after validation.

### Headlamp GUI installation test

The Headlamp installer was tested on Ubuntu 24.04:

```bash
bash install-headlamp.sh
flatpak info --system io.kinvolk.Headlamp
kubectl config current-context
```

Verified successfully:

- Flatpak was installed when it was not already present.
- Flathub was configured with the required elevated permission.
- Headlamp `0.45.0` was installed system-wide.
- Headlamp can read the kubeconfig at `~/.kube/config`.
- The active Kubernetes context is `kind-k8s-137`.
- The `k8s-137` control-plane node is `Ready` on Kubernetes `v1.37.0`.

Start the GUI with:

```bash
flatpak run io.kinvolk.Headlamp
```

### Uninstaller test

The uninstaller was tested without removing the installed tools:

```bash
bash cluster-kind.sh create single --name test-uninstall
bash uninstall-kind.sh \
  --name test-uninstall \
  --keep-tools \
  --purge-kubeconfig
```

Verified successfully:

- Temporary cluster deleted.
- Temporary kubeconfig context, cluster, and user entries removed.
- `kind` and `kubectl` remained installed.
- Docker and the original `k8s-137` cluster were left unchanged.

After testing, `kind get clusters` showed only the original `k8s-137` cluster,
which remained `Ready`.

## Headlamp GUI

For this local kind project, **Headlamp** is the recommended GUI. Headlamp is
an official Kubernetes SIG UI project and can connect to the existing
`~/.kube/config` file without changing the cluster.

### Required files and tools

The GUI setup requires:

- A running kind cluster, normally `k8s-137`.
- `kubectl` and a valid kubeconfig file at `~/.kube/config`.
- The Kubernetes context `kind-k8s-137`.
- Headlamp Desktop installed on the host machine.

No additional Kubernetes YAML file or in-cluster installation is required for
Headlamp Desktop.

Check the context before opening Headlamp:

```bash
kubectl config current-context
kubectl config get-contexts
```

Expected context:

```text
kind-k8s-137
```

Install Headlamp Desktop from the [Headlamp documentation](https://headlamp.dev/docs/latest/).
When Headlamp starts, select or import the existing kubeconfig file:

```text
~/.kube/config
```

Then select the `kind-k8s-137` context. Headlamp can display nodes, pods,
deployments, services, namespaces, events, logs, and resource status.

This repository also includes an Ubuntu Flatpak installer:

```bash
bash install-headlamp.sh
```

The installer adds Flathub if needed and installs Headlamp without changing
the Kubernetes cluster. Start the GUI with:

```bash
flatpak run io.kinvolk.Headlamp
```

### Alternative GUI

[Lens](https://lenshq.io/download/) is another good desktop option, especially
when managing multiple Kubernetes clusters. It also uses the existing
`~/.kube/config` file.

The old Kubernetes Dashboard is not the recommended option for a new setup;
Headlamp is the preferred modern Kubernetes UI for this project.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).

Switch to the kind cluster:

```bash
kubectl config use-context kind-k8s-137
```

View the active kubeconfig:

```bash
kubectl config view
```

## Namespaces

```bash
kubectl get namespaces
kubectl get ns
```

Create a namespace:

```bash
kubectl create namespace demo
```

Delete a namespace:

```bash
kubectl delete namespace demo
```

## Pods

List pods in the current namespace:

```bash
kubectl get pods
```

List pods in all namespaces:

```bash
kubectl get pods -A
```

Show more details:

```bash
kubectl get pods -A -o wide
```

Describe a pod:

```bash
kubectl describe pod <POD_NAME> -n <NAMESPACE>
```

View pod logs:

```bash
kubectl logs <POD_NAME> -n <NAMESPACE>
```

Follow logs:

```bash
kubectl logs -f <POD_NAME> -n <NAMESPACE>
```

## Deployments

Create an nginx deployment:

```bash
kubectl create deployment nginx --image=nginx
```

Check deployments:

```bash
kubectl get deployments
```

Check pods:

```bash
kubectl get pods
```

Scale nginx to 3 replicas:

```bash
kubectl scale deployment nginx --replicas=3
```

Delete it:

```bash
kubectl delete deployment nginx
```

## Services

Expose a deployment:

```bash
kubectl expose deployment nginx \
  --port=80 \
  --target-port=80 \
  --type=ClusterIP
```

List services:

```bash
kubectl get svc
```

Delete the service:

```bash
kubectl delete svc nginx
```

## Apply YAML files

```bash
kubectl apply -f deployment.yaml
```

Delete resources from a YAML file:

```bash
kubectl delete -f deployment.yaml
```

---

# Multi-node cluster

This repository includes `kind-multinode.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

Create a 3-node Kubernetes 1.37 cluster:

```bash
kind create cluster \
  --name k8s-137-multi \
  --image kindest/node:v1.37.0 \
  --config kind-multinode.yaml
```

Check the nodes:

```bash
kubectl get nodes -o wide
```

Delete the multi-node cluster:

```bash
kind delete cluster --name k8s-137-multi
```

---

## Troubleshooting

## `containerd.io : Conflicts: containerd`

Example error:

```text
containerd.io : Conflicts: containerd
E: Error, pkgProblemResolver::Resolve generated breaks
```

This typically happens when Docker CE from Docker's official repository is already installed, but you try to install Ubuntu's `docker.io` package.

Do not install `docker.io` on this host if Docker CE already works.

Verify the current Docker installation:

```bash
docker --version
sudo docker version
sudo docker info
```

If those commands work, keep the current Docker installation and use this repository's installer.

Do **not** blindly remove `containerd.io`, especially on a host running OpenStack, Kolla, or other container workloads.

---

## `permission denied while trying to connect to the Docker daemon socket`

Check your groups:

```bash
id
```

Add your user to the Docker group:

```bash
sudo usermod -aG docker "$USER"
```

Then log out and log back in.

For a temporary shell with the Docker group active:

```bash
newgrp docker
```

Test again:

```bash
docker info
```

---

## `The connection to the server 127.0.0.1:<PORT> was refused`

This usually means `kubectl` is using an old or deleted cluster context, for example a previously removed `k3d` cluster.

Check contexts:

```bash
kubectl config get-contexts
```

Check the current context:

```bash
kubectl config current-context
```

Switch to kind:

```bash
kubectl config use-context kind-k8s-137
```

Then test:

```bash
kubectl get nodes
```

---

## Removed `k3d`, but Bash still tries `/usr/local/bin/k3d`

Example:

```text
-bash: /usr/local/bin/k3d: No such file or directory
```

Bash cached the executable location.

Clear the cache:

```bash
hash -r
```

Then check:

```bash
which k3d
```

If `k3d` was removed successfully, the command should return no path.

---

## `kind create cluster` cannot access Docker

Check Docker as your normal user:

```bash
docker info
```

If that fails but the following works:

```bash
sudo docker info
```

then fix Docker group membership:

```bash
sudo usermod -aG docker "$USER"
newgrp docker
```

Then run:

```bash
kind create cluster \
  --name k8s-137 \
  --image kindest/node:v1.37.0
```

---

## Cluster already exists

Check:

```bash
kind get clusters
```

Delete and recreate:

```bash
kind delete cluster --name k8s-137
./install-kind.sh
```

---

## Node is `NotReady`

Check nodes:

```bash
kubectl get nodes -o wide
```

Check system pods:

```bash
kubectl get pods -n kube-system -o wide
```

Describe the node:

```bash
kubectl describe node k8s-137-control-plane
```

Check the kind container logs:

```bash
docker logs k8s-137-control-plane
```

---

## Image pull problems

Test Docker networking first:

```bash
docker pull kindest/node:v1.37.0
```

Check DNS resolution:

```bash
getent hosts registry-1.docker.io
```

Check Docker daemon details:

```bash
docker info
```

If your environment uses an HTTP/HTTPS proxy, Docker may need proxy configuration at the daemon level.

---

## `kubectl` command not found after installation

Check:

```bash
ls -l /usr/local/bin/kubectl
```

Check your `PATH`:

```bash
echo "$PATH"
```

Run directly:

```bash
/usr/local/bin/kubectl version --client
```

---

## `kind` command not found after installation

Check:

```bash
ls -l /usr/local/bin/kind
```

Run directly:

```bash
/usr/local/bin/kind version
```

Clear Bash's command cache:

```bash
hash -r
```

---

## Recreate the cluster

Delete the current cluster:

```bash
kind delete cluster --name k8s-137
```

Recreate it:

```bash
./install-kind.sh
```

Or create it manually:

```bash
kind create cluster \
  --name k8s-137 \
  --image kindest/node:v1.37.0 \
  --wait 5m
```

---

## Complete cleanup

Delete the Kubernetes cluster:

```bash
kind delete cluster --name k8s-137
```

Remove kind:

```bash
sudo rm -f /usr/local/bin/kind
```

Remove kubectl installed by this repository:

```bash
sudo rm -f /usr/local/bin/kubectl
```

Clear the Bash command cache:

```bash
hash -r
```

This cleanup intentionally does **not** remove Docker.

---

## Useful Docker commands for kind

List kind containers:

```bash
docker ps --filter name=k8s-137
```

Inspect the control-plane container:

```bash
docker inspect k8s-137-control-plane
```

View logs:

```bash
docker logs k8s-137-control-plane
```

Open a shell inside the kind control-plane node:

```bash
docker exec -it k8s-137-control-plane bash
```

Check disk usage:

```bash
docker system df
```

---

## Kubeconfig backup

Before creating the cluster, `install-kind.sh` backs up an existing kubeconfig file in this format:

```text
~/.kube/config.backup.YYYYMMDD-HHMMSS
```

List backups:

```bash
ls -lh ~/.kube/config.backup.*
```

To restore one manually:

```bash
cp ~/.kube/config.backup.YYYYMMDD-HHMMSS ~/.kube/config
```

Replace the timestamp with the backup you want to restore.

---

## Quick command reference

```bash
# Docker
docker --version
docker info
docker ps

# kind
kind version
kind get clusters
kind create cluster --name k8s-137 --image kindest/node:v1.37.0
kind delete cluster --name k8s-137

# kubectl
kubectl version --client
kubectl config get-contexts
kubectl config use-context kind-k8s-137
kubectl get nodes -o wide
kubectl get pods -A
kubectl cluster-info
```

---

## Notes for OpenStack / Kolla hosts

If this Ubuntu machine also runs OpenStack/Kolla or other important Docker workloads, avoid changing or replacing the Docker/containerd packages unless you understand the impact.

This repository is deliberately designed to reuse the existing Docker Engine instead of replacing it.

Before major Docker changes, check running containers:

```bash
docker ps
```

and installed packages:

```bash
dpkg -l | grep -E 'docker|containerd' | grep '^ii'
```
