# MASTER_PLAN.md — LME 3.0 Upgrade Path

## Original Intent
The user needs to integrate the `llama-cpp-frontend` branch into LME's upgrade process so that a live LME 2.2.0 instance can upgrade to LME 3.0.0. The upgraded instance must match the architecture documented at https://github.com/cisagov/lme-docs/commit/e45e124f7f753a9fe3250f7330e9c64b9caa2137 (docs/ai-stack + SVG diagrams). The detailed integration spec was provided in `changes.md`, covering 6 new containers, new secrets, model downloads, cert generation, config files, quadlet files, and a step-by-step upgrade script outline. The upgrade must be additive — existing containers (ES, Kibana, Wazuh, Fleet, ElastAlert2) are untouched, and `install.sh` must NOT be re-run since it is not idempotent.

## Goal
Enable existing LME 2.2.0 installations to upgrade to LME 3.0.0, which adds the AI & LLM security analysis stack (6 new containers: llama-cpp, embeddings, litellm, pgvector, dashboard, log-analyzer).

## Architecture (3.0)
- **Existing stack (unchanged):** Elasticsearch, Kibana, Wazuh, Fleet Server, ElastAlert2
- **New AI stack:** llama-cpp (:8080), embeddings (:8081), LiteLLM (:4000), pgvector (:5432), Dashboard (:8502), Log Analyzer (:8501)
- **Models:** LFM2.5-1.2B-Instruct (~698MB), nomic-embed-text-v1.5 (~81MB) stored at `/opt/lme/llama-models/`
- **Docs reference:** https://github.com/cisagov/lme-docs/commit/e45e124f7f753a9fe3250f7330e9c64b9caa2137

## Upgrade Strategy
The upgrade is **additive** — existing containers are untouched. New components are deployed alongside.

### Key Design Decisions
1. **Secrets use `file` driver** (not `shell`) — avoids ansible-vault password prompts during non-interactive upgrade
2. **Certs generated via openssl** — uses existing LME CA from `lme_certs` volume; does NOT regenerate existing certs
3. **install.sh is NOT re-run** — it's not idempotent; upgrade is via `ansible-playbook ansible/upgrade_lme.yml`
4. **AI stack defaults to ON for fresh installs** — `install_llm` defaults to `true` in podman role

## Changes

### Phase 1: Upgrade Playbook (ansible/upgrade_lme.yml)
- [x] Update target version to 3.0.0
- [x] Add AI stack deployment block (conditional on upgrading from < 3.0.0):
  - Create directories (`/opt/lme/llama-models`, `/opt/lme/lme-dashboard`)
  - Create secrets (`pgvector`, `llm-keys`) with file driver
  - Pull + tag AI container images (llama.cpp, litellm, pgvector)
  - Build local images (dashboard, log-analyzer)
  - Download GGUF models
  - Generate SSL certs for new services via openssl
  - Copy configs (litellm_config.yaml, llama-cpp-model.json)
  - Copy dashboard source + scripts
  - Copy systemd path/service units
  - Enable path watchers
  - Run doc ingestion into pgvector
- [x] Update verification to expect 11 containers (was 5)

### Phase 2: Fresh Install Defaults
- [x] Update `version.txt` to 3.0.0
- [x] Change `install_llm` default from `false` to `true` in podman role
- [x] Fix secret drivers in `llama_cpp_setup.yml` (shell → file for pgvector/llm-keys)

## Verification
After upgrade, all 11 containers running, health checks pass on :8502, :8501, :4000, :8080, :8081, and pgvector `pg_isready`.
