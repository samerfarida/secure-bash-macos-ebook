#!/bin/bash
# cursor-before-mcp-guard.sh — Cursor beforeMCPExecution hook
# Secure Bash for macOS — Chapter 23
set -euo pipefail

input=$(cat)
ALLOWLIST="${MCP_ALLOWLIST:-.mcp/allowlist.json}"

deny() {
  local msg="${1:-MCP server blocked by policy}"
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

if [[ ! -f "$ALLOWLIST" ]]; then
  deny "MCP allowlist missing — failing closed"
fi

result=$(ALLOWLIST="$ALLOWLIST" HOOK_JSON="$input" python3 <<'PY'
import json
import os
import sys

allowlist_path = os.environ.get("ALLOWLIST", ".mcp/allowlist.json")
try:
    hook = json.loads(os.environ["HOOK_JSON"])
except (json.JSONDecodeError, KeyError):
    print("deny:invalid hook JSON — failing closed")
    sys.exit(0)

server = (
    hook.get("server")
    or hook.get("serverName")
    or hook.get("mcpServer")
    or hook.get("name")
)

if not server:
    command = hook.get("command", "")
    parts = command.split()
    if len(parts) >= 2 and parts[0] == "mcp":
        server = parts[1]

if not server:
    print("deny:Unknown MCP server — failing closed")
    sys.exit(0)

try:
    with open(allowlist_path, encoding="utf-8") as fh:
        policy = json.load(fh)
except OSError:
    print("deny:Cannot read MCP allowlist — failing closed")
    sys.exit(0)

servers = policy.get("servers") or {}
default = policy.get("default", "deny")
entry = servers.get(server)

if isinstance(entry, dict) and entry.get("allowed"):
    print("allow")
elif default == "allow":
    print("allow")
else:
    print(f"deny:MCP server '{server}' not in allowlist")
PY
) || deny "MCP policy evaluation failed — failing closed"

case "$result" in
  allow) allow ;;
  deny:*) deny "${result#deny:}" ;;
  *) deny "MCP policy evaluation failed — failing closed" ;;
esac
