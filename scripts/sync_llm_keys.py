#!/usr/bin/env python3
"""
Decrypt LLM API keys from the encrypted store and write them to an
environment file that LiteLLM can load.  Then restart the LiteLLM service
so it picks up new/changed keys.

This script runs on the HOST (not inside a container) and is triggered by
a systemd path unit that watches the trigger file.

Flow:
  1. Read the vault password from /etc/lme/pass.sh
  2. Decrypt /opt/lme/config/llm_keys.enc using Fernet (PBKDF2-derived key)
  3. Write key=value pairs to /opt/lme/config/llm_keys.env (mode 0600)
  4. Restart lme-litellm.service so it loads the new env vars
"""

import base64
import hashlib
import json
import os
import subprocess
import sys

KEYS_ENC_PATH  = os.getenv("LLM_KEYS_PATH", "/opt/lme/config/llm_keys.enc")
KEYS_ENV_PATH  = os.getenv("LLM_KEYS_ENV_PATH", "/opt/lme/config/llm_keys.env")
VAULT_PASS_FILE = os.getenv("VAULT_PASS_FILE", "/etc/lme/pass.sh")
TRIGGER_FILE    = "/opt/lme/config/.llm-keys-updated"


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
        # If cryptography isn't installed on the host, install it
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


def write_env_file(keys: dict):
    """Write decrypted keys to an environment file (root-only readable)."""
    lines = []
    for name, value in sorted(keys.items()):
        # Sanitize: no newlines or quotes in env values
        safe_value = value.replace("\n", "").replace("'", "").replace('"', "")
        lines.append(f"{name}={safe_value}")

    env_content = "\n".join(lines) + "\n" if lines else ""

    # Write atomically: temp file then rename
    tmp_path = KEYS_ENV_PATH + ".tmp"
    with open(tmp_path, "w") as f:
        f.write(env_content)
    os.chmod(tmp_path, 0o600)
    os.rename(tmp_path, KEYS_ENV_PATH)

    print(f"Wrote {len(keys)} key(s) to {KEYS_ENV_PATH}")


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
    write_env_file(keys)
    restart_litellm()

    # Reset trigger file (touch it back so systemd can detect the next change)
    # Don't remove it — just truncate so PathModified fires on next touch
    try:
        if os.path.isdir(TRIGGER_FILE):
            os.rmdir(TRIGGER_FILE)
        open(TRIGGER_FILE, "w").close()
    except Exception:
        pass

    print("Done.")


if __name__ == "__main__":
    main()
