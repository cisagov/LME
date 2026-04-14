# Cluster Admin Commands

Manual install and maintenance commands for a real LME cluster.

Unless noted otherwise, run these from the LME repo root on the master node:

```bash
cd ~/LME
```

## Initial setup

Create the environment file on the master:

```bash
cp config/example.env config/lme-environment.env
sed -i 's/IPVAR=.*/IPVAR=<MASTER_PRIVATE_IP>/' config/lme-environment.env
```

Install Ansible collections:

```bash
cd ~/LME/ansible
ansible-galaxy collection install -r requirements.yml
cd ~/LME
```

Create `ansible/inventory/cluster.yml` from `ansible/inventory/cluster_example.yml`, then run one of:

```bash
./install.sh --cluster
./install.sh --cluster --debug
./install.sh --cluster --cluster-master-only
./install.sh --cluster --cluster-nodes-only
./install.sh --cluster --cluster-inventory ansible/inventory/cluster.yml
```

## Cluster health and status

Load credentials and check cluster status:

```bash
source /opt/lme/scripts/extract_secrets.sh -q
curl -sk -u "elastic:$elastic" https://localhost:9200/_cluster/health?pretty
curl -sk -u "elastic:$elastic" https://localhost:9200/_cat/nodes?v
curl -sk -u "elastic:$elastic" https://localhost:9200/_cat/shards?v
curl -sk -u "elastic:$elastic" https://localhost:9200/_cat/indices?v
```

Check LME services on the master:

```bash
sudo systemctl status lme
sudo podman ps --format '{{.Names}}\t{{.Status}}'
```

## Password rotation

Change built-in passwords from the master.

Elastic or Kibana:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/change_passwords.yml \
  -e lme_user=elastic \
  -e lme_password='YourNewSecurePassword123!'

ansible-playbook -i ansible/inventory/cluster.yml ansible/change_passwords.yml \
  -e lme_user=kibana_system \
  -e lme_password='YourNewSecurePassword123!'
```

Wazuh users:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/change_passwords.yml \
  -e lme_user=wazuh \
  -e lme_password='YourNewSecurePassword123!'

ansible-playbook -i ansible/inventory/cluster.yml ansible/change_passwords.yml \
  -e lme_user=wazuh_api \
  -e lme_password='YourNewSecurePassword123!'
```

Offline mode:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/change_passwords.yml \
  -e lme_user=elastic \
  -e lme_password='YourNewSecurePassword123!' \
  -e offline_mode=true
```

## Snapshots

Basic cluster snapshot:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/snapshot_elasticsearch.yml
```

Register and verify the repository only:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/snapshot_elasticsearch.yml \
  -e create_snapshot=false
```

Use a custom snapshot name:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/snapshot_elasticsearch.yml \
  -e snapshot_name=before-maintenance
```

Use shared filesystem snapshot storage:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/snapshot_elasticsearch.yml \
  -e es_snapshot_fs_location=/usr/share/elasticsearch/snapshots \
  -e es_snapshot_repo=lme_nfs_backups
```

Use an S3 repository:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/snapshot_elasticsearch.yml \
  -e es_snapshot_repo_type=s3 \
  -e es_s3_bucket=my-lme-snapshots \
  -e es_s3_region=us-west-2
```

Use an S3-compatible endpoint such as MinIO:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/snapshot_elasticsearch.yml \
  -e es_snapshot_repo_type=s3 \
  -e es_s3_bucket=my-lme-snapshots \
  -e es_s3_region=us-east-1 \
  -e es_s3_base_path=lme/snapshots \
  -e es_s3_endpoint=https://minio.example.com:9000
```

Check snapshot status:

```bash
source /opt/lme/scripts/extract_secrets.sh -q
curl -sk -u "elastic:$elastic" https://localhost:9200/_snapshot/lme_backups/_all?pretty
curl -sk -u "elastic:$elastic" https://localhost:9200/_snapshot/lme_nfs_backups/_all?pretty
```

## Backup operations

Cluster-safe backup bundle:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/cluster_backup_lme.yml
```

Cluster-safe backup with shared snapshot storage:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/cluster_backup_lme.yml \
  -e es_snapshot_fs_location=/usr/share/elasticsearch/snapshots \
  -e es_snapshot_repo=lme_nfs_backups
```

Cluster-safe backup with a specific snapshot name:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/cluster_backup_lme.yml \
  -e snapshot_name=before-maintenance
```

Single-node backup commands, if needed on non-cluster installs:

```bash
cd ~/LME/ansible
ansible-playbook backup_lme.yml
ansible-playbook backup_lme.yml -e skip_prompts=true
cd ~/LME
```

Check the most recent backup bundle:

```bash
LATEST_BACKUP=$(ls -1dt /var/lib/containers/storage/backups/* | head -n1)
ls -la "$LATEST_BACKUP"
```

If shared storage is mounted, exported master recovery bundles are under:

```bash
ls -la /mnt/es-snapshots/lme-master-backups/
```

## Restore index operations

Full Elasticsearch indices restore from snapshot:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/restore_elasticsearch_snapshot.yml \
  -e snapshot_name=before-maintenance \
  -e confirm_full_cluster_restore=true
```

Restore a specific index into the live cluster:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/restore_elasticsearch_snapshot.yml \
  -e snapshot_name=before-maintenance \
  -e restore_mode=live_cluster \
  -e restore_indices=lme-recovery-test \
  -e include_global_state=false
```

Restore into renamed indices:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/restore_elasticsearch_snapshot.yml \
  -e snapshot_name=before-maintenance \
  -e restore_mode=live_cluster \
  -e restore_indices=lme-recovery-test \
  -e include_global_state=false \
  -e rename_pattern='(.+)' \
  -e rename_replacement='restored-$1'
```

Restore master/control-plane state:

```bash
ansible-playbook ansible/restore_lme_master.yml
```

Restore master state from a specific backup bundle:

```bash
ansible-playbook ansible/restore_lme_master.yml \
  -e restore_backup_dir=/mnt/es-snapshots/lme-master-backups/<timestamp>.tar.gz
```

Restore master state including Elasticsearch volumes only when explicitly needed:

```bash
ansible-playbook ansible/restore_lme_master.yml \
  -e restore_backup_dir=/mnt/es-snapshots/lme-master-backups/<timestamp>.tar.gz \
  -e restore_es_volumes=true
```

Manual Elasticsearch index restore API:

```bash
source /opt/lme/scripts/extract_secrets.sh -q
curl -sk -X POST -u "elastic:$elastic" \
  "https://localhost:9200/_snapshot/lme_backups/SNAPSHOT_NAME/_restore?wait_for_completion=false" \
  -H "Content-Type: application/json" \
  -d '{"indices":"*","include_global_state":true}'
```

Monitor restore progress:

```bash
source /opt/lme/scripts/extract_secrets.sh -q
curl -sk -u "elastic:$elastic" https://localhost:9200/_cat/recovery?v
curl -sk -u "elastic:$elastic" https://localhost:9200/_recovery?pretty
```

## Upgrade operations

Cluster rolling upgrade:

This playbook is currently marked as incomplete work. It now stops before any
shard-allocation changes or Elasticsearch restarts because the per-host image
update/tagging flow still needs to be implemented and validated.

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/rolling_upgrade.yml
```

Skip only the pre-upgrade snapshot:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/rolling_upgrade.yml \
  -e create_pre_upgrade_snapshot=false
```

Skip all pre-upgrade checks:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/rolling_upgrade.yml \
  -e skip_pre_checks=true
```

Single-node upgrade and rollback wrappers, if needed on non-cluster installs:

```bash
ansible-playbook ansible/upgrade_lme.yml
ansible-playbook ansible/rollback_lme.yml
```

## Single-node to cluster conversion

Convert an existing single-node install after creating `ansible/inventory/cluster.yml`:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/convert_to_cluster.yml
```

Non-interactive conversion:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/convert_to_cluster.yml \
  -e skip_prompts=true
```

## Certificate and node maintenance

Regenerate and distribute cluster certificates:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/elasticsearch.yml --tags certificates
```

Add or rebuild one cluster node:

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/elasticsearch.yml --limit <node_name>
```

Check for unassigned shards:

```bash
source /opt/lme/scripts/extract_secrets.sh -q
curl -sk -u "elastic:$elastic" "https://localhost:9200/_cat/shards?v&s=state" | grep UNASSIGNED
```
