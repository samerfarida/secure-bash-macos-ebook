#!/bin/bash
# agent-lab-scaffold.sh — create guardrail files for Chapter 23 hands-on lab
# Usage: bash agent-lab-scaffold.sh [TARGET_DIR]
set -euo pipefail

TARGET="${1:-$PWD}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

mkdir -p "$TARGET"/{.claude/hooks,.cursor,.mcp,docs}
cd "$TARGET" || exit 1

# Copy hook validator from ebook assets if available
if [[ -f "$REPO_ROOT/assets/scripts/claude-pretooluse-validator.sh" ]]; then
  cp "$REPO_ROOT/assets/scripts/claude-pretooluse-validator.sh" .claude/hooks/validate-bash.sh
  chmod +x .claude/hooks/validate-bash.sh
fi
if [[ -f "$REPO_ROOT/assets/scripts/cursor-before-read-guard.sh" ]]; then
  cp "$REPO_ROOT/assets/scripts/cursor-before-read-guard.sh" .cursor/cursor-before-read-guard.sh
  chmod +x .cursor/cursor-before-read-guard.sh
fi
if [[ -f "$REPO_ROOT/assets/scripts/cursor-before-shell-guard.sh" ]]; then
  cp "$REPO_ROOT/assets/scripts/cursor-before-shell-guard.sh" .cursor/cursor-before-shell-guard.sh
  chmod +x .cursor/cursor-before-shell-guard.sh
fi

cat > AGENTS.md <<'EOF'
# Agent instructions

## Build commands
- Test: `make test` (or `echo "no tests configured"`)
- Lint: `shellcheck scripts/*.sh 2>/dev/null || true`

## Security considerations
- Never read or print `.env`, `~/.ssh`, or `~/Library/Keychains`
- Do not run `curl | bash` or `git push --force` without explicit user request
- MCP servers: only those listed in `.mcp/allowlist.json`
- All production changes require tests to pass
EOF

cat > CLAUDE.md <<'EOF'
@AGENTS.md

## Claude-specific notes
- Prefer small, reviewable commits
- Run tests before suggesting git push
EOF

cat > .claude/settings.json <<'EOF'
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": ".claude/hooks/validate-bash.sh"
      }]
    }]
  }
}
EOF

cat > .cursor/sandbox.json <<'EOF'
{
  "type": "workspace_readwrite",
  "networkPolicy": {
    "default": "deny",
    "allow": ["github.com", "registry.npmjs.org"]
  }
}
EOF

cat > .cursor/hooks.json <<'EOF'
{
  "version": 1,
  "hooks": {
    "beforeShellExecution": [{
      "command": ".cursor/cursor-before-shell-guard.sh",
      "failClosed": true
    }],
    "beforeReadFile": [{
      "command": ".cursor/cursor-before-read-guard.sh",
      "failClosed": true
    }]
  }
}
EOF

cp "$REPO_ROOT/assets/sample_configs/mcp-allowlist.json" .mcp/allowlist.json 2>/dev/null || cat > .mcp/allowlist.json <<'EOF'
{
  "servers": {},
  "default": "deny",
  "notes": "Add MCP servers only after security review"
}
EOF

touch .agent-isolation-required

cat > docs/security-agent-policy.md <<'EOF'
# Agent security policy (lab)

- Default: sbx sandbox for unattended agent sessions
- Host path: only for Xcode/signing with documented exception
- Hooks: PreToolUse deny for destructive bash and sensitive paths
- Telemetry: OTLP to localhost collector in lab; corp collector in production
EOF

echo "Scaffold complete in $TARGET"
echo "Next: git add -A && git commit -m 'Add agent guardrails scaffold'"
ls -la "$TARGET"
