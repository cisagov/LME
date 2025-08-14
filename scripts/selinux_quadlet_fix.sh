#!/usr/bin/env bash
set -euo pipefail

# Purpose: Make Podman Quadlet work on RHEL with SELinux Enforcing when Podman is from Nix
# Notes:
# - Run as root. This script sets persistent SELinux file contexts and regenerates quadlet units.
# - It assumes a Nix-installed Podman with generator and quadlet under /nix/store.

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[ERROR] Run this script as root (sudo)." >&2
  exit 1
fi

echo "[INFO] SELinux mode: $(getenforce || true)"

echo "[INFO] (Optional) Ensure SELinux tooling is present"
if command -v dnf >/dev/null 2>&1; then
  dnf -y install selinux-policy selinux-policy-targeted policycoreutils policycoreutils-python-utils libselinux-utils >/dev/null 2>&1 || true
fi

echo "[INFO] Add persistent SELinux file contexts for Nix-installed Podman/Quadlet"
# Generator symlink must be readable by init_t (non-exec type for symlink)
semanage fcontext -a -t lib_t '/nix/store/.*/lib/systemd/system-generators/podman-system-generator' || true

# Quadlet helper (not a container runtime) - readable/executable by init
semanage fcontext -a -t bin_t '/nix/store/.*/libexec/podman/quadlet' || true

# Container runtime stack must be container_runtime_exec_t so it transitions to container_runtime_t
semanage fcontext -a -t container_runtime_exec_t '/nix/store/.*/bin/podman' || true
semanage fcontext -a -t container_runtime_exec_t '/nix/store/.*/bin/\.podman-wrapped' || true
semanage fcontext -a -t container_runtime_exec_t '/nix/store/.*/bin/conmon' || true
semanage fcontext -a -t container_runtime_exec_t '/nix/store/.*/bin/crun'   || true
semanage fcontext -a -t container_runtime_exec_t '/nix/store/.*/bin/runc'   || true
semanage fcontext -a -t container_runtime_exec_t '/nix/store/.*/bin/netavark' || true

# Nix-provided helper wrapper paths for conmon/crun
semanage fcontext -a -t container_runtime_exec_t '/nix/store/.*/podman-helper-binary-wrapper/bin/.*' || true

# Bash used by wrapper
semanage fcontext -a -t shell_exec_t '/nix/store/.*/bin/bash'   || true

# Dynamic loader and shared libraries used by quadlet/podman
semanage fcontext -a -t ld_so_t '/nix/store/.*/lib/ld-linux-x86-64\.so\.2' || true
semanage fcontext -a -t lib_t   '/nix/store/.*/lib/.*\.so(\..*)?'          || true
semanage fcontext -a -t lib_t   '/nix/store/.*/lib64/.*\.so(\..*)?'        || true

# Nix profile symlink (systemd may read through this path)
semanage fcontext -a -t bin_t '/nix/var/nix/profiles/default(/.*)?' || true

# Quadlet directory should be etc_t; ensure permissions 0755
semanage fcontext -a -t etc_t '/etc/containers/systemd(/.*)?' || true
chmod 0755 /etc/containers/systemd || true

echo "[INFO] Apply SELinux contexts (this may take a moment)"
restorecon -Rv /nix/store \
               /nix/var/nix/profiles/default \
               /usr/lib/systemd/system-generators/podman-system-generator \
               /etc/containers/systemd | tail -n 50 || true

echo "[INFO] Enable common container SELinux booleans"
setsebool -P container_manage_cgroup on || true
setsebool -P container_use_devices on || true
setsebool -P container_read_certs on || true

echo "[INFO] Run Podman quadlet generator and reload systemd"
/usr/lib/systemd/system-generators/podman-system-generator \
  /run/systemd/generator \
  /run/systemd/generator.early \
  /run/systemd/generator.late || true

systemctl daemon-reload || true

echo "[INFO] Generated LME units under /run/systemd/generator:"
ls -1 /run/systemd/generator/*lme*.service 2>/dev/null || true

echo "[INFO] (Optional) Start orchestrator"
systemctl start lme.service || true

echo "[DONE] SELinux contexts applied and quadlet units generated."

