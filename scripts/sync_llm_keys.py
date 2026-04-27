#!/usr/bin/env python3
"""
Decrypt LLM API keys from the encrypted store and write them to a
podman secret that LiteLLM can load.  Then restart the LiteLLM service
so it picks up new/changed keys.

This script runs on the HOST (not inside a container) and is triggered by
a systemd path unit that watches the trigger file.

Flow:
  1. Read the vault password from /etc/lme/pass.sh
  2. Decrypt /opt/lme/config/llm_keys.enc using Fernet (PBKDF2-derived key)
  3. Write key=value pairs into a podman secret called 'llm-keys'
  4. Restart lme-litellm.service so it loads the new secrets
"""

import base64
import hashlib
import json
import os
import subprocess
import sys

KEYS_ENC_PATH   = os.getenv("LLM_KEYS_PATH", "/opt/lme/config/llm_keys.enc")
VAULT_PASS_FILE = os.getenv("VAULT_PASS_FILE", "/etc/lme/pass.sh")
TRIGGER_FILE    = "/opt/lme/config/.llm-keys-updated"
SECRET_NAME     = "llm-keys"


def get_vault_password() -> str:
    """Extract the vault password from pass.sh."""
    try:
        with open(VAULT_PASS_FILE, "r") as f:
            content = f.read().strip()
    except FileNotFoundError:
        print(f"ERROR: Vault password file not found: {VAULT_PASS_FILE}", file=sys.stderr)
        sys.exit(1)

    for line in content.splitlines():
        line = line.strip()
        if line.startswith("echo") or line.startswith("printf"):
            for q in ('"', "'"):
                if q in line:
                    parts = line.split(q)
                    if len(parts) >= 2:
                        return parts[1]
        elif not line.startswith("#") and not line.startswith("!") and line:
            return line
    return content


def decrypt_keys() -> dict:
    """Decrypt the LLM keys file."""
    try:
        from cryptography.fernet import Fernet
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "cryptography>=42.0", "-q"])
        from cryptography.fernet import Fernet

    try:
        with open(KEYS_ENC_PATH, "rb") as f:
            encrypted = f.read()
    except FileNotFoundError:
        return {}

    if not encrypted:
        return {}

    vault_pass = get_vault_password()
    key = hashlib.pbkdf2_hmac("sha256", vault_pass.encode(), b"lme-llm-keys", 100000)
    fernet = Fernet(base64.urlsafe_b64encode(key))

    try:
        decrypted = fernet.decrypt(encrypted)
        return json.loads(decrypted)
    except Exception as e:
        print(f"ERROR: Failed to decrypt keys: {e}", file=sys.stderr)
        return {}


def update_podman_secret(keys: dict):
    """Write decrypted keys into a podman secret (replaces any existing)."""
    lines = []
    for name, value in sorted(keys.items()):
        safe_value = value.replace("\n", "").replace("'", "").replace('"', "")
        lines.append(f"{name}={safe_value}")

    env_content = "\n".join(lines) + "\n" if lines else "# empty\n"

    # Create/replace the podman secret from stdin
    # Must use bash with profile sourced so ANSIBLE_VAULT_PASSWORD_FILE is set
    # for the shell secret driver
    result = subprocess.run(
        ["bash", "-c",
         f'source /root/.profile && echo -n "$SECRET_DATA" | podman secret create --driver shell --replace {SECRET_NAME} -'],
        env={**os.environ, "SECRET_DATA": env_content},
        capture_output=True, text=True)
    if result.returncode != 0:
        print(f"ERROR: Failed to create podman secret: {result.stderr}", file=sys.stderr)
        sys.exit(1)

    print(f"Updated podman secret '{SECRET_NAME}' with {len(keys)} key(s)")


def restart_litellm():
    """Restart the LiteLLM service."""
    try:
        subprocess.run(["systemctl", "restart", "lme-litellm.service"],
                        check=True, capture_output=True, text=True)
        print("LiteLLM service restarted successfully")
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Failed to restart LiteLLM: {e.stderr}", file=sys.stderr)
        sys.exit(1)


def main():
    print(f"Syncing LLM keys from {KEYS_ENC_PATH}...")
    keys = decrypt_keys()
    update_podman_secret(keys)
    restart_litellm()

    # Reset trigger file so systemd can detect the next change
    try:
        if os.path.isdir(TRIGGER_FILE):
            os.rmdir(TRIGGER_FILE)
        open(TRIGGER_FILE, "w").close()
    except Exception:
        pass

    print("Done.")


if __name__ == "__main__":
    main()
