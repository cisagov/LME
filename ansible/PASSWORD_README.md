# LME Password and Secret Rotation

This document inventories every credential the LME stack relies on at runtime,
records where each one is stored and consumed, and explains how to rotate each
one safely. Older docs only described `elastic`, `kibana_system`, `wazuh`, and
`wazuh_api`. The LLM stack added a couple of new credentials that did not
follow the existing vault pattern, so they are documented here together.

> Companion docs: [BACKUP_README.md](BACKUP_README.md),
> [CLUSTER_RECOVERY_README.md](CLUSTER_RECOVERY_README.md).

## Quick reference

| Credential | Identity / scope | Storage | How to rotate |
|------------|------------------|---------|---------------|
| `elastic` | Elasticsearch superuser | Podman shell secret backed by `/etc/lme/vault/<id>` (Ansible Vault) | `ansible-playbook ansible/change_passwords.yml -e lme_user=elastic -e lme_password=...` |
| `kibana_system` | Built-in Kibana service account | Same as `elastic` | `change_passwords.yml -e lme_user=kibana_system ...` |
| `wazuh` | Wazuh dashboard / RBAC user | Same as `elastic` | `change_passwords.yml -e lme_user=wazuh ...` (paired with `wazuh_api`) |
| `wazuh_api` | Wazuh API user | Same as `elastic` | `change_passwords.yml -e lme_user=wazuh_api ...` (paired with `wazuh`) |
| `pgvector` | PostgreSQL `lme` superuser inside `lme-pgvector` | Podman **file** secret in `/var/lib/containers/storage/secrets/<id>` | `change_passwords.yml -e lme_user=pgvector ...` |
| `llm-keys` | Cloud LLM provider keys for LiteLLM (OpenAI, Anthropic, etc.) | Encrypted bundle `/opt/lme/config/llm_keys.enc` rendered into Podman **file** secret `llm-keys` by `scripts/sync_llm_keys.py` | Manage keys via the dashboard UI (or edit `llm_keys.enc`); see [LiteLLM cloud keys](#litellm-cloud-keys-llm-keys) |
| `LITELLM_API_KEY` (`sk-lme-llama-proxy`) | Internal proxy key (LiteLLM `master_key`) | Plain string in `config/litellm_config.yaml`, mirrored in `quadlet/lme-dashboard.container` and `quadlet/lme-log-analyzer.container` | Manual edit + service restart; see [Internal LiteLLM proxy key](#internal-litellm-proxy-key) |
| Vault password | Encrypts everything in `/etc/lme/vault/` | `/etc/lme/pass.sh` (mode 0700) | Out of scope for `change_passwords.yml`; rotation requires re-encrypting every vault file |

## Inventory by service

### Elasticsearch and Kibana
- Built-in users `elastic` and `kibana_system` are stored as Podman shell
  secrets that resolve through `ansible-vault view /etc/lme/vault/<id>`.
- Initial creation: [`ansible/roles/podman/tasks/container_setup.yml`](roles/podman/tasks/container_setup.yml).
- Consumed by `lme-elasticsearch`, `lme-kibana`, `lme-fleet-server`,
  `lme-dashboard`, and `lme-log-analyzer` quadlets.

### Wazuh manager / API
- Built-in users `wazuh` and `wazuh_api` use the same shell-driver / vault
  pattern as Elasticsearch users.
- Consumed by `lme-wazuh-manager` and the Wazuh integration in Kibana.
- The Wazuh RBAC tool changes both `wazuh` and `wazuh_api` together, so
  `change_passwords.yml` always updates the paired secret on master.

### pgvector (PostgreSQL)
- The `lme-pgvector` container runs PostgreSQL 17 with the `lme` superuser and
  database `lme_vectors`.
- The password is stored in the Podman **file**-driver secret named
  `pgvector` (created in
  [`ansible/roles/podman/tasks/llama_cpp_setup.yml`](roles/podman/tasks/llama_cpp_setup.yml)).
- Mounted as `POSTGRES_PASSWORD` in `lme-pgvector` and as `PGVECTOR_PASS` in
  `lme-dashboard` and the `ingest_docs.py` job.
- File-driver secrets live under `/var/lib/containers/storage/secrets/<id>`
  rather than `/etc/lme/vault/`.
- `scripts/extract_secrets.sh` now exports `pgvector` by reading Podman with
  `podman secret inspect --showsecret pgvector`, while still skipping
  `llm-keys`.

### LLM-related credentials
The LLM stack introduced two credentials that intentionally bypass the
Ansible-vault pattern. Both are documented here so the deviation is auditable.

#### LiteLLM cloud keys (`llm-keys`)
- Holds API keys for cloud LLM providers (OpenAI, Anthropic, Azure, Bedrock,
  Vertex, etc.) used by LiteLLM at runtime.
- The encrypted source of truth is `/opt/lme/config/llm_keys.enc`. It is
  encrypted with Fernet using a PBKDF2-derived key seeded from the same
  `/etc/lme/pass.sh` vault password.
- [`scripts/sync_llm_keys.py`](../scripts/sync_llm_keys.py) decrypts that file
  and writes the result into the `llm-keys` Podman file-driver secret, which
  LiteLLM mounts at `/run/secrets/llm_keys`.
- A systemd path watcher (`lme-llm-keys.path`) triggers
  `lme-llm-keys.service`, which runs `sync_llm_keys.py` and restarts
  `lme-litellm.service` whenever `/opt/lme/config/.llm-keys-updated` is
  touched.

This is **not** a single password, so it is not part of `change_passwords.yml`.
Rotate individual provider keys through the LME dashboard's LLM keys page (the
UI updates `llm_keys.enc` and touches the trigger file), or edit the encrypted
file and re-trigger the sync manually:

```bash
sudo systemctl start lme-llm-keys.service     # or touch the trigger file
sudo journalctl -u lme-llm-keys.service -n 50
```

#### Internal LiteLLM proxy key
- LiteLLM's `master_key` is the bearer token external clients (the dashboard
  and the log analyzer) present to call the proxy.
- Default value `sk-lme-llama-proxy` is hard-coded in:
  - [`config/litellm_config.yaml`](../config/litellm_config.yaml)
  - [`quadlet/lme-dashboard.container`](../quadlet/lme-dashboard.container)
  - [`quadlet/lme-log-analyzer.container`](../quadlet/lme-log-analyzer.container)
- This is currently a static internal token and is not vault-managed. To
  rotate it, change all three files to the same new value, copy the quadlets
  to `/etc/containers/systemd/`, and restart the affected services:

```bash
sudo systemctl daemon-reload
sudo systemctl restart lme-litellm.service lme-dashboard.service lme-log-analyzer.service
```

### Vault password
- `/etc/lme/pass.sh` decrypts everything in `/etc/lme/vault/` and is the seed
  for the LLM keys Fernet wrapper.
- Rotating it requires re-encrypting every vault file with the new password
  and re-encrypting `llm_keys.enc`. There is no automated playbook for this.

## Rotating with `change_passwords.yml`

`change_passwords.yml` is the supported automation for rotating individual
account passwords. It validates the new password, optionally checks Have I
Been Pwned, applies the change in the target service, updates the matching
Podman secret, redistributes secrets to cluster nodes, restarts affected
services, and waits for cluster health.

### Supported users
- `elastic`
- `kibana_system`
- `wazuh`
- `wazuh_api`
- `pgvector`

### Examples

```bash
# Elastic superuser
ansible-playbook ansible/change_passwords.yml \
  -e lme_user=elastic -e lme_password='NewElasticPwd_123!'

# Wazuh (also rotates wazuh_api)
ansible-playbook ansible/change_passwords.yml \
  -e lme_user=wazuh -e lme_password='NewWazuhPwd_123!'

# pgvector PostgreSQL user (single-node or master)
ansible-playbook ansible/change_passwords.yml \
  -e lme_user=pgvector -e lme_password='NewPgvectorPwd_123!'

# Cluster (run from master)
ansible-playbook -i ansible/inventory/cluster.yml ansible/change_passwords.yml \
  -e lme_user=elastic -e lme_password='NewElasticPwd_123!'

# Offline (skip HIBP check)
ansible-playbook ansible/change_passwords.yml \
  -e lme_user=pgvector -e lme_password='NewPgvectorPwd_123!' \
  -e offline_mode=true
```

### What happens for `pgvector`
1. The playbook verifies that `lme-pgvector` is running on the master.
2. It reads the current password from the file-driver secret with
   `podman secret inspect --showsecret pgvector`.
3. It runs `ALTER USER lme WITH PASSWORD ...` against the live database via
   `podman exec lme-pgvector psql ... -h 127.0.0.1`.
4. It rewrites the `pgvector` Podman secret in place (driver = file).
5. It restarts `lme-pgvector.service` and `lme-dashboard.service` so they
   pick up the new credential.

If `lme-pgvector` is not present (for example an `--offline` install without
`--llm`), the playbook fails fast with a clear message. Cluster nodes do not
run `lme-pgvector`, so cluster-wide secret distribution still happens but is a
no-op for this credential.

## Pattern note (LLM stack vs. existing pattern)

The `pgvector` and `llm-keys` Podman secrets use Podman's **file** driver
rather than the **shell** driver backed by `/etc/lme/vault/` that
`elastic`/`kibana_system`/`wazuh`/`wazuh_api` use. That deviation is
intentional today (the file driver lets `sync_llm_keys.py` rewrite `llm-keys`
without going through Ansible Vault), but it means:
- `extract_secrets.sh` exports `pgvector` but still skips `llm-keys`.
- The standard `secrets_distribution` role does not push the file-driver
  payload to cluster nodes (cluster nodes do not run the LLM stack, so they
  do not need it).
- Backups go through a parallel path: `secret_manifest.txt` plus
  `secrets/pgvector.vault` / `secrets/llm-keys.vault` (see
  [BACKUP_README.md](BACKUP_README.md)).

`change_passwords.yml` is aware of this and handles the file-driver case
explicitly for `pgvector`.
