#!/bin/bash
# cursor-before-read-guard.sh — Cursor beforeReadFile hook (stdin JSON, stdout permission)
# Secure Bash for macOS — Chapter 23
set -euo pipefail

input=$(cat)

deny() {
  local msg="${1:-Blocked read of sensitive path}"
  printf '{"permission":"deny","userMessage":"%s"}\n' "$msg"
  exit 0
}

allow() {
  printf '{"permission":"allow"}\n'
  exit 0
}

if ! command -v python3 >/dev/null 2>&1; then
  deny "python3 required — failing closed"
fi

path=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("file_path",""))' 2>/dev/null) || deny "invalid hook JSON — failing closed"

if [[ -z "$path" ]]; then
  deny "empty file_path — failing closed"
fi

if printf '%s' "$path" | grep -qiE '\.ssh(/|$)|Keychains|(^|/)\.env($|\.)|/\.aws/|/\.kube/'; then
  deny "Blocked read of sensitive path"
fi

allow
