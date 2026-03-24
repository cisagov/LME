# Cluster Installer Testing

Manual testing workflow for multi-node LME cluster installations using Ansible.

## Prerequisites

- Azure CLI authenticated (`az login`)
- SSH key pair (`~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`)
- `jq` and `sshpass` installed locally

## 0. Set Environment Variables

Create `exporter.txt` in the installers directory with your settings:

```bash
export RESOURCE_GROUP="my-cluster-rg"
export PUBLIC_IP="YOUR_IP/32"  # Get from https://www.whatismyip.com/
export VM_SIZE="Standard_E2d_v4"
export LOCATION="westus"
export AUTO_SHUTDOWN_TIME="00:00"
export LME_USER="lme-user"
export BRANCH="your-branch-name"  # git rev-parse --abbrev-ref HEAD
export CLUSTER_SIZE=3  # Optional, defaults to 3
```

## 1. Run the Automated Script (Recommended)

The script automates all steps below. Run from the cluster_installer directory:

```bash
cd testing/v2/installers/cluster_installer
./setup_cluster.sh
```

With debug mode (verbose ansible output):

```bash
./setup_cluster.sh -d
```

The script will:
1. Source `exporter.txt` from the parent directory
2. Set up Python venv and install Azure requirements
3. Build Azure VMs using `build_azure_linux_network.py`
4. Wait for SSH to be ready on all VMs
5. Copy your local SSH key to all machines
6. Generate SSH key on master and distribute to cluster nodes
7. Wait for network connectivity, then clone LME repo
8. Create `lme-environment.env` with master's private IP
9. Create cluster inventory on master
10. Run `install.sh --cluster` (installs ansible, validates inventory, runs `site.yml` + `elasticsearch.yml`)
11. Set up NFS (master as NFS server, all nodes mount shared snapshot storage)

Options: `--skip-nfs` to skip NFS setup, `--nfs-only` to run only NFS setup on an existing cluster.

The Azure script writes credentials under `testing/v2/installers/` first;
`setup_cluster.sh` then copies them to `output/`. For any manual steps you run
from `cluster_installer/`, use `output/${RESOURCE_GROUP}.password.txt` and
`output/${RESOURCE_GROUP}.machines.json` so edits (for example cluster recovery)
do not diverge from stale copies in the parent directory.

## 2. Test Snapshots (Optional)

After the cluster is running (with NFS), test the snapshot playbooks:

```bash
./test_snapshot.sh
```

With debug or single-node mode:

```bash
./test_snapshot.sh -d
./test_snapshot.sh --single-node   # Skip cluster/NFS tests
```

## 3. Test Password Change (Optional)

After the cluster is running, you can test the `change_passwords.yml` playbook:

```bash
./test_change_passwords.sh
```

With a specific resource group or debug output:

```bash
./test_change_passwords.sh -r my-cluster-rg
./test_change_passwords.sh -d
```

The test looks up `${RESOURCE_GROUP}.password.txt` and `${RESOURCE_GROUP}.machines.json` in `output/` first, then the parent installers directory. Prefer keeping the canonical copies in `output/` when you edit them. It runs the same steps as the Docker-based `testing/v2/development/test_change_passwords.sh`: change elastic password, verify it works, verify secrets on nodes, then restore the original password.

## Manual Steps (Alternative)

If you prefer to run steps manually, follow the sections below.

### 1. Build the Cluster

```bash
cd testing/v2/installers
source exporter.txt

./azure/build_azure_linux_network.py \
    -g $RESOURCE_GROUP \
    -s $PUBLIC_IP \
    -vs $VM_SIZE \
    -l $LOCATION \
    -ast $AUTO_SHUTDOWN_TIME \
    -c 3 \
    -w \
    -y
```

The `-w` flag adds a Windows server for testing agent enrollment.

Wait at least 2 minutes after the build completes for VMs to fully boot before proceeding. SSH connections will fail if VMs are not ready.

Set additional variables after build:

```bash
export PASSWORD=$(cat ${RESOURCE_GROUP}.password.txt)
export MASTER_IP=$(jq -r '.linux_vms[0].ip_address' ${RESOURCE_GROUP}.machines.json)
```

### 2. Copy SSH Key to All Machines

```bash
for IP in $(jq -r '.linux_vms[].ip_address' ${RESOURCE_GROUP}.machines.json); do
    sshpass -p "$PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no ${LME_USER}@${IP}
done
```

### 3. Generate and Distribute Master Keys

SSH into master:

```bash
ssh ${LME_USER}@${MASTER_IP}
```

On master, generate a passwordless SSH key:

```bash
ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa -q
```

Install sshpass and copy key to cluster nodes:

```bash
sudo apt-get update && sudo apt-get install -y sshpass
sshpass -p 'PASSWORD' ssh-copy-id -o StrictHostKeyChecking=no lme-user@10.1.0.10
sshpass -p 'PASSWORD' ssh-copy-id -o StrictHostKeyChecking=no lme-user@10.1.0.11
```

Test passwordless SSH:

```bash
ssh lme-user@10.1.0.10 "hostname"
```

### 4. Clone Repo and Checkout Branch

On master:

```bash
git clone https://github.com/cisagov/LME.git ~/LME
cd ~/LME && git checkout ${BRANCH}
```

### 5. Create Environment File

On master, create the environment file with the master's private IP:

```bash
cp ~/LME/config/example.env ~/LME/config/lme-environment.env
sed -i 's/IPVAR=.*/IPVAR=10.1.0.5/' ~/LME/config/lme-environment.env
```

### 6. Install Dependencies on Master

```bash
sudo apt-get install -y jq
```

### 7. Create Cluster Inventory

Create inventory file at `~/LME/ansible/inventory/cluster.yml`:

```yaml
all:
  vars:
    es_master_host: 10.1.0.5
    es_cluster_seed_hosts:
      - 10.1.0.5
      - 10.1.0.10
      - 10.1.0.11

  children:
    elasticsearch:
      hosts:
        # Master must be first (handles cert generation)
        es1:
          ansible_host: 10.1.0.5
          ansible_connection: local
          es_node_name: lme-elasticsearch
          es_is_initial_master: true
          es_publish_host: 10.1.0.5
        es2:
          ansible_host: 10.1.0.10
          ansible_user: lme-user
          es_node_name: es2
          es_publish_host: 10.1.0.10
        es3:
          ansible_host: 10.1.0.11
          ansible_user: lme-user
          es_node_name: es3
          es_publish_host: 10.1.0.11
```

Replace IPs with your actual node private IPs. The `es_cluster_seed_hosts` values must match the `es_publish_host` values.

### 8. Run Cluster Install

```bash
cd ~/LME && ./install.sh --cluster
```

This handles ansible installation, Galaxy collections, inventory validation, SSH connectivity
checks, running `site.yml` on the master (cluster mode), and `elasticsearch.yml` on all cluster
nodes. Use `--debug` for verbose output.

## Cleanup

```bash
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

## Cluster Node Recovery (Azure)

To simulate and recover from a node failure in an Azure cluster, see
[CLUSTER_NODE_RECOVERY_AZURE.md](CLUSTER_NODE_RECOVERY_AZURE.md). That guide
covers building a 3-node cluster with a spare VM, failing a node, then
replacing it with the spare by updating the Ansible inventory and Elasticsearch
discovery configuration from scratch.

## Notes

- Master private IP: `10.1.0.5`
- Additional node private IPs: `10.1.0.10`, `10.1.0.11`, etc.
- Use `CLUSTER_SIZE` in exporter.txt to control number of nodes (default: 3)
- Ansible runs without sudo and elevates internally with `become: yes`
- Secrets are distributed from master to all cluster nodes
