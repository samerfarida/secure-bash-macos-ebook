# Chapter 14: Automated Hardening & Compliance (mSCP)

## Learning Objectives

By the end of this chapter, you will be able to:

1. Explain what the macOS Security Compliance Project (mSCP) is and what it generates (guidance, compliance scripts, configuration profiles, and DDM components).
2. Select an mSCP baseline aligned to your framework (for example, NIST 800‑53r5, CIS, or DISA STIG) and tailor it for your organization.
3. Generate compliance scripts and configuration profiles, and understand where enforcement must be done by MDM/DDM versus shell scripts.
4. Schedule automated audits, emit machine‑readable results (JSON/CSV), and map findings back to control IDs for dashboards or SIEM.
5. Build a minimal Bash‑first verifier that complements mSCP outputs for custom checks, drift detection, and rollup reporting.

## Introduction

The macOS Security Compliance Project (mSCP) is an open‑source, community‑led effort that turns security guidance into programmatically generated outputs for macOS. From a single, versioned source of truth, you can produce documentation, compliance scripts (check/fix), configuration profiles, and Declarative Device Management (DDM) components for deployment with your MDM.

In enterprise environments, compliance with security frameworks is not optional—it's a requirement for doing business. Whether you're subject to NIST 800-53 (federal government contractors), DISA STIG (Department of Defense), CIS Benchmarks (industry standards), or HIPAA/PCI-DSS requirements, you need demonstrable evidence that your macOS fleet meets defined security controls. Manual audits don't scale, and ad-hoc hardening scripts drift over time, creating compliance gaps that surface only during audits.

mSCP bridges this gap by providing:

- **Standardized baselines** aligned to recognized security frameworks
- **Automated verification** that scales across thousands of devices
- **Machine-readable outputs** that feed directly into compliance dashboards and SIEMs
- **Reproducible enforcement** through configuration profiles and DDM declarations

> **Production note: MDM/DDM vs. scripts**  
> PPPC/TCC, Full Disk Access, and most hardening settings must be applied by device management (MDM or DDM). Use scripts primarily to verify and to handle edge‑case remediation.

## Why mSCP Matters: Business Drivers and Enterprise Context

Enterprise macOS administrators face increasing pressure to demonstrate compliance with security frameworks while managing fleets that can number in the thousands. Traditional approaches—manual checklists, periodic audits, or one-off hardening scripts—fail at scale and create compliance drift over time.

### Compliance Requirements Drive Automation

**Regulatory Frameworks:**

- **NIST 800-53**: Required for federal agencies and contractors; controls span access control, audit logging, system integrity
- **DISA STIG**: Department of Defense security requirements; often the most stringent baseline
- **CIS Benchmarks**: Industry-standard hardening guidance; frequently cited in insurance and procurement requirements
- **HIPAA/PCI-DSS**: Healthcare and payment processing industries require demonstrable security controls

**Audit Scenarios:**

- Annual compliance audits require evidence of continuous monitoring
- Vendor security assessments demand proof of baseline adherence
- Insurance and procurement processes may require compliance attestation
- Incident response requires demonstrating that controls were in place

### Operational Challenges mSCP Solves

**Scale and Consistency:**

- Manual verification doesn't scale beyond dozens of devices
- Configuration drift accumulates over time as users install software or change settings
- Different administrators may apply hardening inconsistently across devices

**Continuous Monitoring:**

- Compliance is not a point-in-time achievement; it requires ongoing verification
- Security teams need visibility into fleet compliance status
- Non-compliance must be detected and remediated quickly

**Framework Alignment:**

- Organizations often need to demonstrate compliance with multiple frameworks simultaneously
- mSCP baselines are pre-mapped to control IDs (e.g., NIST AC-2, CIS 1.1.1)
- Reports can be generated for auditors showing control-by-control compliance

**Integration with Existing Tools:**

- mSCP outputs integrate with SIEM platforms for security monitoring
- Configuration profiles deploy through existing MDM infrastructure
- Compliance data feeds into asset management and reporting systems

## 14.1 Prerequisites and Setup Requirements

Before generating your first compliance baseline, ensure your build environment meets these requirements. This section covers prerequisites in detail, validation steps, and considerations for different deployment scenarios.

### System Requirements

**Build/Test Mac:**

- macOS 12.0 (Monterey) or later for building baselines
- Python 3.8 or later (Python 3.9+ recommended)
- Administrator access for installing dependencies and testing generated scripts
- Minimum 2 GB free disk space for repository and generated artifacts

**Target Devices:**

- Generated compliance scripts target specific macOS versions (branches)
- Configuration profiles and DDM components require compatible MDM
- Verification scripts run on macOS 10.15+ with appropriate permissions

### Required Software and Tools

**Python 3:**

```bash
# Verify Python version (macOS includes Python 3.9+ on recent releases)
python3 --version
# Should show Python 3.8 or later

# If Python 3 is not available, install via Homebrew
brew install python3
```

**Python Dependencies:**

```bash
# Install required packages
pip3 install --user pyyaml xlwt

# Verify installation
python3 -c "import yaml, xlwt; print('Dependencies OK')"
```

**Optional but Recommended:**

- **Git**: For version control of tailored baselines and generated artifacts

  ```bash
  git --version  # Verify Git is installed
  # If not: xcode-select --install (includes Git) or brew install git
  ```

- **jq**: For parsing JSON outputs (useful for custom scripts)

  ```bash
  brew install jq
  ```

### Version Compatibility and Validation

**mSCP Repository Branches:**

- mSCP maintains separate branches for each macOS major version
- Always use the branch matching your target macOS version
- Common branches: `sonoma`, `ventura`, `monterey`, `sequoia`
- Check available branches: `git branch -r` after cloning

**Validating Your Setup:**

```bash
# Test Python and dependencies
python3 -c "import yaml, xlwt; print('Python dependencies: OK')"

# Verify Git (if cloning)
git --version

# Check disk space
df -h . | awk 'NR==2{print "Free space: " $4}'
```

### Build Environment Considerations

**Development Workflow:**

- Use a dedicated build Mac or isolated VM for generating baselines
- Keep generated artifacts in version control for reproducibility
- Test generated scripts in a non-production environment first

**Network Access:**

- Build machine needs internet access to clone mSCP repository
- Target devices need MDM connectivity for profile deployment
- SIEM/webhook endpoints must be reachable for compliance reporting

### MDM Prerequisites (for Deployment)

**MDM Platform Requirements:**

- MDM must support configuration profile deployment
- For DDM components: macOS 14+ and MDM with DDM support required
- PPPC/TCC profiles require supervised devices or managed user enrollment

**Certificate Requirements (Optional but Recommended):**

- Developer ID certificate for signing configuration profiles
- Subject Key ID needed for signed profile generation
- Certificate should be in your login or System keychain

### Next Steps

Once prerequisites are validated, proceed to Section 14.2 to understand compliance frameworks and baseline selection before generating your first compliance script.

## 14.2 Understanding Your Compliance Framework

Before selecting a baseline, you need to understand which security framework aligns with your organization's requirements. Different frameworks serve different industries and use cases, and some organizations must comply with multiple frameworks simultaneously.

### Common Security Frameworks and Their Use Cases

**NIST 800-53:**

- **Primary Use**: Federal government agencies and contractors
- **Structure**: Control families (AC=Access Control, AU=Audit, CM=Configuration Management)
- **Baseline Options**:
  - `800-53r5_moderate.yaml`: Moderate impact systems (most common)
  - `800-53r5_low.yaml`: Low impact systems
  - `800-53r5_high.yaml`: High impact systems
- **mSCP Coverage**: Comprehensive mapping to 800-53r5 control IDs

**NIST 800-171:**

- **Primary Use**: Non-federal organizations handling Controlled Unclassified Information (CUI)
- **Structure**: 110 controls organized into 14 families
- **Baseline Options**: `800-171r2.yaml`
- **Common Use Case**: Defense contractors, research institutions with federal grants

**DISA STIG:**

- **Primary Use**: Department of Defense systems
- **Structure**: Security Technical Implementation Guides with specific rule IDs
- **Baseline Options**: `disa_stig.yaml`
- **Characteristics**: Often the most restrictive baseline; may conflict with user productivity requirements

**CIS Benchmarks:**

- **Primary Use**: Industry-standard hardening guidance
- **Structure**: Level 1 (basic) and Level 2 (advanced) recommendations
- **Baseline Options**: `cis_level1.yaml`, `cis_level2.yaml`
- **Advantages**: Well-documented, widely accepted, balanced security vs. usability

### Selecting the Right Baseline for Your Organization

**Decision Criteria:**

1. **Regulatory Requirements:**
   - Do you have contractual or legal obligations to specific frameworks?
   - Are you subject to industry-specific regulations (HIPAA, PCI-DSS)?
   - Must you demonstrate compliance to auditors or partners?

2. **Risk Tolerance:**
   - High-security environments (defense, finance) may require DISA STIG or NIST High
   - Commercial enterprises often balance CIS Level 1/2 or NIST Moderate
   - Development/test environments may use relaxed baselines

3. **Operational Impact:**
   - More restrictive baselines may break user workflows
   - Consider user experience and business process impact
   - Plan for exceptions and exemptions (see Section 14.6)

**Real-World Scenarios:**

**Scenario A: Federal Contractor (Defense)**

- Required: DISA STIG or NIST 800-53 High
- Baseline: `disa_stig.yaml` or `800-53r5_high.yaml`
- Challenge: Balancing security with developer productivity
- Solution: Tailor baseline to exclude development tools, document exemptions

**Scenario B: Healthcare Provider (HIPAA)**

- Required: HIPAA security rule (no formal mSCP baseline, but NIST 800-53 Moderate aligns well)
- Baseline: `800-53r5_moderate.yaml` with custom additions
- Challenge: Must protect PHI while maintaining clinical workflow
- Solution: Focus on encryption (FileVault), access controls, audit logging

**Scenario C: Commercial Enterprise**

- Required: Industry best practices, insurance requirements
- Baseline: `cis_level1.yaml` or `800-53r5_moderate.yaml`
- Challenge: Minimal user disruption while maintaining security posture
- Solution: Start with CIS Level 1, gradually adopt Level 2 controls

**Scenario D: Multi-Framework Compliance**

- Required: Multiple frameworks (e.g., NIST 800-53 + CIS)
- Approach: Select most restrictive baseline, then add controls from others
- Baseline: Start with `800-53r5_moderate.yaml`, supplement with CIS controls
- Challenge: Avoiding conflicts and redundant controls

### Framework Mapping and Control IDs

Each framework uses its own control identification system:

- **NIST 800-53**: Control families and IDs (e.g., AC-2, AU-3)
- **DISA STIG**: Rule IDs (e.g., V-220763)
- **CIS**: Benchmark recommendations (e.g., 1.1.1, 1.1.2)

mSCP generates mappings between controls and macOS-specific implementations. When generating compliance scripts, you'll see control IDs in:

- Compliance script output (audit plist)
- Generated documentation (HTML/PDF)
- Mapping spreadsheets (XLS format)

These mappings are essential for:

- Audit reports showing compliance by control ID
- SIEM dashboards correlating findings to framework requirements
- Executive reporting translating technical findings to business language

### Tailoring Baselines: When and Why

**Before Generating:**

- Review baseline YAML files to understand included rules
- Identify controls that conflict with your operational needs
- Plan for exemptions (e.g., development tools, specialized software)

**After Generating:**

- Use mSCP's tailoring mechanisms to disable specific controls
- Document business justifications for exceptions
- Track exemptions in audit logs for compliance visibility

See Section 14.7 for detailed tailoring workflows and exemption management.

## 14.3 Quickstart: Your First Compliance Run

Now that you understand compliance frameworks and have selected an appropriate baseline, follow this step-by-step sequence to generate and run your first compliance check on a build/test Mac.

### Step 1: Get the Repository and Select OS Branch

```bash
# Clone the mSCP repository
git clone https://github.com/usnistgov/macos_security.git
cd macos_security

# Check available branches for your macOS version
git branch -r | grep -E "sequoia|sonoma|ventura"

# Checkout the branch matching your target macOS version
git checkout sequoia  # Replace with your macOS version branch name
```

> **Important**: Always use the branch that matches your target macOS version. Using the wrong branch may result in incorrect or missing controls.

### Step 2: Generate a Compliance Script

After selecting your baseline (see Section 14.2), generate the compliance script:

```bash
# Generate compliance script for NIST 800-53 Moderate baseline
./scripts/generate_guidance.py -s baselines/800-53r5_moderate.yaml

# Output will be in build/800-53r5_moderate/
ls -la build/800-53r5_moderate/
```

This creates the compliance script, audit plist template, and documentation artifacts.

### Step 3: Run the Compliance Script

Execute the generated script with appropriate flags:

```bash
# Run check-fix-check cycle (non-interactive)
sudo zsh build/800-53r5_moderate/800-53r5_moderate_compliance.sh --cfc --quiet=2

# Results are written to:
# - /Library/Preferences/org.800-53r5_moderate.audit.plist
# - /Library/Logs/800-53r5_moderate_baseline.log
```

**Flag Explanation:**

- `--cfc`: Check-fix-check cycle (checks compliance, fixes issues, checks again)
- `--quiet=2`: Minimal output (use `--quiet=0` for verbose debugging)

### Step 4: Generate Configuration Profiles (Recommended)

Create configuration profiles for MDM deployment:

```bash
# Generate unsigned profiles (for MDM upload)
./scripts/generate_guidance.py -p build/baselines/800-53r5_moderate.yaml

# Or generate signed profiles (requires Subject Key ID - see Section 14.3.4)
# ./scripts/generate_guidance.py -p -H <SUBJECT_KEY_ID> build/baselines/800-53r5_moderate.yaml
```

Profiles are generated in `build/800-53r5_moderate/profiles/` directory.

### Step 5: (Optional) Generate DDM Components

For macOS 14+ with DDM-capable MDM:

```bash
./scripts/generate_guidance.py -D baselines/all_rules.yaml -p -s
```

DDM components are created in `build/<BASELINE>/{activations,assets,configurations}/` directories.

### Step 6: Review Results

Check compliance status:

```bash
# View audit plist results
plutil -p /Library/Preferences/org.800-53r5_moderate.audit.plist | head -50

# Check compliance log
tail -50 /Library/Logs/800-53r5_moderate_baseline.log

# Use compliance script's built-in stats
sudo zsh build/800-53r5_moderate/800-53r5_moderate_compliance.sh --stats
```

Next, proceed to Section 14.4 to understand mSCP outputs in detail before deploying to production.

## 14.4 mSCP outputs at a glance

- **Baselines:** Curated rule sets mapped to frameworks such as NIST 800‑53, 800‑171, DISA STIG, and CIS.
- **Compliance script:** `*_compliance.sh` with check/fix/check (`--cfc`), writing results to an audit plist and baseline log.  
  The generated compliance script is written for **zsh** (invoke from Bash with `zsh …`).
- **Configuration profiles:** `.mobileconfig` files for MDM/DDM enforcement; optionally signed via Subject Key ID.
- **DDM components:** Activations, assets, configurations that devices evaluate locally.
- **Mappings/SCAP/docs:** Optional artifacts (XLS/HTML/PDF) and mapping helpers.

### 14.4.1 Choosing and generating a baseline

If you need a baseline YAML first (for example, to generate profiles from a tailored baseline), use the built‑in baseline helpers and tailor as needed. Otherwise you can point `generate_guidance.py` directly at a provided baseline (for example, `baselines/800-53r5_moderate.yaml`).

### 14.4.2 Generate a compliance script

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

### 14.4.3 Generate configuration profiles

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

### 14.4.4 Generate DDM components

```bash
./scripts/generate_guidance.py -D baselines/all_rules.yaml -p -s
# Output under: build/<BASELINE>/{activations,assets,configurations}/
```

## 14.5 Operating model: MDM/DDM enforce, scripts verify

### 14.5.1 What must come from device management

- **PPPC/TCC and Full Disk Access** require managed profiles or declarations.
- **System policies** such as Firewall, Gatekeeper, password policy, and login window restrictions should be applied by device management for durability and auditability.

### 14.5.2 Where scripts shine

- **Verification:** Emit machine‑readable pass/fail for SIEM and dashboards.
- **Edge remediation:** Handle legacy or mis‑tuned hosts while you fix policy.
- **Contextual checks:** Validate organization‑specific requirements not in a baseline.

## 14.6 Scheduling audits with launchd

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

## 14.7 A minimal Bash verifier (complement to mSCP)

The generated compliance script is comprehensive, but sometimes you want a small Bash‑first verifier for quick signals (Jamf extension attributes, Munki conditions, or a lightweight cron‑style check). The example below checks common controls and emits compact JSON for dashboards or a SIEM.

### 14.6.1 The verifier script

```bash
#!/bin/bash
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

### 14.6.2 Shipping results

A simple, generic shipper using `curl` to a webhook (change URL and headers to fit your stack):

```bash
#!/bin/bash
set -euo pipefail
payload="$(/usr/local/bin/mscp-mini-audit.sh)"
curl -sS -X POST https://siem.example.com/intake   -H 'Content-Type: application/json'   --data-binary "$payload" -o /dev/null
```

## 14.8 Tailoring and exemptions

mSCP supports tailoring (choosing rules) and exemptions (documenting exceptions with reasons), tracked in the audit plist and logs. Use tailoring to align with business risk, then capture exemptions with justification so you remain auditable.

### Understanding Tailoring vs. Exemptions

**Tailoring** occurs before baseline generation—you modify which rules are included in the baseline itself. This is appropriate for:

- Organization-wide policy decisions (e.g., "we don't use Xcode, so exclude development tool controls")
- Framework-specific requirements that don't apply to your environment
- Controls that conflict with business-critical workflows at the organizational level

**Exemptions** occur after deployment—specific devices or users are excluded from certain controls with documented justification. This is appropriate for:

- Legacy devices that cannot meet all requirements
- Specialized use cases (research, development) requiring relaxed controls
- Temporary exceptions while remediation is in progress

### Real-World Tailoring Examples

**Example 1: Development Environment Baseline**

Your organization maintains separate security baselines for development and production Macs. Development Macs need Xcode and command-line tools, which conflict with some restrictive controls.

**Approach:**

1. Generate a base NIST 800-53 Moderate baseline
2. Review the YAML file for development tool restrictions
3. Tailor the baseline to exclude or modify controls that block:
   - Developer tools installation
   - Code signing requirements for local builds
   - Network debugging tools

**Implementation:**

```bash
# Create a tailored baseline for development
cp baselines/800-53r5_moderate.yaml baselines/800-53r5_moderate_dev.yaml

# Edit the YAML file to exclude/modify development tool controls
# Then generate from the tailored baseline
./scripts/generate_guidance.py -s baselines/800-53r5_moderate_dev.yaml
```

**Documentation:**

- Maintain a changelog of tailored controls with business justification
- Track which devices use the tailored baseline in your asset management system
- Review tailored baselines annually for continued relevance

**Example 2: Healthcare Environment with Clinical Applications**

A hospital IT department must comply with HIPAA while maintaining clinical workflow. Some CIS/NIST controls conflict with medical device software requirements.

**Approach:**

1. Start with NIST 800-53 Moderate baseline
2. Identify controls that conflict with:
   - Medical device drivers requiring kernel extensions
   - Legacy PACS (Picture Archiving) systems with specific security requirements
   - Point-of-care devices that cannot be fully managed

**Tailoring Strategy:**

- Tailor baseline to relax kernel extension restrictions (where medically necessary)
- Document specific medical device exceptions with vendor justifications
- Implement compensating controls (network segmentation, audit logging)

**Exemption Management:**

```bash
# Run compliance script with exemption tracking
sudo zsh compliance.sh --cfc --quiet=2

# Review audit plist for exemptions
plutil -p /Library/Preferences/org.800-53r5_moderate.audit.plist | grep -A 5 "exemption"

# Document exemptions in your compliance database
```

**Example 3: Financial Services with Trading Floor Requirements**

A financial services firm requires high security but trading floor applications have unique latency and connectivity requirements that conflict with some network controls.

**Approach:**

1. Use DISA STIG baseline as starting point (high security requirement)
2. Tailor network-related controls to allow:
   - Low-latency trading platform connections
   - Real-time market data feeds
   - Direct exchange connectivity requirements

**Tailoring Process:**

- Work with security and business stakeholders to identify acceptable risk
- Tailor controls with compensating monitoring (enhanced logging, network monitoring)
- Document business justification for each tailored control
- Maintain separation between trading and corporate networks

**Example 4: Multi-Framework Compliance (NIST + CIS)**

An organization must demonstrate compliance with both NIST 800-53 and CIS Benchmarks simultaneously.

**Approach:**

1. Generate NIST 800-53 Moderate baseline
2. Compare against CIS Level 1 and Level 2 controls
3. Identify gaps (controls in CIS but not NIST)
4. Create a merged baseline or run both baselines in parallel

**Practical Implementation:**

```bash
# Generate both baselines
./scripts/generate_guidance.py -s baselines/800-53r5_moderate.yaml
./scripts/generate_guidance.py -s baselines/cis_level1.yaml

# Run both compliance scripts and merge results
sudo zsh build/800-53r5_moderate/800-53r5_moderate_compliance.sh --check
sudo zsh build/cis_level1/cis_level1_compliance.sh --check

# Merge audit results for unified reporting
```

**Reporting Strategy:**

- Map findings to both framework control IDs
- Generate separate reports for each framework's auditors
- Maintain a cross-reference mapping between frameworks

### Managing Exemptions at Scale

**Exemption Workflow:**

1. **Identify Need**: Non-compliant device or control that cannot be remediated immediately
2. **Document Justification**: Business reason, risk assessment, remediation plan
3. **Track Exemption**: Record in compliance database or SIEM
4. **Review Periodically**: Quarterly exemption review to determine if still needed
5. **Remediate or Renew**: Either fix the issue or renew exemption with updated justification

**Exemption Tracking Script Example:**

```bash
#!/bin/bash
# track_exemption.sh - Log exemption in compliance system

CONTROL_ID="$1"
DEVICE_SERIAL="$2"
JUSTIFICATION="$3"
EXPIRY_DATE="$4"

# Log to local audit plist (custom field)
/usr/libexec/PlistBuddy -c "Add :exemptions:${CONTROL_ID} dict" \
  /Library/Preferences/org.800-53r5_moderate.audit.plist 2>/dev/null || true

/usr/libexec/PlistBuddy -c "Add :exemptions:${CONTROL_ID}:serial string ${DEVICE_SERIAL}" \
  /Library/Preferences/org.800-53r5_moderate.audit.plist

/usr/libexec/PlistBuddy -c "Add :exemptions:${CONTROL_ID}:justification string ${JUSTIFICATION}" \
  /Library/Preferences/org.800-53r5_moderate.audit.plist

/usr/libexec/PlistBuddy -c "Add :exemptions:${CONTROL_ID}:expiry date ${EXPIRY_DATE}" \
  /Library/Preferences/org.800-53r5_moderate.audit.plist

# Also ship to SIEM for centralized tracking
curl -X POST https://compliance.example.com/api/exemptions \
  -H "Content-Type: application/json" \
  -d "{\"control_id\":\"${CONTROL_ID}\",\"device\":\"${DEVICE_SERIAL}\",\"reason\":\"${JUSTIFICATION}\"}"
```

### Best Practices for Tailoring and Exemptions

1. **Start Strict, Then Tailor**: Begin with full baseline, then tailor based on proven need
2. **Document Everything**: Every tailored control or exemption needs business justification
3. **Regular Review**: Quarterly review of exemptions to ensure they're still necessary
4. **Risk Assessment**: Evaluate security impact of each tailoring decision
5. **Compensating Controls**: Where possible, implement alternative security measures
6. **Version Control**: Track baseline versions and tailoring changes over time
7. **Audit Trail**: Maintain clear audit trail of who approved exemptions and when

## 14.9 User experience: prompting and guidance

When hardening requires user action (for example, reboots, login/logout, or deferrals), pair enforcement with clear messaging:

- swiftDialog for pre/post prompts, progress, or “this will reboot” warnings.
- Nudge for user‑friendly OS‑update nudging once you have set deadlines via MDM/DDM.

Example: lightweight pre‑check prompt before a remediation window with swiftDialog:

```bash
#!/bin/bash
dialog --title "Compliance Window"   --message "Your Mac will run a security compliance check. Save work now."   --button1text "OK"
```

## 14.10 Reporting and dashboards

- Compliance script stats: use `--stats`, `--compliant`, and `--non_compliant` to summarize the last run.
- SIEM: ingest your JSON from section 14.5 and join to device identity.
- Executive views: map counts back to framework IDs (for example, 800‑53 AC‑2). If you used the mapping generator, you already have the translation CSV.

## 14.11 Rolling Out to Production

Deploying compliance baselines across a large fleet requires careful planning, phased rollouts, and continuous monitoring. This section provides a structured approach to production deployment based on enterprise operational best practices.

### Pre-Deployment Planning

**Define Success Criteria:**

- Target compliance percentage (e.g., 95% of devices compliant within 30 days)
- Acceptable false positive rate (aim for <5%)
- Performance impact thresholds (compliance checks should not degrade user experience)
- Remediation SLA (time to fix non-compliant devices)

**Identify Stakeholders:**

- Security team: Define compliance requirements and risk tolerance
- IT operations: Execute deployment and remediation
- Help desk: Handle user issues and exceptions
- Business units: Approve exemptions and understand operational impact
- Compliance/audit: Validate reporting and attestation

**Create Baseline Documentation:**

- Document which baseline you're using and why
- List all tailored controls and business justifications
- Define exemption policy and approval process
- Create runbooks for common scenarios (see Section 14.10.3)

### Ring-Based Deployment Strategy

Deploy compliance baselines in phases to minimize risk and catch issues early:

**Ring 1: Pilot (1-5% of fleet)**

- **Participants**: IT team, security team, power users
- **Duration**: 2-4 weeks
- **Goals**:
  - Validate baseline works in production environment
  - Identify false positives and operational issues
  - Refine tailoring and exemptions
- **Success Criteria**:
  - >90% compliance rate
  - <10 help desk tickets per 100 devices
  - No critical business process disruptions

**Ring 2: Canary (10-15% of fleet)**

- **Participants**: Representative sample across departments and device types
- **Duration**: 2-3 weeks
- **Goals**:
  - Validate scaling to larger population
  - Test remediation workflows
  - Identify department-specific issues
- **Success Criteria**:
  - >85% compliance rate
  - Remediation process proven
  - No widespread user complaints

**Ring 3: Broad Deployment (80%+ of fleet)**

- **Participants**: Remaining production devices
- **Duration**: Phased over 4-8 weeks (weekly increments)
- **Approach**:
  - Deploy by department, geography, or device type
  - Monitor compliance rates and help desk tickets
  - Pause if issues exceed thresholds
- **Success Criteria**:
  - >80% compliance rate
  - Stable remediation process
  - User education reducing support load

**Ring 4: Hardening (Final 5-10%)**

- **Participants**: Legacy devices, specialized systems, problematic cases
- **Duration**: Ongoing
- **Goals**:
  - Individual remediation and exemption handling
  - Replacement planning for non-compliant hardware
  - Continuous improvement

### Deployment Workflow

**Step 1: Prepare Baseline and Profiles**

```bash
# Generate baseline with your tailored configuration
./scripts/generate_guidance.py -s baselines/800-53r5_moderate.yaml

# Generate unsigned profiles for MDM upload
./scripts/generate_guidance.py -p build/baselines/800-53r5_moderate.yaml

# Review generated profiles before deployment
open build/800-53r5_moderate/profiles/*.mobileconfig
```

**Step 2: Deploy Configuration Profiles via MDM**

- Upload profiles to MDM console
- Scope to Ring 1 pilot group
- Set deployment priority (higher priority = applied first)
- Configure conflicts and removal policies

**Step 3: Deploy Compliance Script**

- Package compliance script as installer or deploy via MDM script
- Install LaunchDaemon for scheduled execution
- Configure logging and result shipping

**Step 4: Monitor and Validate**

- Monitor compliance dashboard for initial results
- Review help desk tickets for user impact
- Validate audit plists on sample devices
- Check SIEM for compliance events

**Step 5: Iterate and Refine**

- Address false positives through tailoring
- Process exemptions with proper documentation
- Adjust remediation workflows based on feedback
- Proceed to next ring when success criteria met

### Remediation Workflows

**Automated Remediation (via Scripts):**

- Compliance script with `--cfc` (check-fix-check) attempts automatic remediation
- Log all remediation actions for audit trail
- Alert on remediation failures requiring manual intervention

**Manual Remediation (via MDM Policies):**

- Create MDM policies for common non-compliance scenarios
- Trigger policies based on compliance script exit codes
- Document remediation steps in help desk knowledge base

**Example Remediation Policy (Jamf):**

```bash
#!/bin/bash
# Remediate common compliance issues

# Fix firewall if disabled
if ! /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | grep -q "enabled"; then
    /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    echo "Firewall enabled"
fi

# Enable Gatekeeper if disabled
if ! spctl --status | grep -q "enabled"; then
    spctl --master-enable
    echo "Gatekeeper enabled"
fi

# Log remediation actions
logger -t compliance "Remediation script executed: $(date)"
```

### Monitoring and Reporting

**Real-Time Monitoring:**

- SIEM dashboard showing compliance status by device, department, control ID
- Alert on compliance drop below threshold (e.g., <90%)
- Track remediation time (time from non-compliance detection to fix)

**Regular Reporting:**

- Weekly compliance summary by department
- Monthly executive dashboard with trend analysis
- Quarterly audit reports with control-by-control compliance

**Example Compliance Dashboard Queries (Splunk):**

```spl
# Overall compliance rate
index=compliance | stats count by compliant | eval pct=round(count/total*100,2)

# Top non-compliant controls
index=compliance compliant=false | stats count by control_id | sort -count | head 10

# Compliance by department
index=compliance | lookup department_lookup hostname OUTPUT department | stats count by department, compliant
```

### Rollback Procedures

**When to Rollback:**

- Compliance rate drops below 70% in any ring
- Critical business process disrupted (e.g., trading platform blocked)
- High false positive rate (>20%)
- Performance degradation affecting >10% of users

**Rollback Steps:**

1. **Immediate Actions:**
   - Pause profile deployment to next ring
   - Remove compliance profiles from affected devices (via MDM)
   - Stop scheduled compliance scripts (disable LaunchDaemon)

2. **Analysis:**
   - Root cause analysis of issues
   - Identify specific controls or profiles causing problems
   - Document lessons learned

3. **Remediation:**
   - Tailor baseline to address issues
   - Update profiles and regenerate
   - Revise deployment plan based on findings

4. **Resume Deployment:**
   - Restart from appropriate ring after fixes validated
   - Extend pilot phase if needed
   - Update success criteria based on learnings

### Communication and Change Management

**Stakeholder Communication:**

- Executive summary: Why compliance matters, business impact, timeline
- IT communication: Technical details, deployment schedule, support process
- User communication: What changes, impact on daily work, how to get help

**Change Management Best Practices:**

- Provide advance notice (2-4 weeks before deployment)
- Offer training sessions or documentation for common scenarios
- Establish clear escalation path for issues
- Create FAQ addressing common concerns

### Post-Deployment Operations

**Ongoing Maintenance:**

- Monthly review of compliance metrics and trends
- Quarterly review of exemptions and tailoring decisions
- Annual baseline refresh (regenerate from updated mSCP repository)
- Continuous monitoring of new macOS versions and baseline updates

**Continuous Improvement:**

- Regular feedback collection from help desk and users
- Analysis of false positives to refine tailoring
- Automation of common remediation tasks
- Integration with vulnerability management and patch deployment

**Documentation Updates:**

- Maintain runbooks with lessons learned
- Update exemption policy based on patterns
- Document common issues and solutions
- Keep baseline version history and change log

## 14.12 Troubleshooting

This section addresses common issues encountered when deploying mSCP-based compliance in enterprise environments, with specific attention to MDM integration, profile deployment, and operational challenges.

### Common Build and Generation Issues

**Wrong Branch:**

- **Symptom**: Generated scripts report incorrect OS versions or missing controls for your macOS version
- **Cause**: Using mSCP branch that doesn't match target macOS version
- **Solution**:

  ```bash
  # Verify current branch
  git branch
  
  # Switch to correct branch (e.g., sequoia for macOS 15)
  git checkout sequoia
  
  # Regenerate baseline
  ./scripts/generate_guidance.py -s baselines/800-53r5_moderate.yaml
  ```

- **Prevention**: Document which mSCP branch corresponds to each macOS version in your deployment documentation

**Python Dependency Errors:**

- **Symptom**: `ModuleNotFoundError: No module named 'yaml'` or similar
- **Cause**: Missing Python dependencies or wrong Python version
- **Solution**:

  ```bash
  # Verify Python version (need 3.8+)
  python3 --version
  
  # Install dependencies
  pip3 install --user pyyaml xlwt
  
  # Verify installation
  python3 -c "import yaml, xlwt; print('OK')"
  ```

**Generation Fails with YAML Errors:**

- **Symptom**: Syntax errors when generating baseline
- **Cause**: Corrupted baseline YAML file or manual edits with syntax errors
- **Solution**:
  - Validate YAML syntax: `python3 -c "import yaml; yaml.safe_load(open('baselines/800-53r5_moderate.yaml'))"`
  - Restore from git if manually edited: `git checkout baselines/800-53r5_moderate.yaml`
  - If tailoring, use version control to track changes

### Compliance Script Execution Issues

**Shell Syntax Errors:**

- **Symptom**: `syntax error near unexpected token` when running compliance script
- **Cause**: Generated scripts are written for zsh, but being executed with bash
- **Solution**: Always invoke with `zsh`:

  ```bash
  sudo zsh /Library/Security/mSCP/800-53r5_moderate_compliance.sh --cfc
  ```

- **Prevention**: Update LaunchDaemon plists to use `/bin/zsh` explicitly

**Permission Denied Errors:**

- **Symptom**: Script fails with "Permission denied" even when run with sudo
- **Cause**: File permissions on script or audit plist location
- **Solution**:

  ```bash
  # Fix script permissions
  sudo chmod 755 /Library/Security/mSCP/800-53r5_moderate_compliance.sh
  sudo chown root:wheel /Library/Security/mSCP/800-53r5_moderate_compliance.sh
  
  # Ensure audit directory exists and is writable
  sudo mkdir -p /Library/Preferences
  sudo chmod 755 /Library/Preferences
  ```

**Script Runs But No Audit Output:**

- **Symptom**: Script completes but audit plist is empty or missing
- **Cause**: Wrong path, permissions, or script arguments
- **Diagnosis**:

  ```bash
  # Check script location
  ls -la /Library/Security/mSCP/
  
  # Check for audit plist (location varies by baseline name)
  ls -la /Library/Preferences/org.*.audit.plist
  
  # Review script logs
  tail -50 /Library/Logs/*baseline*.log
  ```

- **Solution**: Verify script arguments and output paths; check logs for errors

### MDM and Profile Deployment Issues

**Configuration Profiles Not Taking Effect:**

**Symptom**: Profiles deploy but settings don't appear on device

**Diagnosis Steps:**

```bash
# Verify profile is installed
profiles -P

# Check profile payloads
profiles -P -o stdout-xml

# Verify managed preferences location
ls -la /Library/Managed\ Preferences/

# Check for conflicts with user settings
defaults read /Library/Preferences/.GlobalPreferences.plist 2>/dev/null | grep -i firewall
```

**Common Causes and Solutions:**

1. **Profile Conflicts:**
   - Multiple profiles trying to set the same preference
   - **Solution**: Review all deployed profiles, identify conflicts, consolidate or prioritize
   - **Tool**: `profiles -P -o stdout-xml | grep -A 10 "PayloadDisplayName"` to list all profiles

2. **PPPC/TCC Profiles Require Supervision:**
   - Full Disk Access and other PPPC settings only work on supervised devices
   - **Solution**: Verify device is supervised: `profiles status -type enrollment`
   - **Workaround**: For unsupervised devices, use alternative enforcement methods

3. **Profile Not Scoped Correctly:**
   - Profile deployed to wrong device group or user
   - **Solution**: Verify MDM scope and device membership in groups
   - **Tool**: Check MDM console for profile assignment

4. **Profile Signature Issues:**
   - Unsigned profiles may not apply on supervised devices
   - **Solution**: Sign profiles with Subject Key ID as shown in Section 14.2.3

**DDM Components Not Applying:**

**Symptom**: DDM activations, assets, or configurations show as "pending" or "failed"

**Diagnosis:**

```bash
# Check DDM status (macOS 14+)
profiles status -type declarative

# View detailed DDM state
profiles show -type declarative

# Check unified logging for DDM errors
log show --last 1h --predicate 'subsystem == "com.apple.ManagedClient"' | grep -i ddm
```

**Common Causes:**

1. **MDM Doesn't Support DDM:**
   - Not all MDM vendors fully support DDM declarations
   - **Solution**: Verify MDM vendor's DDM support matrix; may need to use traditional profiles

2. **macOS Version Too Old:**
   - DDM requires macOS 14.0 or later
   - **Solution**: Verify target OS: `sw_vers -productVersion`

3. **Malformed Declarations:**
   - JSON syntax errors or missing required fields
   - **Solution**: Validate JSON before deployment; check mSCP generation output

4. **Declaration Conflicts:**
   - Multiple declarations trying to manage the same resource
   - **Solution**: Review all active declarations, consolidate or remove conflicts

**MDM-Specific Integration Issues:**

**Jamf Pro:**

- **Issue**: Profiles appear as "pending" indefinitely
- **Solution**: Verify scope and exclusions; check for profile conflicts in Jamf console
- **Tool**: Jamf Pro logs at `/Library/Application Support/JAMF/Logs/jamf.log`

**Microsoft Intune:**

- **Issue**: Configuration profiles fail to apply with generic errors
- **Solution**: Verify profile format compatibility; Intune may require specific payload structures
- **Workaround**: Use Intune's native configuration profile templates where possible

**Kandji/Mosyle/Addigy:**

- **Issue**: Custom profiles don't merge with vendor-managed profiles
- **Solution**: Coordinate with vendor support to understand profile precedence rules
- **Best Practice**: Use vendor's native configuration options when available

### Compliance Verification Issues

**False Positives in Compliance Reports:**

- **Symptom**: Script reports non-compliance but manual check shows compliance
- **Cause**: Check logic doesn't account for managed preferences or configuration profile application
- **Solution**: Enhance verification script to check `/Library/Managed Preferences/` for profile-applied settings
- **Example**:

  ```bash
  # Check if firewall is managed by profile
  plutil -p /Library/Managed\ Preferences/com.apple.alf.plist 2>/dev/null || echo "Not managed"
  ```

**Missing Controls in Reports:**

- **Symptom**: Expected controls don't appear in compliance output
- **Cause**: Baseline tailoring excluded controls, or baseline doesn't include them
- **Solution**: Review baseline YAML to verify controls are included; check tailoring decisions

### Performance and Operational Issues

**Compliance Script Runs Too Long:**

- **Symptom**: Script takes >30 minutes to complete on fleet
- **Cause**: Too many checks, or checks that are computationally expensive
- **Solutions**:
  - Use `--quiet=2` flag to reduce output verbosity
  - Split baseline into multiple smaller baselines (e.g., critical vs. non-critical)
  - Run checks less frequently for non-critical controls
  - Consider async processing for large fleets

**High CPU Usage During Compliance Checks:**

- **Symptom**: Devices become unresponsive during compliance script execution
- **Cause**: I/O-intensive checks (file system scans, process enumeration)
- **Solutions**:
  - Schedule checks during off-hours (see Section 14.5)
  - Use `nice` to reduce priority: `nice -n 10 zsh compliance.sh`
  - Limit concurrent script executions across fleet

**Audit Plist Size Growing Unbounded:**

- **Symptom**: Audit plist file grows very large over time
- **Cause**: Historical results accumulating without cleanup
- **Solution**: Implement log rotation or truncation:

  ```bash
  # Keep only last 30 days of results
  find /Library/Preferences -name "*.audit.plist" -mtime +30 -delete
  ```

### Getting Help and Escalation

**When to Escalate:**

- Profile deployment failures affecting >10% of fleet
- False positives causing significant operational impact
- Compliance gaps that cannot be resolved through tailoring or exemptions
- MDM integration issues that block deployment

**Resources:**

- mSCP GitHub Issues: https://github.com/usnistgov/macos_security/issues
- mSCP Documentation: https://pages.nist.gov/macos_security/
- MDM Vendor Support: Consult your MDM vendor's support channels for profile/DDM issues

## macOS Scripting Tips

- **Bash 3.2 vs 5:** If you author your own verifiers, stick to Bash 3.2‑compatible syntax (ships with macOS) unless you deploy a Bash 5 runtime.
- **Apple silicon paths:** If you reference Homebrew tools in checks, use `/opt/homebrew` on Apple silicon.
- **Managed preferences:** Many profile‑applied settings surface in `/Library/Managed Preferences/` as plists you can read with `plutil -p` (read‑only for verification).

## Chapter 14 Exercise

**Build a compliance pipeline:**

1. Generate a compliance script for your chosen baseline and run `--check` and `--cfc`.
2. Generate configuration profiles for the same baseline and scope them via your MDM.
3. Create a LaunchDaemon to run nightly and ship the audit plist/log summary to your SIEM.
4. Add your mini‑audit JSON to the SIEM and build a simple dashboard showing pass/fail by control ID.

## References and Further Reading

- mSCP introduction and docs: https://pages.nist.gov/macos_security/welcome/introduction/
- Getting Started (prerequisites and branches): https://pages.nist.gov/macos_security/welcome/getting-started/
- Generate compliance scripts: https://pages.nist.gov/macos_security/compliance-scripts/how-to-generate-compliance-scripts/
- Compliance script layout and flags: https://pages.nist.gov/macos_security/compliance-scripts/compliance-script-layout/
- Generate configuration profiles: https://pages.nist.gov/macos_security/configuration-profiles/how-to-generate-configuration-profiles/
- Generate DDM components: https://pages.nist.gov/macos_security/ddm-components/how-to-generate-ddm-components/
- Script arguments list: https://pages.nist.gov/macos_security/repository/script-arguments-list/
