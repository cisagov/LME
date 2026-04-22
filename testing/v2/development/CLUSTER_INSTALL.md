# LME Cluster Installation Guide

This guide covers manual installation of LME (Logging Made Easy) on an existing cluster of servers.

For **local multi-node testing with Docker**, use `docker-compose-cluster.yml` and the helper script **`install_cluster.sh`** in this directory. That script configures SSH between containers, **mounts NFS on every node before LME install (Phase 2.5)**, runs `./install.sh --cluster` (equivalent to Steps 1-4 below when applied inside the master container), then **Phase 4** wires Elasticsearch into that mount and restarts it. **`./install.sh --cluster` alone**-whether on real hosts or in the master container-does **not** set up NFS; you need that extra step (or your own shared storage) if you want **multi-node filesystem snapshot repositories** to work. See [Local Docker cluster (development)](#local-docker-cluster-development) below.

## Overview

LME can be deployed in cluster mode where:
- **Master node (es1)**: Runs the full LME stack (Elasticsearch, Kibana, Fleet, Wazuh)
- **Cluster nodes (es2, es3, ...)**: Run Elasticsearch only for distributed storage and search

### Cluster child quadlets

Cluster child nodes only keep the Elasticsearch quadlet dependency graph under
`/etc/containers/systemd/`. LME stages the full quadlet source tree under
`/opt/lme/quadlet-source/`, but on child nodes it only installs:

- `lme.network`
- `lme-backups.volume`
- `lme-esdata01.volume`
- `lme-kibanadata.volume`
- `lme-setup-certs.container`
- the rendered `lme-elasticsearch.container`

Non-ES quadlets such as Kibana, Fleet, Wazuh, ElastAlert, and `lme.service`
are intentionally removed from the active quadlet directory on child nodes, so
the podman systemd generator never creates those services at boot.

This keeps reboot behavior correct while preserving a future promotion path: a
promotion workflow can copy the staged files from `/opt/lme/quadlet-source/`
back into `/etc/containers/systemd/`, run `systemctl daemon-reload`, and then
enable/start the full stack.

## Prerequisites

### Infrastructure Requirements
- 3+ Linux servers (Ubuntu 20.04+ or RHEL/Rocky 8+)
- SSH access from master to all cluster nodes (passwordless recommended)
- All nodes should be able to reach each other by hostname or IP
- Minimum recommended specs per node:
  - 4 CPU cores
  - 8 GB RAM
  - 100 GB disk space

### Software Requirements (Master Node)
- `ansible` (2.9+)
- `jq`
- `git`

Install on Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install -y ansible jq git
```

## Installation Steps

### Step 1: Clone and Configure on Master

```bash
# Clone the repository
git clone https://github.com/cisagov/LME.git ~/LME
cd ~/LME

# Create environment file
cp config/example.env config/lme-environment.env

# Edit to set IPVAR to master's private IP
# Replace <MASTER_PRIVATE_IP> with your master node's IP
sed -i 's/IPVAR=.*/IPVAR=<MASTER_PRIVATE_IP>/' config/lme-environment.env
```

### Step 2: Install Ansible Dependencies

```bash
cd ~/LME/ansible
ansible-galaxy collection install -r requirements.yml
```

This installs required Ansible collections:
- `community.general` - General-purpose modules (timezone, firewall, etc.)
- `ansible.posix` - POSIX/Unix modules (sysctl, mount, etc.)

### Step 3: Create Cluster Inventory File

Create `ansible/inventory/cluster.yml` with your cluster topology:

```yaml
all:
  vars:
    # Master node IP (where Kibana/Fleet will run)
    es_master_host: 10.0.0.4

    # All node IPs for cluster discovery
    es_cluster_seed_hosts:
      - 10.0.0.4
      - 10.0.0.5
      - 10.0.0.6

  children:
    elasticsearch:
      hosts:
        # Master node - MUST be first (handles cert generation)
        es1:
          # ansible_host: IP/hostname for Ansible to SSH/connect to this node
          ansible_host: 10.0.0.4
          # ansible_connection: Use 'local' for master (no SSH), 'ssh' for remote nodes
          ansible_connection: local
          # es_node_name: The name this Elasticsearch node uses within the cluster
          es_node_name: lme-elasticsearch
          # es_is_initial_master: Set to true only for the initial master node
          es_is_initial_master: true
          # es_publish_host: IP/hostname this node advertises to other ES nodes
          # This value MUST appear in es_cluster_seed_hosts above
          es_publish_host: 10.0.0.4

        # Cluster node 2
        es2:
          # ansible_host: IP/hostname for Ansible to SSH to this node
          ansible_host: 10.0.0.5
          # ansible_user: SSH username for Ansible to connect as
          ansible_user: ubuntu
          # es_node_name: The name this Elasticsearch node uses within the cluster
          es_node_name: es2
          # es_publish_host: IP/hostname this node advertises to other ES nodes
          # This value MUST appear in es_cluster_seed_hosts above
          es_publish_host: 10.0.0.5

        # Cluster node 3
        es3:
          # ansible_host: IP/hostname for Ansible to SSH to this node
          ansible_host: 10.0.0.6
          # ansible_user: SSH username for Ansible to connect as
          ansible_user: ubuntu
          # es_node_name: The name this Elasticsearch node uses within the cluster
          es_node_name: es3
          # es_publish_host: IP/hostname this node advertises to other ES nodes
          # This value MUST appear in es_cluster_seed_hosts above
          es_publish_host: 10.0.0.6
```

**Important Notes:**
- Replace IP addresses with your actual node IPs
- Replace `ansible_user` with your SSH username
- The master (es1) **must** be listed first
- Use either all IPs or all resolvable hostnames (must be consistent)
- In most cases, `ansible_host` and `es_publish_host` will be the same IP/hostname

#### Field Relationships

```
┌───────────────────────┬──────────────────────────────────────────────┬────────────────────────────────────────┐
│         Field         │                   Purpose                    │                Used By                 │
├───────────────────────┼──────────────────────────────────────────────┼────────────────────────────────────────┤
│ es_cluster_seed_hosts │ List of all node IPs for cluster discovery  │ Elasticsearch cluster formation        │
├───────────────────────┼──────────────────────────────────────────────┼────────────────────────────────────────┤
│ ansible_host          │ Where Ansible connects to configure the node │ Ansible SSH connection                 │
├───────────────────────┼──────────────────────────────────────────────┼────────────────────────────────────────┤
│ es_publish_host       │ Where ES nodes connect to each other         │ Elasticsearch inter-node communication │
├───────────────────────┼──────────────────────────────────────────────┼────────────────────────────────────────┤
│ es_node_name          │ Logical name for the ES node                 │ Elasticsearch cluster membership       │
├───────────────────────┼──────────────────────────────────────────────┼────────────────────────────────────────┤
│ ansible_connection    │ How Ansible connects (local/ssh)             │ Ansible configuration                  │
├───────────────────────┼──────────────────────────────────────────────┼────────────────────────────────────────┤
│ ansible_user          │ SSH username                                 │ Ansible SSH authentication             │
├───────────────────────┼──────────────────────────────────────────────┼────────────────────────────────────────┤
│ es_is_initial_master  │ Initial master for bootstrap                 │ Elasticsearch first-time setup         │
└───────────────────────┴──────────────────────────────────────────────┴────────────────────────────────────────┘
```

**Key Point:** `es_cluster_seed_hosts` must contain all the `es_publish_host` values - this is how Elasticsearch nodes find each other.

In most setups:
- `ansible_host` = `es_publish_host` (same IP for both Ansible config and ES clustering)
- But they can be different if you have a separate management network

### Step 4: Run the Cluster Install

Run the full cluster installation from the master node:

```bash
cd ~/LME
./install.sh --cluster
```

This single command validates your cluster inventory, installs the full LME stack
on the master node with cluster settings, and then deploys Elasticsearch to all
cluster nodes. Seed hosts and the master publish host are derived automatically
from your `ansible/inventory/cluster.yml`.

The script will:
- Validate that the cluster inventory file exists and is well-formed
- Check SSH connectivity to all cluster nodes via Ansible ping
- Install Ansible Galaxy collections
- Run `site.yml` on the master with cluster mode enabled
- Run `elasticsearch.yml` on all cluster nodes

**Options:**
- `--cluster-inventory PATH` - use a custom inventory file (default: `ansible/inventory/cluster.yml`)
- `--cluster-master-only` - only run `site.yml` on the master (skip cluster node deployment)
- `--cluster-nodes-only` - only run `elasticsearch.yml` on cluster nodes (skip master install)
- `--debug` - enable verbose Ansible output
- `LME_CLUSTER=true` - environment variable equivalent of `--cluster`

**Note:** `--cluster` and `--offline` cannot be used together. Offline cluster
installation is not supported at this time.

### Shared snapshot storage (NFS) on real clusters

Elasticsearch **filesystem** snapshot repositories on a **multi-node** cluster require the **same** directory to be visible on **every** data node (shared disk or NFS). LME’s `ansible/snapshot_elasticsearch.yml` can register such a repo when `path.repo` and the mount layout allow it.

This guide’s Steps 1-4 do **not** configure NFS or other shared storage; that is an infrastructure choice. If you use NFS, mount it consistently on all nodes at the path you expose to the Elasticsearch containers (for example under `/opt/lme` or a dedicated mount bound into the container). The **Docker development** flow automates a minimal NFS server + client mounts in **`install_cluster.sh`** Phase 2.5 (before install), then connects Elasticsearch in Phase 4.

### Local Docker cluster (development)

From the **host** (not inside a container), with repo root available:

```bash
cd testing/v2/development
docker compose -f docker-compose-cluster.yml up -d --build
./install_cluster.sh          # SSH + NFS mounts (Phase 2.5) + install.sh --cluster + ES↔NFS (Phase 4)
# Optional: ./install_cluster.sh --skip-nfs   # skip NFS phases if you only need the stack, not shared snapshot paths
```

- `docker-compose-cluster.yml` now gives `node1`, `node2`, and `node3` separate
  Docker-backed `/var/lib/containers` mounts. Podman volumes and backup data
  therefore persist across container recreation for each node independently.
- If you need a completely clean Docker dev cluster, use
  `docker compose -f docker-compose-cluster.yml down -v` before bringing it back
  up.
- **`install_cluster.sh`** complements this document: it prepares the dev environment, **mounts NFS before LME install**, ends with the same logical install as Step 4, then **hooks Elasticsearch to that mount** (needed for **`test_snapshot.sh`** in default cluster mode and for realistic snapshot testing).
- To match this guide **literally** inside Docker (manual Steps 1-4 only, no NFS), run those commands on **`lme_cluster_node1`** after setting up SSH to the other containers yourself; snapshot playbooks that assume a **shared** repo across nodes will not verify until shared storage is added (e.g. run `./install_cluster.sh --skip-master --skip-cluster` to run only the NFS phases, or full `install_cluster.sh`).

## Verification

### Check Cluster Health

```bash
# Source the password file
source /opt/lme/scripts/extract_secrets.sh -q

# Check cluster health
curl -sk -u elastic:$elastic https://localhost:9200/_cluster/health?pretty

# View cluster nodes
curl -sk -u elastic:$elastic https://localhost:9200/_cat/nodes?v

# Check shards distribution
curl -sk -u elastic:$elastic https://localhost:9200/_cat/shards?v
```

### Verify child quadlet layout and reboot behavior

Run these checks on a cluster child node after `ansible/elasticsearch.yml` (or
the Phase 5b child section of `ansible/convert_to_cluster.yml`) completes:

```bash
# Active quadlets on the child should be ES-only.
sudo ls -1 /etc/containers/systemd

# Full source tree should still be staged locally for future promotion.
sudo ls -1 /opt/lme/quadlet-source

# Only Elasticsearch should be present in the active boot path.
systemctl list-unit-files 'lme-*'

# Elasticsearch should be healthy before reboot.
source /opt/lme/scripts/extract_secrets.sh -q
curl -sk -u elastic:$elastic https://localhost:9200/_cluster/health?pretty

# Reboot the child and repeat the ls/systemctl/curl checks.
sudo reboot
```

Expected child-node state:

- `/etc/containers/systemd` contains only the Elasticsearch dependency set plus
  the rendered `lme-elasticsearch.container`
- `/opt/lme/quadlet-source` contains the full repo quadlet tree
- Kibana/Fleet/Wazuh/ElastAlert units are not regenerated after reboot
- Cluster health and node membership stay unchanged

### Expected Output

Healthy cluster health response:
```json
{
  "cluster_name" : "lme-cluster",
  "status" : "green",
  "number_of_nodes" : 3,
  "number_of_data_nodes" : 3,
  "active_primary_shards" : X,
  "active_shards" : X,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 0
}
```

### Access Kibana

Navigate to: `https://<MASTER_IP>:5601`

Default credentials:
- Username: `elastic`
- Password: Retrieved via `source /opt/lme/scripts/extract_secrets.sh -q && echo $elastic`

## Troubleshooting

### Nodes Not Joining Cluster

Check Elasticsearch logs on each node:
```bash
sudo podman logs lme-elasticsearch
```

Common issues:
- Firewall blocking ports 9200, 9300
- `es_publish_host` not reachable from other nodes
- SSL certificate issues

### SSH Connection Issues

Test SSH connectivity from master:
```bash
ssh <ansible_user>@<node_ip> "echo Connected successfully"
```

Set up passwordless SSH if needed:
```bash
ssh-copy-id <ansible_user>@<node_ip>
```

### Certificate Issues

Certificates are generated on the master (es1) and distributed to cluster nodes.
If regeneration is needed:
```bash
# On master node
cd ~/LME
ansible-playbook -i ansible/inventory/cluster.yml ansible/elasticsearch.yml --tags certificates
```

## Architecture Details

### Port Requirements

| Port | Service | Direction | Notes |
|------|---------|-----------|-------|
| 9200 | Elasticsearch HTTP | Master ← Nodes | API access |
| 9300 | Elasticsearch Transport | Master ↔ Nodes | Cluster communication |
| 5601 | Kibana | External → Master | Web UI |
| 8220 | Fleet | Agents → Master | Agent enrollment |

### File Locations

| Path | Description |
|------|-------------|
| `/opt/lme` | Main LME installation directory |
| `/etc/lme` | Configuration and secrets |
| `/etc/lme/vault` | SSL certificates and keys |
| `/var/lib/containers/storage` | Container storage |

### Cluster Configuration

Key cluster settings (configured automatically):

- `cluster.name: lme-cluster`
- `discovery.seed_hosts: [all node IPs]`
- `cluster.initial_master_nodes: [lme-elasticsearch]` (only on initial master)
- `network.publish_host: <node's IP>` (unique per node)
- `node.roles: [master, data, ingest]` (all nodes are master-eligible)

## Scaling

### Adding Nodes to Existing Cluster

1. Add the new node to `ansible/inventory/cluster.yml`
2. Update `es_cluster_seed_hosts` to include the new node
3. Run the elasticsearch playbook:
   ```bash
   ansible-playbook -i ansible/inventory/cluster.yml ansible/elasticsearch.yml --limit <new_node_name>
   ```

### Removing Nodes

Before removing a node:
1. Migrate data away from the node
2. Remove from cluster inventory
3. Update cluster configuration on remaining nodes

### Recovering a Failed Node

If a child node (`node2`, `node3`, etc.) fails and needs to be replaced, see
[CLUSTER_NODE_RECOVERY.md](CLUSTER_NODE_RECOVERY.md) for the full procedure
covering container replacement, SSH re-establishment, Ansible rejoin, and
NFS snapshot reconfiguration.

## Additional Resources

- [Elasticsearch Cluster Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-discovery.html)
- [LME Official Documentation](https://github.com/cisagov/LME)
- [Cluster Node Recovery](CLUSTER_NODE_RECOVERY.md) - Single node failure recovery procedure
- **Docker dev cluster:** `docker-compose-cluster.yml` and **`install_cluster.sh`** (this directory) - see [Local Docker cluster (development)](#local-docker-cluster-development)
- **Docker snapshot tests:** `test_snapshot.sh` (this directory; default mode expects NFS from `install_cluster.sh`)
- **Docker cluster recovery test:** `test_cluster_backup_restore.sh` (this directory; validates cluster backup, snapshot restore, and master restore)
- **Cluster recovery QA checklist:** `CLUSTER_RECOVERY_QA_CHECKLIST.md`
- For automated Azure deployment, see: `testing/v2/installers/cluster_installer/setup_cluster.sh`
