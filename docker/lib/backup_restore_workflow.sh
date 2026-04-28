#!/usr/bin/env bash
# Shared LME backup/restore validation workflow for docker/*/ single-node systemd images.
#
# Prerequisites:
#   - Docker Compose v2, resources for full LME + LLM install
#   - Repository checkout so ../../../LME from docker/<variant>/ resolves to repo root (see compose bind mount)
#   - Ports 5601, 443, 8220, 9200 available on host (or edit compose)
#
# Usage (normally via docker/<variant>/test_backup_restore_workflow.sh):
#   test_backup_restore_workflow.sh install | wait-install | syntax | backup | restore [ts] | health | all
#
set -euo pipefail

COMPOSE_PROJECT_DIR="${1:?First argument must be the path to a docker Compose project directory (e.g. docker/24.04)}"
shift

INVOKED_AS="${LME_WORKFLOW_SCRIPT_NAME:-$0}"

COMPOSE_PROJECT_DIR="$(cd "$COMPOSE_PROJECT_DIR" && pwd)"
COMPOSE_FILE="$COMPOSE_PROJECT_DIR/docker-compose.yml"
if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "No docker-compose.yml in: $COMPOSE_PROJECT_DIR" >&2
  exit 1
fi

COMPOSE_VARIANT="$(basename "$COMPOSE_PROJECT_DIR")"

cd "$COMPOSE_PROJECT_DIR"

COMPOSE=(docker compose -f "$COMPOSE_FILE")
CONTAINER="${LME_CONTAINER_NAME:-lme}"
INSTALL_LOG="${LME_INSTALL_LOG:-/tmp/lme-install.log}"

dc() {
  "${COMPOSE[@]}" "$@"
}

exec_lme() {
  dc exec -T "$CONTAINER" bash -lc "$1"
}

wait_systemd() {
  local n=0
  while [[ "$n" -lt 30 ]]; do
    if dc exec -T "$CONTAINER" systemctl is-system-running &>/dev/null; then
      return 0
    fi
    sleep 2
    n=$((n + 1))
  done
  echo "systemd did not reach running state in time" >&2
  return 1
}

cmd_install() {
  dc build
  dc up -d
  wait_systemd
  echo "Starting non-interactive install with debug (${COMPOSE_VARIANT}; online LLM stack on by default)..."
  dc exec -d "$CONTAINER" bash -lc "cd /root/LME && NON_INTERACTIVE=true AUTO_CREATE_ENV=true ./install.sh -d 2>&1 | tee $INSTALL_LOG; echo EXIT:\$? >> $INSTALL_LOG"
  echo "Install started; log inside container: $INSTALL_LOG . Next: \"$INVOKED_AS\" wait-install"
}

cmd_wait_install() {
  echo "Polling $INSTALL_LOG for EXIT: (typically 45–90+ minutes)..."
  while true; do
    if exec_lme "grep -q '^EXIT:' $INSTALL_LOG 2>/dev/null"; then
      exec_lme "tail -30 $INSTALL_LOG"
      if exec_lme "grep -q '^EXIT:0' $INSTALL_LOG"; then
        echo "Install finished successfully."
        return 0
      fi
      echo "Install reported non-zero exit; see log above." >&2
      return 1
    fi
    sleep 120
    exec_lme "tail -3 $INSTALL_LOG" || true
  done
}

cmd_syntax() {
  exec_lme "cd /root/LME && ansible-galaxy collection install -r ansible/requirements.yml && \
    ansible-playbook --syntax-check ansible/backup_lme.yml && \
    ansible-playbook --syntax-check ansible/rollback_lme.yml && \
    ansible-playbook --syntax-check ansible/restore_lme_master.yml"
  echo "Syntax checks passed."
}

cmd_backup() {
  exec_lme "cd /root/LME && ansible-playbook ansible/backup_lme.yml -e skip_prompts=true"
  local latest
  latest="$(exec_lme "ls -1 /var/lib/containers/storage/backups | sort | tail -1")"
  echo "Latest backup directory: /var/lib/containers/storage/backups/$latest"
  exec_lme "B=/var/lib/containers/storage/backups/$latest; \
    test -f \"\$B/etc_systemd_system_lme/manifest.txt\" && \
    test -f \"\$B/secret_manifest.txt\" && \
    test -f \"\$B/secrets/pgvector.vault\" && \
    test -d \"\$B/volumes/lme_pgvectordata/data/\" && \
    echo Verified: manifest.txt, secret_manifest.txt, pgvector.vault, lme_pgvectordata/data"
}

cmd_restore() {
  local latest="${1:-}"
  if [[ -z "$latest" ]]; then
    latest="$(exec_lme "ls -1 /var/lib/containers/storage/backups | sort | tail -1")"
  fi
  local bp="/var/lib/containers/storage/backups/$latest"
  echo "Running restore_lme_master from: $bp (restore_es_volumes defaults to auto from archive)"
  exec_lme "cd /root/LME && ansible-playbook ansible/restore_lme_master.yml -e restore_backup_dir=$bp"
}

cmd_health() {
  exec_lme "source /opt/lme/scripts/extract_secrets.sh -q 2>/dev/null || true; \
    echo 'Elasticsearch cluster health:'; \
    curl -sk -u \"elastic:\${elastic}\" 'https://127.0.0.1:9200/_cluster/health?pretty'; \
    echo ''; echo 'lme systemd:'; systemctl is-active lme || true; \
    echo ''; echo 'Podman lme-*:'; export PATH=\$PATH:/nix/var/nix/profiles/default/bin; \
    podman ps --filter name=lme --format '{{.Names}} {{.Status}}'"
}

usage() {
  echo "Docker LME workflow (${COMPOSE_PROJECT_DIR}; variant ${COMPOSE_VARIANT})"
  echo "Invoked as: ${INVOKED_AS}"
  echo ""
  grep '^#' "${BASH_SOURCE[0]}" | grep -v '^#!' | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
  install)        cmd_install ;;
  wait-install)   cmd_wait_install ;;
  syntax)         cmd_syntax ;;
  backup)         cmd_backup ;;
  restore)        cmd_restore "${2:-}" ;;
  health)         cmd_health ;;
  all)
    cmd_install
    cmd_wait_install
    cmd_syntax
    cmd_backup
    cmd_restore
    cmd_health
    ;;
  ""|-h|--help)   usage ;;
  *)
    echo "Unknown command: $1" >&2
    usage >&2
    exit 1
    ;;
esac
