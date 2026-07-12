#!/bin/bash
# claude-pretooluse-validator.sh — PreToolUse command hook for Claude Code
# Blocks destructive patterns and sensitive path writes (Chapter 23)
set -euo pipefail

INPUT=$(cat)

deny() {
  local reason="$1"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
  exit 0
}

allow() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}\n'
  exit 0
}

if ! command -v python3 >/dev/null 2>&1; then
  deny "python3 required for hook parsing — failing closed"
fi

COMMAND=$(printf '%s' "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    sys.exit(1)
" 2>/dev/null) || deny "invalid hook JSON — failing closed"

[[ -z "$COMMAND" ]] && deny "empty command — failing closed"

# Destructive rm: combined -rf/-fr or separate recursive+force flags
if printf '%s' "$COMMAND" | grep -qE '\brm\b'; then
  if printf '%s' "$COMMAND" | grep -qE '(-[a-zA-Z]*[rR][a-zA-Z]*[fF][a-zA-Z]*|-[a-zA-Z]*[fF][a-zA-Z]*[rR][a-zA-Z]*|--recursive|--force)'; then
    deny "Destructive rm blocked by policy"
  fi
fi

# Pipe to shell
if printf '%s' "$COMMAND" | grep -qE '(curl|wget)\s+[^|]*\|\s*(ba)?sh'; then
  deny "curl/wget pipe to shell blocked by policy"
fi

# Sensitive paths (tilde-expanded and absolute forms)
if printf '%s' "$COMMAND" | grep -qE '(\.ssh(/|$)|Keychains|\.env(\.|$)|/\.aws/|/\.kube/)'; then
  deny "Sensitive path access blocked by policy"
fi

allow
