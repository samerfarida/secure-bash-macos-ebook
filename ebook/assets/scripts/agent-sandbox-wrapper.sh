#!/bin/bash
# agent-sandbox-wrapper.sh — route agent CLI through sbx when repo requires isolation
# Secure Bash for macOS — Chapter 23 sample script
set -euo pipefail

MARKER=".agent-isolation-required"
AGENT="${AGENT:-claude}"
LOG_PREFIX="${LOG_PREFIX:-[acme-devx]}"

run_agent_isolated() {
  local workspace
  workspace="$(pwd)"

  if [[ ! -d "$workspace" ]]; then
    echo "${LOG_PREFIX} ERROR: not in a valid workspace directory" >&2
    return 1
  fi

  if [[ -f "${workspace}/${MARKER}" ]]; then
    echo "${LOG_PREFIX} Running ${AGENT} via sbx for ${workspace}"
    cd "$workspace" && sbx run "$AGENT" -- "$@"
  else
    echo "${LOG_PREFIX} WARNING: host execution for ${workspace}" >&2
    command "$AGENT" "$@"
  fi
}

run_agent_isolated "$@"
