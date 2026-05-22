# Testing Framework Bugs — Found During run-all.sh Execution

## BUG-1: generate-range.sh put local path in range-config (FIXED)
**Commit:** a8e1b06
**Symptom:** Ludus deploy failed — VM tried `git clone file:///home/mreeve/vibe-home/LME`.
**Fix:** Check if URL starts with `/` instead of `-d` test. Local paths use GitHub URL in range-config; `deploy-range.sh` rsyncs after deploy.

## BUG-2: ludus_lme_agents dynamic lookup skipped (FIXED)
**Commit:** a5205f6
**Symptom:** elastic_version and enrollment_token empty after deploy.
**Fix:** Changed conditions from `is not defined` to `| default('') | length == 0`.

## BUG-3: Wazuh delegate_to SSH hangs (PARTIALLY FIXED)
**Commit:** a3d910b, beaec2b
**Symptom:** `Get Wazuh manager version from container` — SSH to LME server hangs when Ludus runs Ansible on the same host.
**Fix:** Defaulted `wazuh_version` to 4.9.1 to skip the delegate_to. Added `ansible_connection: ssh` + `ansible_ssh_private_key_file: ""`. Still may hang on Wazuh agent registration verification.
**Impact:** Agents not fully enrolled on Win11/Ubuntu endpoints → TS-03-02, TS-VULN fail.

## BUG-4: SETUP-03b used wrong install dir (FIXED)
**Commit:** 990571d
**Symptom:** `ingest_docs.py: error: unrecognized arguments: --docs-repo` — notebook found `/opt/lme` (runtime dir without our fix) instead of `/opt/lme-install` (rsynced code).
**Fix:** Changed dir detection to prefer `/opt/lme-install`, verify `--docs-repo` flag exists before running.

## BUG-5: ludus CLI API key not auto-loaded (FIXED)
**Commit:** bf5030a
**Symptom:** `ludus range list` returned empty — CLI couldn't authenticate.
**Fix:** `lib-params.sh` auto-exports `LUDUS_API_KEY` and `LUDUS_URL` from `~/.ludus/config`. Added `ludus_cmd` wrapper that passes `--url`.

## Product Issues (not framework bugs)

### SEC-CRIT: Dashboard/Log Analyzer no auth
Both respond to unauthenticated `/api/health`. Network-accessible information disclosure.

### SEC-HIGH: LiteLLM static master_key
Hardcoded `sk-lme-llama-proxy` in config file.

### TS-01: Only 10 containers (timing bug)
One container fails to start — this is the bug `cbaxley-fix-quadlet-timing` was created to fix.
