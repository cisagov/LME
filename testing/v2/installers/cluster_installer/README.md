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
9. Install ansible and run `site.yml` on master
10. Create cluster inventory and run `elasticsearch.yml` on cluster nodes
11. Set up NFS (master as NFS server, all nodes mount shared snapshot storage)

Options: `--skip-nfs` to skip NFS setup, `--nfs-only` to run only NFS setup on an existing cluster.

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

The test uses `${RESOURCE_GROUP}.password.txt` and `${RESOURCE_GROUP}.machines.json` from the `output/` directory (or parent directory). It runs the same steps as the Docker-based `testing/v2/development/test_change_passwords.sh`: change elastic password, verify it works, verify secrets on nodes, then restore the original password.

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
    -y
```

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
sudo apt-get install -y ansible jq
cd ~/LME/ansible && ansible-galaxy install -r requirements.yml
```

### 7. Install Main Server (First Node)

Run `site.yml` on master (ansible elevates with `become: yes`):

```bash
cd ~/LME && ansible-playbook ansible/site.yml
```

This installs: base → nix → podman → elasticsearch → kibana → dashboards → wazuh → fleet

### 8. Create Cluster Inventory

Create inventory file at `~/LME/ansible/inventory/cluster.yml`:

```yaml
all:
  children:
    elasticsearch:
      hosts:
        es2:
          ansible_host: 10.1.0.10
          ansible_user: lme-user
        es3:
          ansible_host: 10.1.0.11
          ansible_user: lme-user
```

### 9. Install Cluster Nodes

Run `elasticsearch.yml` against cluster nodes:

```bash
cd ~/LME && ansible-playbook -i ansible/inventory/cluster.yml ansible/elasticsearch.yml
```

This runs on each node: base → nix → podman → secrets_distribution → certs → elasticsearch

## Cleanup

```bash
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

## Notes

- Master private IP: `10.1.0.5`
- Additional node private IPs: `10.1.0.10`, `10.1.0.11`, etc.
- Use `CLUSTER_SIZE` in exporter.txt to control number of nodes (default: 3)
- Ansible runs without sudo and elevates internally with `become: yes`
- Secrets are distributed from master to all cluster nodes
