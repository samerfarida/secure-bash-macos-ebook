#!/bin/bash
# agent-isolation-policy-check.sh — verify repo isolation marker and sbx availability
# Secure Bash for macOS — Chapter 23 sample script
set -euo pipefail

MARKER=".agent-isolation-required"
EXIT_OK=0
EXIT_WARN=1
EXIT_FAIL=2

check_sbx() {
  if ! command -v sbx >/dev/null 2>&1; then
    echo "FAIL: sbx CLI not installed (brew install docker/tap/sbx)"
    return "$EXIT_FAIL"
  fi
  if ! sbx version >/dev/null 2>&1; then
    echo "FAIL: sbx installed but not functional — run sbx login"
    return "$EXIT_FAIL"
  fi
  echo "OK: sbx $(sbx version 2>/dev/null | head -1)"
  return "$EXIT_OK"
}

check_marker() {
  local repo="${1:-.}"
  if [[ -f "${repo}/${MARKER}" ]]; then
    echo "OK: isolation marker present at ${repo}/${MARKER}"
    return "$EXIT_OK"
  fi
  echo "WARN: no ${MARKER} in ${repo} — host execution allowed by policy"
  return "$EXIT_WARN"
}

main() {
  local repo="${1:-.}"
  local rc="$EXIT_OK" mc

  check_sbx || rc=$?

  if ! check_marker "$repo"; then
    mc=$?
    (( mc > rc )) && rc=$mc
  fi

  exit "$rc"
}

main "$@"
