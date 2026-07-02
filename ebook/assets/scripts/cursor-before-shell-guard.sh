#!/bin/bash
# cursor-before-shell-guard.sh — Cursor beforeShellExecution hook
# Secure Bash for macOS — Chapter 23
set -euo pipefail

input=$(cat)

deny() {
  local msg="${1:-Command blocked by policy}"
  printf '{"permission":"deny","agentMessage":"%s"}\n' "$msg"
  exit 0
}

allow() {
  printf '{"permission":"allow"}\n'
  exit 0
}

if ! command -v python3 >/dev/null 2>&1; then
  deny "python3 required — failing closed"
fi

command=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("command",""))' 2>/dev/null) || deny "invalid hook JSON — failing closed"

[[ -z "$command" ]] && deny "empty command — failing closed"

if printf '%s' "$command" | grep -qE '\brm\b'; then
  if printf '%s' "$command" | grep -qE '(-[rRfF]|--recursive|--force|-fr|-rf)'; then
    deny "Destructive rm blocked by policy"
  fi
fi

if printf '%s' "$command" | grep -qE '(curl|wget)\s+[^|]*\|\s*(ba)?sh'; then
  deny "curl/wget pipe to shell blocked by policy"
fi

if printf '%s' "$command" | grep -qE '(\.ssh(/|$)|Keychains|\.env)'; then
  deny "Sensitive path in command blocked by policy"
fi

allow
