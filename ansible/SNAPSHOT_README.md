# LME Elasticsearch Snapshot Operations

This guide covers how to configure Elasticsearch snapshot repositories and create snapshots for your LME installation using Ansible playbooks.

## Overview

Elasticsearch snapshots provide point-in-time backups of your cluster's indices and state. Unlike the full LME backup (`backup_lme.yml`) which stops services and copies Podman volumes, snapshots are taken while Elasticsearch is running and are the recommended approach for:
- Pre-upgrade safety nets
- Scheduled data backups
- Disaster recovery in cluster environments

For a full cluster recovery bundle, pair snapshots with the master backup flow in
`ansible/cluster_backup_lme.yml`.

The `snapshot_elasticsearch.yml` playbook supports two repository types:
- **`fs` (filesystem)**: Default. Uses the `lme_backups` Podman volume already mounted on each node.
- **`s3`**: Uses an S3-compatible object store (AWS S3, MinIO, etc.). Requires the `repository-s3` Elasticsearch plugin.

## Prerequisites

### Filesystem (`fs`) Repositories

For **single-node** installations, no extra setup is required - the `lme_backups` volume is already configured and `path.repo` is set in `elasticsearch.yml`.

For **multi-node clusters**, the `lme_backups` Podman volume is local to each node and is **not shared**. You must provide shared storage so all nodes can access the same repository path. The most common approach is NFS:

1. Set up an NFS export on a shared server (or use the master node):
   ```bash
   # On the NFS server
   mkdir -p /srv/es-snapshots
   chown 1000:1000 /srv/es-snapshots   # Elasticsearch container UID
   echo "/srv/es-snapshots *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
   exportfs -ra
   ```

2. Mount on every Elasticsearch node:
   ```bash
   # On each node
   mkdir -p /mnt/es-snapshots
   mount -t nfs nfs-server:/srv/es-snapshots /mnt/es-snapshots
   # Add to /etc/fstab for persistence
   ```

3. Bind-mount the shared path into the Elasticsearch container (update the Quadlet unit or Podman volume configuration to point to the shared mount).

4. Run the playbook with the shared location:
   ```bash
   ansible-playbook -i ansible/inventory/cluster.yml ansible/snapshot_elasticsearch.yml \
     -e es_snapshot_fs_location=/usr/share/elasticsearch/snapshots
   ```

### S3 Repositories

S3 repositories require the `repository-s3` Elasticsearch plugin to be installed on **every** Elasticsearch node before running the playbook. The playbook does not install the plugin automatically.

1. Install the plugin inside each Elasticsearch container:
   ```bash
   podman exec lme-elasticsearch elasticsearch-plugin install repository-s3
   ```

2. Configure S3 credentials using the Elasticsearch keystore:
   ```bash
   podman exec -it lme-elasticsearch elasticsearch-keystore add s3.client.default.access_key
   podman exec -it lme-elasticsearch elasticsearch-keystore add s3.client.default.secret_key
   ```

3. Restart Elasticsearch on each node after installing the plugin and adding credentials.

## Usage

### Basic (single-node, fs repository)

The snapshot playbook targets `hosts: elasticsearch`. For single-node installs, use `ansible/inventory/single.yml`:

```bash
ansible-playbook -i ansible/inventory/single.yml ansible/snapshot_elasticsearch.yml
```

This registers the `lme_backups` repository, verifies it, and creates a timestamped snapshot.

### Register and verify repository only (no snapshot)

```bash
ansible-playbook -i ansible/inventory/single.yml ansible/snapshot_elasticsearch.yml -e create_snapshot=false
```

### Custom snapshot name

```bash
ansible-playbook -i ansible/inventory/single.yml ansible/snapshot_elasticsearch.yml -e snapshot_name=before-maintenance
```

### Cluster with filesystem repository

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/snapshot_elasticsearch.yml
```

A warning will be displayed reminding you that `fs` repositories require shared storage in multi-node clusters.

### Cluster backup bundle

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/cluster_backup_lme.yml
```

When `/mnt/es-snapshots` is mounted on the master, this workflow also exports a
copy of the master recovery bundle to:

```bash
/mnt/es-snapshots/lme-master-backups/<timestamp>
```

### S3 repository

```bash
ansible-playbook -i ansible/inventory/single.yml ansible/snapshot_elasticsearch.yml \
  -e es_snapshot_repo_type=s3 \
  -e es_s3_bucket=my-lme-snapshots \
  -e es_s3_region=us-west-2
```

With optional base path and custom endpoint (e.g., MinIO):

```bash
ansible-playbook -i ansible/inventory/single.yml ansible/snapshot_elasticsearch.yml \
  -e es_snapshot_repo_type=s3 \
  -e es_s3_bucket=my-lme-snapshots \
  -e es_s3_region=us-east-1 \
  -e es_s3_base_path=lme/snapshots \
  -e es_s3_endpoint=https://minio.example.com:9000
```

## Variable Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `es_snapshot_repo` | `lme_backups` | Repository name registered in Elasticsearch |
| `es_snapshot_repo_type` | `fs` | Repository type: `fs` or `s3` |
| `es_snapshot_fs_location` | `/usr/share/elasticsearch/backups` | Path inside the ES container for `fs` repos |
| `snapshot_name` | `lme-<timestamp>` | Name for the created snapshot |
| `create_snapshot` | `true` | Set to `false` to register/verify without creating a snapshot |
| `es_s3_bucket` | *(required for s3)* | S3 bucket name |
| `es_s3_region` | `us-east-1` | AWS region for the S3 bucket |
| `es_s3_base_path` | *(empty)* | Optional prefix path inside the bucket |
| `es_s3_endpoint` | *(empty)* | Custom S3 endpoint (for MinIO, etc.) |

## Pre-Upgrade Snapshots

The `rolling_upgrade.yml` playbook includes pre-upgrade checks (`tasks/pre_upgrade_checks.yml`) that create a snapshot before upgrading. This is enabled by default.

To skip only the snapshot (other checks-cluster health, disk space, etc.-still run):

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/rolling_upgrade.yml -e create_pre_upgrade_snapshot=false
```

To skip all pre-upgrade checks (including the snapshot):

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/rolling_upgrade.yml -e skip_pre_checks=true
```

## Troubleshooting

### Repository verification fails

- **Single-node**: Ensure the `lme_backups` Podman volume is mounted and `path.repo` is configured in `elasticsearch.yml`.
- **Cluster (fs)**: All nodes must be able to access the same physical storage at `path.repo`. Check NFS mounts.
- **S3**: Verify the `repository-s3` plugin is installed, credentials are in the keystore, and the bucket exists with proper permissions.

### Snapshot state is not SUCCESS

Check the `failures` array in the Elasticsearch response for details. Common causes:
- Disk full on the snapshot repository
- Network issues reaching S3
- Corrupted repository (run `POST /_snapshot/<repo>/_verify` to check)

### Permission errors

The Elasticsearch process runs as UID 1000 inside the container. Ensure the backup directory (or NFS mount) is owned by `1000:1000`.

## Restoring Snapshots

LME includes `ansible/restore_elasticsearch_snapshot.yml` to orchestrate
repository registration, verification, and snapshot restore.

### Playbook-driven restore

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/restore_elasticsearch_snapshot.yml \
  -e snapshot_name=SNAPSHOT_NAME \
  -e confirm_full_cluster_restore=true
```

Example: restore a single index under a new name

```bash
ansible-playbook -i ansible/inventory/cluster.yml ansible/restore_elasticsearch_snapshot.yml \
  -e snapshot_name=SNAPSHOT_NAME \
  -e restore_mode=live_cluster \
  -e restore_indices=lme-recovery-test \
  -e rename_pattern='(.+)' \
  -e rename_replacement='restored-$1'
```

Restore mode rules:
- `fresh_cluster` is the default and is intended for full rebuild/restore targets
- `live_cluster` is limited to targeted restores and requires `include_global_state=false`
- Full-cluster restore (`indices='*'` with global state) requires `-e confirm_full_cluster_restore=true`

### Manual restore

```bash
# Load credentials
source /opt/lme/scripts/extract_secrets.sh -q

# Restore snapshot (replaces existing indices with same names)
curl -sk -X POST -u "elastic:$elastic" \
  "https://localhost:9200/_snapshot/lme_backups/SNAPSHOT_NAME/_restore?wait_for_completion=false" \
  -H "Content-Type: application/json" \
  -d '{"indices": "*", "include_global_state": true}'
```

Replace `SNAPSHOT_NAME` with your snapshot name (e.g. `test-snapshot-1`). Use `wait_for_completion=true` to block until the restore finishes, or `false` to run asynchronously and monitor via `GET /_recovery` or `GET /_cat/recovery`.

### Restore options

- **`indices`**: `"*"` for all indices, or a comma-separated list (e.g. `"wazuh-alerts-*,.kibana*"`).
- **`include_global_state`**: `true` to restore cluster state (e.g. Kibana config).
- **`rename_pattern`** / **`rename_replacement`**: Restore into different index names to avoid overwriting existing indices.

### Important considerations

1. **Index conflicts**: Indices that already exist must be closed before restore, or you must use `rename_pattern`/`rename_replacement` to restore into new index names.
2. **Kibana**: Restoring `.kibana*` while Kibana is running can cause issues; consider stopping Kibana first.
3. **Version compatibility**: The snapshot must be from a compatible Elasticsearch version. See [Elasticsearch Snapshot and Restore](https://www.elastic.co/guide/en/elasticsearch/reference/current/snapshot-restore.html) for version compatibility rules.

## Related Operations

- **[Backup Operations](BACKUP_README.md)**: Full LME backup (stops services, copies volumes)
- **[Cluster Recovery](CLUSTER_RECOVERY_README.md)**: Cluster-safe backup and restore workflow
- **[Upgrade Operations](UPGRADE_README.md)**: Upgrading LME with pre-upgrade snapshot
- **[Rollback Operations](ROLLBACK_README.md)**: Restoring from backups
