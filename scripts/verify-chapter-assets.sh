#!/usr/bin/env bash
# verify-chapter-assets.sh — OS-aware chapter executable QA for Secure Bash for macOS
# Usage: ./scripts/verify-chapter-assets.sh ebook/part3_real_world_projects/23_*.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CHAPTER="${1:-}"
if [[ -z "$CHAPTER" || ! -f "$CHAPTER" ]]; then
  echo "Usage: $0 <chapter-markdown-path>" >&2
  exit 1
fi

OS="$(uname -s)"
ARCH="$(uname -m)"
if [[ "$OS" == "Darwin" ]]; then
  REVIEW_MODE="macos-live"
  MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
else
  REVIEW_MODE="static-only"
  MACOS_VERSION="n/a"
fi

echo "REVIEW_MODE=$REVIEW_MODE"
echo "HOST_OS=$OS"
echo "HOST_ARCH=$ARCH"
echo "MACOS_VERSION=$MACOS_VERSION"
echo "CHAPTER=$CHAPTER"
echo "---"

BLOCKERS=0
WARNINGS=0
TMPDIR_VERIFY="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_VERIFY"' EXIT

log_blocker() { echo "BLOCKER: $*"; BLOCKERS=$((BLOCKERS + 1)); }
log_warn() { echo "WARN: $*"; WARNINGS=$((WARNINGS + 1)); }
log_ok() { echo "OK: $*"; }

# --- Extract fenced bash blocks from chapter ---
extract_bash_blocks() {
  python3 - "$CHAPTER" "$TMPDIR_VERIFY" <<'PY'
import re, sys, pathlib
chapter, outdir = sys.argv[1], pathlib.Path(sys.argv[2])
text = pathlib.Path(chapter).read_text(encoding="utf-8")
pattern = re.compile(r"```(?:bash|sh)\n(.*?)```", re.DOTALL)
skip_tokens = ("=", "echo", "if ", "for ", "while ", "sudo", "launchctl", "brew",
               "cat ", "cp ", "mv ", "chmod", "export", "curl", "jq", "python",
               "plutil", "defaults", "santactl", "osquery", "sbx", "mkdir", "cd ")
for i, m in enumerate(pattern.finditer(text), 1):
    cleaned = []
    for line in m.group(1).splitlines():
        s = line.strip()
        if s.startswith("$ "):
            cleaned.append(s[2:])
        elif s.startswith("$"):
            cleaned.append(s[1:].lstrip())
        else:
            cleaned.append(line)
    content = "\n".join(cleaned).strip()
    if not content:
        continue
    if "<" in content and ">" in content:
        # skip blocks with angle-bracket placeholders (not valid bash)
        continue
    if not any(tok in content for tok in skip_tokens):
        continue
    (outdir / f"extracted-{i}.sh").write_text(content + "\n", encoding="utf-8")
PY
}

extract_bash_blocks

# --- bash -n on asset scripts ---
if [[ -d ebook/assets/scripts ]]; then
  while IFS= read -r -d '' script; do
    if bash -n "$script" 2>/dev/null; then
      log_ok "bash -n $script"
    else
      log_blocker "bash -n failed: $script"
    fi
  done < <(find ebook/assets/scripts -name '*.sh' -print0 2>/dev/null)
fi

# --- bash -n on extracted blocks ---
shopt -s nullglob
for f in "$TMPDIR_VERIFY"/extracted-*.sh; do
  [[ -f "$f" ]] || continue
  if bash -n "$f" 2>/dev/null; then
    log_ok "bash -n extracted $(basename "$f")"
  else
    log_blocker "bash -n failed: $f (from $CHAPTER)"
  fi
done

# --- ShellCheck (optional) ---
if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r -d '' script; do
    if shellcheck -s bash -o all "$script" >/dev/null 2>&1; then
      log_ok "shellcheck $script"
    else
      log_warn "shellcheck issues: $script"
    fi
  done < <(find ebook/assets/scripts -name '*.sh' -print0 2>/dev/null)
  for f in "$TMPDIR_VERIFY"/extracted-*.sh; do
    [[ -f "$f" ]] || continue
    if shellcheck -s bash -o all "$f" >/dev/null 2>&1; then
      log_ok "shellcheck $(basename "$f")"
    else
      log_warn "shellcheck issues: $f"
    fi
  done
else
  log_warn "shellcheck not installed — skipping (install for full QA)"
fi

# --- JSON assets ---
if [[ -d ebook/assets/sample_configs ]]; then
  while IFS= read -r -d '' jsonf; do
    if python3 -m json.tool "$jsonf" >/dev/null 2>&1; then
      log_ok "JSON valid: $jsonf"
    else
      log_blocker "Invalid JSON: $jsonf"
    fi
  done < <(find ebook/assets/sample_configs -name '*.json' -print0 2>/dev/null)
fi

# --- YAML assets ---
if command -v yamllint >/dev/null 2>&1 && [[ -d ebook/assets/sample_configs ]]; then
  while IFS= read -r -d '' yamlf; do
    if yamllint -c .yamllint.yml "$yamlf" >/dev/null 2>&1; then
      log_ok "YAML valid: $yamlf"
    else
      log_blocker "Invalid YAML: $yamlf"
    fi
  done < <(find ebook/assets/sample_configs \( -name '*.yaml' -o -name '*.yml' \) -print0 2>/dev/null)
elif [[ -d ebook/assets/sample_configs ]]; then
  while IFS= read -r -d '' yamlf; do
    if python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$yamlf" 2>/dev/null; then
      log_ok "YAML parse: $yamlf"
    else
      log_warn "YAML parse skipped/failed (install yamllint): $yamlf"
    fi
  done < <(find ebook/assets/sample_configs \( -name '*.yaml' -o -name '*.yml' \) -print0 2>/dev/null)
fi

# --- Plist ---
plist_files=()
while IFS= read -r -d '' p; do plist_files+=("$p"); done < <(find ebook/assets -name '*.plist' -print0 2>/dev/null)
if [[ ${#plist_files[@]} -gt 0 ]]; then
  for pf in "${plist_files[@]}"; do
    if [[ "$REVIEW_MODE" == "macos-live" ]] && command -v plutil >/dev/null 2>&1; then
      if plutil -lint "$pf" >/dev/null 2>&1; then
        log_ok "plutil -lint $pf"
      else
        log_blocker "Invalid plist: $pf"
      fi
    else
      if python3 -c "import plistlib; plistlib.load(open('$pf','rb'))" 2>/dev/null; then
        log_ok "plist parse: $pf"
      else
        log_blocker "Invalid plist: $pf"
      fi
    fi
  done
fi

# --- Linux-ism scan on chapter ---
LINUX_PATTERNS='apt-get|apt install|yum |dnf |systemctl |useradd |usermod |grep -P|readlink -f|stat -c|date -d|/home/|/etc/bash.bashrc'
if rg -n -e "$LINUX_PATTERNS" "$CHAPTER" 2>/dev/null; then
  log_blocker "Linux-ism pattern found in $CHAPTER (see lines above)"
else
  log_ok "No Linux-ism patterns in chapter"
fi

# --- sed -i without backup on macOS (in bash blocks) ---
if rg -n 'sed -i[^ .'"'"'"]' "$CHAPTER" 2>/dev/null | rg -v "sed -i ''" >/dev/null 2>&1; then
  log_warn "Possible GNU sed -i without macOS '' backup — review chapter"
fi

# --- Bash 4+ features ---
BASH4_PATTERNS='mapfile|readarray|declare -A|\|&|wait -n'
if rg -n -e "$BASH4_PATTERNS" "$CHAPTER" ebook/assets/scripts 2>/dev/null; then
  log_warn "Bash 4+ feature detected — ensure Homebrew bash prerequisite or rewrite for 3.2"
else
  log_ok "No Bash 4+ features detected"
fi

# --- Legacy launchctl ---
if rg -n 'launchctl (load|unload)' "$CHAPTER" 2>/dev/null; then
  log_warn "Legacy launchctl load/unload in chapter — prefer bootstrap/bootout for new material"
fi

# --- macos-live: tool presence for CLIs cited in chapter ---
if [[ "$REVIEW_MODE" == "macos-live" ]]; then
  TOOLS=(jq python3 plutil launchctl)
  # extract common CLIs from chapter
  while read -r tool; do
    [[ -z "$tool" ]] && continue
  done < <(rg -o '\b(jq|santactl|osqueryi|osqueryd|sbx|brew|shellcheck|yamllint)\b' "$CHAPTER" 2>/dev/null | sort -u)
  for tool in jq python3 plutil launchctl; do
    if rg -q "\\b${tool}\\b" "$CHAPTER" 2>/dev/null; then
      if command -v "$tool" >/dev/null 2>&1; then
        log_ok "command -v $tool (macos-live)"
      else
        log_warn "Tool cited but not installed: $tool (macos-live)"
      fi
    fi
  done
  for tool in santactl osqueryi sbx; do
    if rg -q "\\b${tool}\\b" "$CHAPTER" 2>/dev/null; then
      if command -v "$tool" >/dev/null 2>&1; then
        log_ok "command -v $tool (macos-live)"
      else
        echo "REQUIRES-MACOS-RUNNER: $tool cited in chapter but not installed on this Mac"
      fi
    fi
  done
else
  for tool in launchctl plutil santactl osqueryi sbx security; do
    if rg -q "\\b${tool}\\b" "$CHAPTER" 2>/dev/null; then
      echo "REQUIRES-MACOS-RUNNER: $tool — re-run on macOS for live verification"
    fi
  done
fi

# --- Hook fixture tests (Ch 23 cursor guards) ---
if [[ -f ebook/assets/scripts/cursor-before-read-guard.sh ]]; then
  if echo '{"file_path":"/Users/me/.ssh/id_ed25519"}' | bash ebook/assets/scripts/cursor-before-read-guard.sh 2>/dev/null | rg -q 'deny'; then
    log_ok "hook deny fixture: cursor-before-read-guard.sh"
  else
    log_warn "hook deny fixture unexpected: cursor-before-read-guard.sh"
  fi
  if echo '{"file_path":"/Users/me/project/README.md"}' | bash ebook/assets/scripts/cursor-before-read-guard.sh 2>/dev/null | rg -q 'allow'; then
    log_ok "hook allow fixture: cursor-before-read-guard.sh"
  else
    log_warn "hook allow fixture unexpected: cursor-before-read-guard.sh"
  fi
fi
if [[ -f ebook/assets/scripts/cursor-before-shell-guard.sh ]]; then
  if echo '{"command":"rm -rf /tmp/lab"}' | bash ebook/assets/scripts/cursor-before-shell-guard.sh 2>/dev/null | rg -q 'deny'; then
    log_ok "hook deny fixture: cursor-before-shell-guard.sh"
  else
    log_warn "hook deny fixture unexpected: cursor-before-shell-guard.sh"
  fi
  if echo '{"command":"ls -la"}' | bash ebook/assets/scripts/cursor-before-shell-guard.sh 2>/dev/null | rg -q 'allow'; then
    log_ok "hook allow fixture: cursor-before-shell-guard.sh"
  else
    log_warn "hook allow fixture unexpected: cursor-before-shell-guard.sh"
  fi
fi

echo "---"
echo "SUMMARY: blockers=$BLOCKERS warnings=$WARNINGS mode=$REVIEW_MODE"
if [[ "$BLOCKERS" -gt 0 ]]; then
  exit 1
fi
exit 0
