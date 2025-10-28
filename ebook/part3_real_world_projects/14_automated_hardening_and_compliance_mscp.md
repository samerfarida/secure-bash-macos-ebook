# Chapter 14: Automated Hardening & Compliance (mSCP)

## Learning Objectives

By the end of this chapter, you will be able to:

1. Explain what the macOS Security Compliance Project (mSCP) is and what it generates (guidance, compliance scripts, configuration profiles, and DDM components).
1. Select an mSCP baseline aligned to your framework (for example, NIST 800‑53r5, CIS, or DISA STIG) and tailor it for your organization.
1. Generate compliance scripts and configuration profiles, and understand where enforcement must be done by MDM/DDM versus shell scripts.
1. Schedule automated audits, emit machine‑readable results (JSON/CSV), and map findings back to control IDs for dashboards or SIEM.
1. Build a minimal Bash‑first verifier that complements mSCP outputs for custom checks, drift detection, and rollup reporting.

## Introduction

The macOS Security Compliance Project (mSCP) is an open‑source, community‑led effort that turns security guidance into programmatically generated outputs for macOS. From a single, versioned source of truth, you can produce documentation, compliance scripts (check/fix), configuration profiles, and Declarative Device Management (DDM) components for deployment with your MDM.

> **Production note: MDM/DDM vs. scripts**  
> PPPC/TCC, Full Disk Access, and most hardening settings must be applied by device management (MDM or DDM). Use scripts primarily to verify and to handle edge‑case remediation.

## 14.1 Quickstart: from zero to your first compliance run

Follow this exact sequence on a build/test Mac.

1. **Install prerequisites**  
   - Python 3  
   - `pip3 install --user pyyaml xlwt` (or install from your package manager)  
   - Git (optional, if cloning rather than downloading)

2. **Get the repository and select the OS branch**  
   - Clone or download the repo, then `git checkout <your‑macOS‑branch>` (for example, `sequoia`).

3. **Generate a compliance script for a baseline**  
   - `./scripts/generate_guidance.py -s baselines/800-53r5_moderate.yaml`

4. **Run the compliance script (zsh)**  
   - `sudo zsh build/800-53r5_moderate/800-53r5_moderate_compliance.sh --cfc --quiet=2`  
   - Results land in `/Library/Preferences/org.800-53r5_moderate.audit.plist` and `/Library/Logs/800-53r5_moderate_baseline.log`.

5. **(Recommended) Generate configuration profiles for MDM/DDM**  
   - Unsigned profiles: `./scripts/generate_guidance.py -p build/baselines/800-53r5_moderate.yaml`  
   - Signed profiles: obtain certificate Subject Key ID, then  
     `./scripts/generate_guidance.py -p -H <SUBJECT_KEY_ID> build/baselines/800-53r5_moderate.yaml`

6. **(Optional) Generate DDM components**  
   - `./scripts/generate_guidance.py -D baselines/all_rules.yaml -p -s`

## 14.2 mSCP outputs at a glance

- **Baselines:** Curated rule sets mapped to frameworks such as NIST 800‑53, 800‑171, DISA STIG, and CIS.
- **Compliance script:** `*_compliance.sh` with check/fix/check (`--cfc`), writing results to an audit plist and baseline log.  
  The generated compliance script is written for **zsh** (invoke from Bash with `zsh …`).
- **Configuration profiles:** `.mobileconfig` files for MDM/DDM enforcement; optionally signed via Subject Key ID.
- **DDM components:** Activations, assets, configurations that devices evaluate locally.
- **Mappings/SCAP/docs:** Optional artifacts (XLS/HTML/PDF) and mapping helpers.

### 14.2.1 Choosing and generating a baseline

If you need a baseline YAML first (for example, to generate profiles from a tailored baseline), use the built‑in baseline helpers and tailor as needed. Otherwise you can point `generate_guidance.py` directly at a provided baseline (for example, `baselines/800-53r5_moderate.yaml`).

### 14.2.2 Generate a compliance script

```bash
# From the OS-matched branch (for example, sequoia):
./scripts/generate_guidance.py -s baselines/800-53r5_moderate.yaml
```

What you get (example; your baseline name will differ):

```
build/800-53r5_moderate/800-53r5_moderate_compliance.sh
build/800-53r5_moderate/preferences/org.800-53r5_moderate.audit.plist
build/800-53r5_moderate/*.html
build/800-53r5_moderate/*.pdf
```

Run it (zsh) non‑interactively and record results:

```bash
sudo zsh build/800-53r5_moderate/800-53r5_moderate_compliance.sh --cfc --quiet=2
# Results:
#  /Library/Preferences/org.800-53r5_moderate.audit.plist
#  /Library/Logs/800-53r5_moderate_baseline.log
```

### 14.2.3 Generate configuration profiles

Unsigned profiles (useful for inspection or uploading to MDM):

```bash
./scripts/generate_guidance.py -p build/baselines/800-53r5_moderate.yaml
```

Signed profiles (Subject Key ID required):

```bash
# Example: extract Subject Key ID (abbreviated approach; adapt to your cert name)
skid=$(security find-certificate -c "Developer ID Application: Example, Inc." -p   | openssl asn1parse | awk -F: '/X509v3 Subject Key Identifier/ {getline; print $1}')

security find-certificate -c "Developer ID Application: Example, Inc." -p   | openssl asn1parse -strparse "$skid" | awk -F: '/HEX DUMP/{print $4}'

# Use the hex value (no spaces) as the -H argument:
./scripts/generate_guidance.py -p -H <SUBJECT_KEY_ID_HEX> build/baselines/800-53r5_moderate.yaml
```

### 14.2.4 Generate DDM components

```bash
./scripts/generate_guidance.py -D baselines/all_rules.yaml -p -s
# Output under: build/<BASELINE>/{activations,assets,configurations}/
```

## 14.3 Operating model: MDM/DDM enforce, scripts verify

### 14.3.1 What must come from device management

- **PPPC/TCC and Full Disk Access** require managed profiles or declarations.
- **System policies** such as Firewall, Gatekeeper, password policy, and login window restrictions should be applied by device management for durability and auditability.

### 14.3.2 Where scripts shine

- **Verification:** Emit machine‑readable pass/fail for SIEM and dashboards.
- **Edge remediation:** Handle legacy or mis‑tuned hosts while you fix policy.
- **Contextual checks:** Validate organization‑specific requirements not in a baseline.

## 14.4 Scheduling audits with launchd

Use a LaunchDaemon to run the baseline’s compliance script (or your own verifier) on a schedule. The following example runs a silent check‑fix‑check daily at 02:00.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.acme.mscp.daily</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>/Library/Security/mSCP/800-53r5_moderate_compliance.sh</string>
    <string>--cfc</string>
    <string>--quiet=2</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>2</integer><key>Minute</key><integer>0</integer></dict>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>/Library/Logs/mscp_compliance.out</string>
  <key>StandardErrorPath</key><string>/Library/Logs/mscp_compliance.err</string>
</dict>
</plist>
```

Install and load:

```bash
sudo install -m 0644 com.acme.mscp.daily.plist /Library/LaunchDaemons/
sudo launchctl bootstrap system /Library/LaunchDaemons/com.acme.mscp.daily.plist
sudo launchctl enable system/com.acme.mscp.daily
sudo launchctl start system/com.acme.mscp.daily
```

## 14.5 A minimal Bash verifier (complement to mSCP)

The generated compliance script is comprehensive, but sometimes you want a small Bash‑first verifier for quick signals (Jamf extension attributes, Munki conditions, or a lightweight cron‑style check). The example below checks common controls and emits compact JSON for dashboards or a SIEM.

### 14.5.1 The verifier script

```bash
#!/usr/bin/env bash
# file: /usr/local/bin/mscp-mini-audit.sh
# Purpose: quick, read-only compliance checks -> JSON rollup
# Compatible with macOS bash 3.2 (no associative arrays)

set -euo pipefail

# Helpers
json_escape() { python - <<'PY' "$1"; import json,sys; print(json.dumps(sys.argv[1])); PY; }

now_epoch="$(date -u +%s)"
host="$(scutil --get ComputerName 2>/dev/null || hostname)"

pass() { printf '{"control_id":"%s","result":"pass"}
' "$1"; }
fail() { printf '{"control_id":"%s","result":"fail","details":%s}
' "$1" "$(json_escape "$2")"; }

# Checks (read-only; enforcement via MDM/DDM)
check_gatekeeper() {
  local status
  status="$(/usr/sbin/spctl --status 2>/dev/null || true)"
  if [[ "$status" == "assessments enabled" ]]; then pass "os_gatekeeper_enable"; else fail "os_gatekeeper_enable" "$status"; fi
}

check_firewall() {
  # Prefer parsing the human-readable state to avoid plist drift
  if /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -qi "enabled"; then
    pass "os_firewall_enable"
  else
    fail "os_firewall_enable" "firewall disabled"
  fi
}

check_filevault() {
  local s; s="$(/usr/bin/fdesetup status 2>/dev/null)" || true
  if echo "$s" | grep -qi "FileVault is On"; then pass "os_filevault_enable"; else fail "os_filevault_enable" "$s"; fi
}

check_password_policy() {
  # Example: minimum length >= 12 (organization choice)
  local len; len="$(/usr/bin/pwpolicy getaccountpolicies 2>/dev/null | awk -F'minLength' 'NF>1{print $2}' | tr -dc '0-9' | head -1)"
  if [[ -n "$len" && "$len" -ge 12 ]]; then pass "pw_policy_min_length"; else fail "pw_policy_min_length" "minLength=${len:-unset}"; fi
}

run_all() {
  check_gatekeeper
  check_firewall
  check_filevault
  check_password_policy
}

# Emit JSON array
{
  echo '{'
  printf '"host":%s,' "$(json_escape "$host")"
  printf '"timestamp":%s,' "$now_epoch"
  echo '"results":['
  run_all | paste -sd, -
  echo ']}'
}
```

### 14.5.2 Shipping results

A simple, generic shipper using `curl` to a webhook (change URL and headers to fit your stack):

```bash
#!/usr/bin/env bash
set -euo pipefail
payload="$(/usr/local/bin/mscp-mini-audit.sh)"
curl -sS -X POST https://siem.example.com/intake   -H 'Content-Type: application/json'   --data-binary "$payload" -o /dev/null
```

## 14.6 Tailoring and exemptions

mSCP supports tailoring (choosing rules) and exemptions (documenting exceptions with reasons), tracked in the audit plist and logs. Use tailoring to align with business risk, then capture exemptions with justification so you remain auditable.

## 14.7 User experience: prompting and guidance

When hardening requires user action (for example, reboots, login/logout, or deferrals), pair enforcement with clear messaging:

- swiftDialog for pre/post prompts, progress, or “this will reboot” warnings.
- Nudge for user‑friendly OS‑update nudging once you have set deadlines via MDM/DDM.

Example: lightweight pre‑check prompt before a remediation window with swiftDialog:

```bash
#!/usr/bin/env bash
dialog --title "Compliance Window"   --message "Your Mac will run a security compliance check. Save work now."   --button1text "OK"
```

## 14.8 Reporting and dashboards

- Compliance script stats: use `--stats`, `--compliant`, and `--non_compliant` to summarize the last run.
- SIEM: ingest your JSON from section 14.5 and join to device identity.
- Executive views: map counts back to framework IDs (for example, 800‑53 AC‑2). If you used the mapping generator, you already have the translation CSV.

## 14.9 Troubleshooting

- **Wrong branch:** If output or rule coverage looks off, verify you are on the OS‑matched branch.
- **Profiles not taking effect:** Confirm MDM scope and conflicts. PPPC/TCC require supervision and managed profiles.
- **Compliance script shell:** If you see syntax errors in Bash, run with `zsh` as required.
- **DDM not applying:** Ensure your MDM supports DDM on the target OS and you delivered the correct activations, assets, and configurations.

## macOS Scripting Tips

- **Bash 3.2 vs 5:** If you author your own verifiers, stick to Bash 3.2‑compatible syntax (ships with macOS) unless you deploy a Bash 5 runtime.
- **Apple silicon paths:** If you reference Homebrew tools in checks, use `/opt/homebrew` on Apple silicon.
- **Managed preferences:** Many profile‑applied settings surface in `/Library/Managed Preferences/` as plists you can read with `plutil -p` (read‑only for verification).

## Chapter 14 Exercise

**Build a compliance pipeline:**

1. Generate a compliance script for your chosen baseline and run `--check` and `--cfc`.
1. Generate configuration profiles for the same baseline and scope them via your MDM.
1. Create a LaunchDaemon to run nightly and ship the audit plist/log summary to your SIEM.
1. Add your mini‑audit JSON to the SIEM and build a simple dashboard showing pass/fail by control ID.

## References and Further Reading

- mSCP introduction and docs: https://pages.nist.gov/macos_security/welcome/introduction/
- Getting Started (prerequisites and branches): https://pages.nist.gov/macos_security/welcome/getting-started/
- Generate compliance scripts: https://pages.nist.gov/macos_security/compliance-scripts/how-to-generate-compliance-scripts/
- Compliance script layout and flags: https://pages.nist.gov/macos_security/compliance-scripts/compliance-script-layout/
- Generate configuration profiles: https://pages.nist.gov/macos_security/configuration-profiles/how-to-generate-configuration-profiles/
- Generate DDM components: https://pages.nist.gov/macos_security/ddm-components/how-to-generate-ddm-components/
- Script arguments list: https://pages.nist.gov/macos_security/repository/script-arguments-list/