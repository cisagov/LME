#!/usr/bin/env python3
"""
Switch the local llama.cpp model by rewriting the quadlet Exec line
and restarting the lme-llama-cpp systemd service.

This script runs on the HOST (not inside a container) and is triggered by
a systemd path unit that watches /opt/lme/config/.llama-model-updated.

Flow:
  1. Read /opt/lme/config/llama-cpp-model.json to get the desired model filename
  2. Verify the .gguf file exists in /opt/lme/llama-models/
  3. Rewrite the Exec line in the quadlet file
  4. Reload systemd and restart lme-llama-cpp.service
"""

import json
import os
import re
import subprocess
import sys

CONFIG_PATH = os.getenv("LLAMA_MODEL_CONFIG", "/opt/lme/config/llama-cpp-model.json")
MODELS_DIR = "/opt/lme/llama-models"
QUADLET_PATH = "/etc/containers/systemd/lme-llama-cpp.container"
STATUS_PATH = "/opt/lme/config/llama-cpp-status.json"


def read_config() -> dict:
    """Read the model switch request."""
    try:
        with open(CONFIG_PATH, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"ERROR: Cannot read config {CONFIG_PATH}: {e}", file=sys.stderr)
        sys.exit(1)


def write_status(status: str, model: str = "", error: str = ""):
    """Write status so the dashboard can poll progress."""
    try:
        with open(STATUS_PATH, "w") as f:
            json.dump({"status": status, "model": model, "error": error}, f)
    except Exception:
        pass


def get_current_model() -> str:
    """Read the current --model value from the quadlet file."""
    try:
        with open(QUADLET_PATH, "r") as f:
            content = f.read()
        m = re.search(r'--model\s+/models/(\S+)', content)
        return m.group(1) if m else ""
    except FileNotFoundError:
        return ""


def update_quadlet(model_filename: str) -> bool:
    """Rewrite the Exec line in the quadlet file to use the new model."""
    try:
        with open(QUADLET_PATH, "r") as f:
            content = f.read()
    except FileNotFoundError:
        print(f"ERROR: Quadlet file not found: {QUADLET_PATH}", file=sys.stderr)
        sys.exit(1)

    # Replace the --model argument in the Exec line
    new_content = re.sub(
        r'(--model\s+/models/)\S+',
        rf'\g<1>{model_filename}',
        content,
    )

    if new_content == content:
        print(f"WARNING: Could not find --model in Exec line, quadlet unchanged", file=sys.stderr)
        return False

    with open(QUADLET_PATH, "w") as f:
        f.write(new_content)

    print(f"Updated quadlet Exec to use model: {model_filename}")
    return True


def restart_llama_cpp():
    """Reload systemd and restart llama-cpp service."""
    try:
        subprocess.run(["systemctl", "daemon-reload"],
                       check=True, capture_output=True, text=True)
        print("systemd daemon reloaded")
    except subprocess.CalledProcessError as e:
        print(f"ERROR: daemon-reload failed: {e.stderr}", file=sys.stderr)
        sys.exit(1)

    try:
        subprocess.run(["systemctl", "restart", "lme-llama-cpp.service"],
                       check=True, capture_output=True, text=True)
        print("lme-llama-cpp.service restarted successfully")
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Failed to restart llama-cpp: {e.stderr}", file=sys.stderr)
        sys.exit(1)


def main():
    config = read_config()
    model_filename = config.get("model", "")

    if not model_filename:
        print("ERROR: No model specified in config", file=sys.stderr)
        write_status("error", error="No model specified in config")
        sys.exit(1)

    # Validate: must be a simple filename (no path traversal)
    if "/" in model_filename or ".." in model_filename:
        print(f"ERROR: Invalid model filename: {model_filename}", file=sys.stderr)
        write_status("error", error="Invalid model filename")
        sys.exit(1)

    model_path = os.path.join(MODELS_DIR, model_filename)
    if not os.path.isfile(model_path):
        print(f"ERROR: Model file not found: {model_path}", file=sys.stderr)
        write_status("error", model=model_filename, error=f"Model file not found: {model_filename}")
        sys.exit(1)

    # Skip if already running this model (idempotent — avoids ghost re-triggers)
    current = get_current_model()
    if current == model_filename:
        print(f"Model already set to {model_filename}, nothing to do.")
        write_status("ready", model=model_filename)
        return

    print(f"Switching llama.cpp model to: {model_filename}")
    write_status("switching", model=model_filename)

    if update_quadlet(model_filename):
        restart_llama_cpp()
        write_status("ready", model=model_filename)
        print("Done.")
    else:
        write_status("error", model=model_filename, error="Failed to update quadlet file")
        sys.exit(1)


if __name__ == "__main__":
    main()
