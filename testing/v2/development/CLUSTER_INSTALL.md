# LME Cluster Installation Guide

This guide covers manual installation of LME (Logging Made Easy) on an existing cluster of servers.

## Overview

LME can be deployed in cluster mode where:
- **Master node (es1)**: Runs the full LME stack (Elasticsearch, Kibana, Fleet, Wazuh)
- **Cluster nodes (es2, es3, ...)**: Run Elasticsearch only for distributed storage and search

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

### Step 4: Run Main Install on Master

This installs the full LME stack on the master node:

```bash
cd ~/LME

ansible-playbook ansible/site.yml \
  -e lme_cluster_mode=true \
  -e 'es_cluster_seed_hosts=["10.0.0.4","10.0.0.5","10.0.0.6"]' \
  -e es_master_publish_host=10.0.0.4
```

**Note:** The `es_cluster_seed_hosts` values should match your inventory file.

This will:
- Install Podman and container dependencies
- Deploy Elasticsearch with cluster configuration
- Deploy Kibana, Fleet, and Wazuh
- Generate SSL certificates for the cluster
- Set up initial passwords and configuration

### Step 5: Deploy to Cluster Nodes

This distributes Elasticsearch to the remaining cluster nodes:

```bash
cd ~/LME
ansible-playbook -i ansible/inventory/cluster.yml ansible/elasticsearch.yml
```

This will:
- Copy SSL certificates from master to all nodes
- Install Elasticsearch on each cluster node
- Configure each node to join the cluster
- Start Elasticsearch services

## Verification

### Check Cluster Health

```bash
# Source the password file
source /opt/lme/scripts/extract_secrets.sh -q

# Check cluster health
curl -sk -u elastic:$lme_elastic_password https://localhost:9200/_cluster/health?pretty

# View cluster nodes
curl -sk -u elastic:$lme_elastic_password https://localhost:9200/_cat/nodes?v

# Check shards distribution
curl -sk -u elastic:$lme_elastic_password https://localhost:9200/_cat/shards?v
```

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

## Additional Resources

- [Elasticsearch Cluster Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-discovery.html)
- [LME Official Documentation](https://github.com/cisagov/LME)
- For automated Azure deployment, see: `testing/v2/installers/cluster_installer/setup_cluster.sh`
