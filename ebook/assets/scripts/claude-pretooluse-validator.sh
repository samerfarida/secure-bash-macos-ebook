#!/bin/bash
# claude-pretooluse-validator.sh — PreToolUse command hook for Claude Code
# Blocks destructive patterns and sensitive path writes (Chapter 23)
set -euo pipefail

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

deny() {
  local reason="$1"
  printf '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "%s"}}\n' "$reason"
  exit 0
}

if echo "$COMMAND" | grep -qE 'rm\s+(-[a-zA-Z]*f[a-zA-Z]*\s+|-[a-zA-Z]*r[a-zA-Z]*\s+).*(-r|-f)|rm\s+-rf'; then
  deny "Destructive rm blocked by policy"
fi

if echo "$COMMAND" | grep -qE 'curl\s+[^|]*\|\s*(ba)?sh'; then
  deny "curl pipe to shell blocked by policy"
fi

if echo "$COMMAND" | grep -qE '~/.ssh|\.git/hooks|\.cursor/mcp\.json|Library/Keychains'; then
  deny "Write to sensitive path blocked by policy"
fi

echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
exit 0
