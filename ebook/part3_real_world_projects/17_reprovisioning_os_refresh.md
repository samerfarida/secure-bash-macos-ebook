# Chapter 17: Reprovisioning & OS Refresh (startosinstall / erase-install)

## Learning Objectives

By the end of this chapter, you will be able to:

- Choose between **clean refresh** and **in‑place upgrades** for different operational scenarios.
- Use **startosinstall** safely for reinstall, upgrade, and full wipe workflows.
- Orchestrate **erase-install** (community automation) for consistent operator UX.
- Handle **Apple silicon** caveats (user authentication, ownership, Secure Enclave) vs. Intel.
- Validate **FileVault**, **Bootstrap Token**, and **power/network** prerequisites before a refresh.
- Decide when to prefer **MDM/DDM** workflows (EraseDevice, ScheduleOSUpdate) over local scripts.
- Present **preconditions and consent prompts** to users (e.g., with swiftDialog) before triggering actions.
- Produce logs, proof-of-execution artifacts, and rollback/abort paths for help desk safety.

## Introduction

Reprovisioning and major OS refresh tasks are high‑impact operations that touch identity, disk layout, and the secure boot chain. On macOS, you can accomplish these operations locally with **startosinstall** (included inside the macOS installer) or with **MDM/DDM** actions at fleet scale. Many teams also adopt the community **erase-install** tool to standardize preflight checks and reduce operator errors.

This chapter provides a practical, script‑first treatment of **in‑place upgrades** and **clean refresh** (erase and reinstall), emphasizing *safe automation* for Apple silicon as well as Intel Macs. You'll build preflight checks, user dialogs, and idempotent runbooks that your help desk and your auditors can trust.

> **Danger zone:** The examples below can erase data. Only run on test devices first. Always back up and confirm scope, power, and user consent.

### Enterprise Refresh Scenarios

Understanding when and why to perform OS refreshes in enterprise environments helps choose the right approach and justify the operational impact.

**Device Lifecycle Management:**

- **New Device Provisioning**: Prepare new Macs for deployment with standard OS version and configuration
- **OS Upgrade Cycles**: Move devices to new macOS major versions as part of planned refresh cycles
- **Standardization**: Ensure all devices run the same OS version for consistent security posture and support

**Security and Compliance:**

- **Compliance Events**: Refresh devices that cannot meet new security baseline requirements
- **Incident Response**: Clean refresh after security incidents to ensure no persistent threats
- **Policy Enforcement**: Reimage devices that have drifted from compliance requirements

**Operational Scenarios:**

- **Device Offboarding**: Secure wipe and refresh before device reassignment or disposal
- **Problem Resolution**: Refresh devices with persistent software issues that resist troubleshooting
- **Configuration Drift**: Reset devices with significant configuration changes from standard baselines

**Business Drivers:**

- Reduce support burden by maintaining consistent device state
- Improve security posture through standardized configurations
- Accelerate onboarding with automated device provisioning
- Meet compliance requirements for device lifecycle management

## 17.1 Choosing a Strategy: In-Place vs Clean Refresh

**In‑place upgrade / reinstall** (keeps data & apps):

- Minimal user disruption; preserves `/Users`, settings, MDM enrollment.
- Use when moving from n to n+1, repairing a damaged system component, or re-baselining without wiping data.
- Primary tool: `startosinstall --reinstall` or `--agreetolicense --nointeraction` with an appropriate installer.

**Clean refresh (erase & install)**:

- Wipes data volumes; returns the device to a known-good state.
- Use for device repurpose, offboarding, persistent corruption, lab turnover, or compliance events.
- Tools: `startosinstall --eraseinstall --newvolumename "Macintosh HD"` or MDM’s **EraseDevice** (where supported).

**When to prefer MDM/DDM**:

- You need **hands‑off**, user‑absent workflows, especially for Apple silicon.
- You want **audit trails**, **rate limiting**, and **policy gating** at scale.
- You rely on **Bootstrap Token** and platform entitlements only MDM can exercise.

### Decision Tree: Choosing the Right Refresh Strategy

Use this decision tree to select the appropriate refresh approach for your scenario:

**Decision Flow:**

1. **Is device being offboarded or repurposed?**
   - YES → Clean Refresh (erase & install)
     - Use MDM EraseDevice if available, else `startosinstall --eraseinstall`
   - NO → Continue to next question

2. **Is device part of a compliance event or security incident?**
   - YES → Clean Refresh (erase & install)
     - Use MDM EraseDevice for audit trail, else `startosinstall --eraseinstall`
   - NO → Continue to next question

3. **Is device experiencing persistent software issues?**
   - YES → Try in-place reinstall first
     - If issues persist after reinstall → Clean Refresh
   - NO → Continue to next question

4. **Is this a routine OS upgrade (n to n+1)?**
   - YES → In-place upgrade (preserve data)
     - Use MDM ScheduleOSUpdate if available, else `startosinstall`
   - NO → Continue to next question

5. **Is device Apple silicon (M1/M2/M3)?**
   - YES → Prefer MDM workflows (EraseDevice, ScheduleOSUpdate)
     - Local scripts may require user authentication
   - NO → Continue (Intel devices)

6. **Fleet size and automation requirements?**
   - Large fleet (100+ devices) → MDM/DDM preferred
   - Medium fleet (10-100 devices) → MDM or local scripts with automation
   - Small fleet (<10 devices) → Local scripts acceptable

**Default:** In-place upgrade/reinstall (preserve data)

- Use `startosinstall` with appropriate flags

**Key Decision Factors:**

1. **Data Preservation**: Can user data be preserved or must it be wiped?
2. **User Presence**: Is user available to authorize or must it be unattended?
3. **Fleet Scale**: How many devices need refreshing?
4. **Device Architecture**: Apple silicon requires different approaches than Intel
5. **Compliance/Audit**: Are audit trails and centralized control required?
6. **Risk Tolerance**: What's the impact of failure or rollback need?

## 17.2 Preflight Checks You Should Never Skip

Create a **single preflight function** you can call from any workflow. This avoids subtle differences across scripts and teams.

```bash
#!/bin/bash
# preflight_refresh.sh
set -euo pipefail

log(){ printf "%s %s\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*" ; }

assert_root(){
  if [[ $EUID -ne 0 ]]; then
    log "[FATAL] Must run as root"; exit 1
  fi
}

assert_power(){
  # Require AC power or battery >= 50%
  if pmset -g batt | grep -q "AC Power"; then
    log "[OK] On AC power"
  else
    # Battery percentage output varies; handle both formats
    battpct="$(pmset -g batt | awk -F';' '/InternalBattery|Battery/{gsub(/[^0-9]/,"",$2); print $2}')"
    battpct="${battpct:-0}"
    if (( battpct < 50 )); then
      log "[FATAL] Battery ${battpct}%, require >= 50% or AC power"; exit 1
    fi
    log "[OK] Battery ${battpct}%"
  fi
}

assert_space(){
  avail_bytes=$(df -k / | awk 'NR==2{print $4*1024}')
  req_bytes=$((25*1024*1024*1024))
  if (( avail_bytes < req_bytes )); then
    log "[FATAL] Not enough free space: need >=25 GB"; exit 1
  fi
  log "[OK] Free space: $(df -h / | awk 'NR==2{print $4}')"
}

arch_type(){
  uname -m  # arm64 or x86_64
}

filevault_status(){
  fdesetup status | tr -d '.'
}

bootstrap_token_status(){
  profiles status -type bootstraptoken 2>/dev/null || true
}

fv_ok(){
  if fdesetup status | grep -qi "FileVault is On"; then
    log "[OK] FileVault enabled"
  else
    log "[WARN] FileVault disabled"
  fi
}

bt_ok(){
  if profiles status -type bootstraptoken 2>/dev/null | grep -Eq "escrowed( to server)?: YES"; then
    log "[OK] Bootstrap Token escrowed"
  else
    log "[WARN] Bootstrap Token not escrowed"
  fi
}

owner_ok(){
  if diskutil apfs listUsers / 2>/dev/null | grep -q "Volume Owner: Yes"; then
    log "[OK] Volume owner present"
  else
    log "[WARN] No volume owner detected; unattended startosinstall may prompt on Apple silicon"
  fi
}

os_installer_ok(){
  # Expect an installer under /Applications/Install macOS*.app
  installer="$(ls -d /Applications/Install\ macOS*.app 2>/dev/null | head -n1 || true)"
  if [[ -z "$installer" ]]; then
    log "[FATAL] No macOS installer in /Applications"; exit 1
  fi
  if [[ ! -x "$installer/Contents/Resources/startosinstall" ]]; then
    log "[FATAL] startosinstall missing in $installer"; exit 1
  fi
  echo "$installer"
}

main(){
  assert_root
  assert_power
  assert_space
  log "[INFO] Architecture: $(arch_type)"
  log "[INFO] $(filevault_status)"
  log "[INFO] $(bootstrap_token_status)"
  fv_ok
  bt_ok
  owner_ok
  inst="$(os_installer_ok)"
  log "[OK] Using installer: $inst"
  log "[READY] Preconditions met"
}
main "$@"
```

**Why these checks?** Power loss or low disk space can brick upgrades. Apple silicon may require *user authorization* during certain flows unless MDM pathways are used. **Bootstrap Token** state tells you how “hands‑off” the flow can be on managed Macs.

## 17.3 Obtaining the Installer Safely

Prefer **Apple‑signed installers** via `softwareupdate`. This ensures correct catalogs and signing.

```bash
# List available full installers
softwareupdate --list-full-installers

# Fetch latest (or a specific) full installer
softwareupdate --fetch-full-installer
# or
softwareupdate --fetch-full-installer --full-installer-version 15.0
```

When targeting a specific point release, use:  
`softwareupdate --fetch-full-installer --full-installer-version <15.x.y>` after confirming availability with `--list-full-installers`.

Validate code signature before trusting the bundle:

```bash
spctl --assess --type execute "/Applications/Install macOS*.app" && echo "Signed OK"
codesign -dv --verbose=4 "/Applications/Install macOS*.app" 2>&1 | grep -E "Authority|TeamIdentifier"
```

For bandwidth control across sites, consider **Content Caching** and staged distribution.

## 17.4 startosinstall: Core Patterns

`startosinstall` lives at:

```bash
/Applications/Install macOS <Name>.app/Contents/Resources/startosinstall
```

Run `--usage` on the target device to confirm flags for that macOS version.

### In‑Place Reinstall (repair same version)

```bash
installer="/Applications/Install macOS Sequoia.app"
sudo "$installer/Contents/Resources/startosinstall"   --reinstall   --agreetolicense   --forcequitapps   --nointeraction
```

### Upgrade to New Major Version (preserve data)

```bash
installer="/Applications/Install macOS Sequoia.app"
sudo "$installer/Contents/Resources/startosinstall"   --agreetolicense   --forcequitapps   --nointeraction
```

### Clean Refresh (wipe & install)

```bash
installer="/Applications/Install macOS Sequoia.app"
sudo "$installer/Contents/Resources/startosinstall"   --eraseinstall   --newvolumename "Macintosh HD"   --agreetolicense   --forcequitapps   --nointeraction
```

**Common flags you’ll see:**

- `--agreetolicense` – pre-accept license.
- `--forcequitapps` – avoid “app blocking restart” prompts.
- `--nointeraction` – suppress interactive prompts.
- `--eraseinstall` – delete data volumes before install.
- `--newvolumename <name>` – optional with `--eraseinstall`; sets the target volume’s name.
- `--preservecontainer` – keeps other APFS volumes intact when using `--eraseinstall`.
- `--rebootdelay <seconds>` – delays reboot; useful for logging or last-minute cleanup.
- `--installpackage <pkg>` – stage a **signed** package to run at first boot.
- `--rebootdelay <seconds>` – useful after user prompts.

> **Tip:** Some flows on Apple silicon still require an *admin user’s authorization* to proceed. If you need a truly unattended experience at scale, use **MDM workflows** and ensure **Bootstrap Token** is escrowed.

## 17.5 Apple Silicon vs Intel: Critical Differences

| Topic | Intel (T2 and non‑T2) | Apple silicon (M1/M2/M3) |
|---|---|---|
| Authenticated Restart | Often possible via `fdesetup authrestart` when FV is on (Intel/T2 only); behavior differs on Apple silicon—don’t rely on it for unattended OS upgrades, prefer MDM. | Behavior differs; authorization may be required by an **Owner** user. Prefer **MDM** for unattended flows |
| Erase/Reinstall | `startosinstall --eraseinstall` works; may be unattended on some setups | May trigger ownership/auth prompts; `EraseDevice` via MDM (EACS) is more reliable for zero-touch |
| Secure Boot Chain | T2 security; recoveryOS present | Secure Enclave ownership and *Owner* context matter (who activated the Mac) |
| Network Recovery | Internet Recovery via Command‑R/Option‑Command‑R | On‑chip DFU/Revive paths exist; plan for help desk runbooks |

### Checking Ownership and Volume State

```bash
# FileVault
fdesetup status

# APFS volume owners (look for "Volume owner: Yes")
diskutil apfs list / | grep -A5 "APFS Volume Disk" | grep -i "Volume.*Owner"

# Bootstrap Token
profiles status -type bootstraptoken
```

If **Bootstrap Token** is not escrowed on managed devices, unattended upgrades may stall on Apple silicon. Work with your MDM to escrow tokens and consider using **ScheduleOSUpdate**/**EraseDevice** instead of local scripts.

## 17.6 Using erase-install for Operator Safety

The community **erase-install** tool wraps `startosinstall` to provide consistent CLI options, preflight checks, and logging. Typical flows:

- **Reinstall same OS:** keep data, repair system.
- **Upgrade OS:** fetch the desired full installer and apply.
- **Erase & Install:** full wipe with confirmations.

Example patterns (confirm version on the device you’re targeting):

```bash
# Dry-run / list versions
/usr/local/bin/erase-install --list

# Fetch and reinstall current OS
/usr/local/bin/erase-install --reinstall --confirm --agreetolicense

# Upgrade to a specific version (example; adjust for your fleet)
/usr/local/bin/erase-install --os 15 --reinstall --confirm --agreetolicense

# Full wipe and reinstall (danger)
/usr/local/bin/erase-install --erase --confirm --agreetolicense --rebootdelay 10
```

**Operational guardrails to keep:** require `--confirm`, maintain verbose logs, and gate execution behind your preflight function.

## 17.7 User Experience: Preconditions and Consent (swiftDialog)

Use a lightweight dialog to show preconditions and gather explicit consent in user‑present flows.

```bash
#!/bin/bash
# preflight_dialog.sh (requires swiftDialog installed)
DIALOG="/usr/local/bin/dialog"
TITLE="macOS Refresh"
MESSAGE="This process will restart your Mac and may take 30–90 minutes. Please plug in power. Your files may be erased depending on the selected option. Continue?"

"$DIALOG"   --title "$TITLE"   --message "$MESSAGE"   --icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns"   --button1text "Continue"   --button2text "Cancel"   --ontop

case $? in
  0) echo "User consented";;
  *) echo "User cancelled"; exit 1;;
esac
```

Combine with your **preflight_refresh.sh** to fail fast when power/network/FileVault conditions are not met.

## 17.8 Logging, Proof, and Rollback

Your help desk will thank you for **structured logs** and clear “what happened” artifacts.

```bash
LOGDIR="/var/log/os-refresh"
mkdir -p "$LOGDIR"
exec > >(tee -a "$LOGDIR/run_$(date +%F_%H%M%S).log") 2>&1

# Capture installer usage and version
installer="$(ls -d /Applications/Install\ macOS*.app 2>/dev/null | head -n1)"
"$installer/Contents/Resources/startosinstall" --usage
sw_vers
```

Keep a manifest of **inputs** (installer path, flags, user decision), **outputs** (return codes), and **timeline** for audit. If a flow aborts, display a dialog with next steps and open a help ticket URL for the user.

## 17.9 MDM/DDM Workflows to Prefer at Scale

- **EraseDevice** – authoritative wipe for Apple silicon and T2; user‑absent, auditable. On macOS 12+, EraseDevice leverages **Erase All Content and Settings (EACS)**, which performs faster and preserves OS integrity.
- **ScheduleOSUpdate / Declarative Device Management** – platform‑level upgrades with better success rates than local scripts.
- **Nudge** (user experience companion) – pre‑upgrade nudging and deferral tracking.
- **Installomator/Patchomator** – pre/post OS refresh app re‑seeding.

**Rule of thumb:** If it must be unattended on Apple silicon, and you manage the device with MDM, prefer **MDM/DDM** over local `startosinstall`.

## 17.10 Help Desk Runbooks

Help desk teams need standardized procedures for common OS refresh scenarios. These runbooks provide step-by-step guidance for troubleshooting and executing refresh operations.

### Runbook 1: Device Stuck During Upgrade

**Symptoms**: Device appears frozen during upgrade, progress bar not moving, no response to input

**Diagnosis Steps:**

1. Check device power status (AC power connected, battery level)
2. Verify network connectivity (upgrade may be downloading)
3. Review installation logs: `tail -100 /var/log/install.log`
4. Check available disk space: `df -h /`
5. Verify installer integrity: `codesign -dv --verbose=4 "/Applications/Install macOS*.app"`

**Resolution Steps:**

1. **If stuck < 30 minutes**: Wait and monitor logs (upgrades can take 60-90 minutes)
2. **If stuck > 60 minutes**: Check logs for specific error messages
3. **If installer corrupted**: Download fresh installer via `softwareupdate --fetch-full-installer`
4. **If disk space issue**: Free space or abort and reschedule
5. **If power issue**: Connect AC power, wait for sufficient charge, retry

**Escalation**: If device is completely unresponsive, may need recovery mode intervention

### Runbook 2: Failed Upgrade Recovery

**Symptoms**: Upgrade failed, device boots but shows error messages, OS version unchanged

**Diagnosis Steps:**

1. Review installation log: `tail -200 /var/log/install.log | grep -i error`
2. Check system integrity: `diskutil verifyVolume /`
3. Verify installer was valid: `spctl --assess "/Applications/Install macOS*.app"`
4. Check for error codes in logs

**Resolution Steps:**

1. **Clear failed upgrade state**: `sudo softwareupdate --clear-catalog`
2. **Download fresh installer**: `softwareupdate --fetch-full-installer --full-installer-version X.Y`
3. **Retry upgrade**: Use orchestrator script with verbose logging
4. **If persistent failures**: Consider clean refresh instead of upgrade
5. **Document error codes**: Record specific errors for pattern analysis

**Prevention**: Always verify preflight checks passed before upgrade

### Runbook 3: User Data Backup Before Clean Refresh

**Symptoms**: Need to perform clean refresh but ensure user data is preserved

**Pre-Refresh Backup Steps:**

1. Verify user is logged in and can authorize backup
2. Check available backup storage (external drive, network location, cloud)
3. Use Time Machine if configured: Verify latest backup completed
4. Manual backup for critical data:
   - User documents: `rsync -av ~/Documents /Volumes/Backup/`
   - Desktop files: `rsync -av ~/Desktop /Volumes/Backup/`
   - Keychain: Export passwords if needed
   - Browser bookmarks: Export from browsers
5. Verify backup integrity: Spot check files can be opened
6. Document backup location for user

**Post-Refresh Restoration:**

1. Restore from Time Machine (if used) or manual backup location
2. Reinstall applications (use MDM or Installomator)
3. Verify user data restored correctly
4. Test critical applications and workflows

### Runbook 4: Apple Silicon Authentication Prompt

**Symptoms**: Upgrade/refresh requires user authentication on Apple silicon device

**Diagnosis:**

- Apple silicon devices may prompt for user password during refresh
- Occurs when Bootstrap Token not escrowed or device not fully supervised
- Check Bootstrap Token status: `profiles status -type bootstraptoken`

**Resolution Options:**

**Option A: User Present (Preferred)**

1. Have user authenticate when prompted
2. Continue with upgrade process
3. After completion, verify Bootstrap Token escrowed via MDM

**Option B: Unattended (Requires MDM)**

1. Verify device is supervised and Bootstrap Token escrowed
2. Use MDM EraseDevice or ScheduleOSUpdate instead of local script
3. If local script required, ensure proper MDM enrollment and token escrow

**Prevention:**

- Ensure all devices are supervised via MDM
- Verify Bootstrap Token escrowed for all managed devices
- Prefer MDM workflows for unattended operations

### Runbook 5: Post-Refresh Device Enrollment

**Symptoms**: After clean refresh, device not enrolled in MDM or missing configuration

**Post-Refresh Enrollment Steps:**

1. **Automatic Enrollment**: If DEP/ADM configured, device should auto-enroll
   - Check device serial in DEP/ADM portal
   - Verify network connectivity during setup
   - Allow time for enrollment (may take 5-10 minutes)

2. **Manual Enrollment**: If auto-enrollment failed
   - Open System Settings → Privacy & Security → Device Management
   - Click "Enroll" or "Enable Management"
   - Enter enrollment URL or scan QR code
   - Complete authentication

3. **Profile Installation**: After enrollment
   - Verify profiles installed: `profiles -P`
   - Check for configuration profiles in MDM console
   - Verify device appears in MDM inventory

4. **Application Deployment**: Reinstall required applications
   - Deploy via MDM policies
   - Use Installomator for standard applications
   - Verify critical applications installed and functional

### Runbook 6: Emergency Rollback from Failed Refresh

**Symptoms**: Upgrade/refresh failed, device unbootable or critical issues

**Recovery Steps:**

1. **Boot to Recovery Mode**:
   - Intel: Hold Command-R during boot
   - Apple Silicon: Hold power button, release when Options appears

2. **Assess Situation**:
   - Can Time Machine restore previous system? (Use Restore from Time Machine)
   - Is system volume corrupted? (Use Disk Utility to verify/repair)
   - Need complete reinstall? (Use Reinstall macOS)

3. **Recovery Options**:
   - **Time Machine Restore**: Fastest if recent backup available
   - **Reinstall macOS**: Keeps data, reinstalls OS
   - **Internet Recovery**: Download and install fresh OS

4. **Post-Recovery**:
   - Verify MDM enrollment
   - Check application functionality
   - Review logs to understand failure cause
   - Document for prevention

### Runbook 7: Staged Fleet Upgrade Coordination

**Scenario**: Upgrading multiple devices in phases (ring-based deployment)

**Planning Phase:**

1. Define rings: Pilot (5%), Canary (15%), Broad (80%)
2. Identify pilot devices: IT team, power users, representative sample
3. Schedule upgrade windows: Off-hours, consider time zones
4. Communicate to users: Email, notifications, status page

**Execution Phase:**

1. **Pilot Ring**:
   - Deploy to small group
   - Monitor for issues daily
   - Collect feedback and metrics
   - Adjust process based on learnings

2. **Canary Ring**:
   - Expand to larger, diverse group
   - Continue monitoring
   - Verify no new issues introduced
   - Prepare for broad deployment

3. **Broad Ring**:
   - Deploy to remaining devices
   - Stagger by department/region
   - Monitor success rates and support tickets
   - Pause if issues exceed thresholds

**Monitoring:**

- Track upgrade success rate per ring
- Monitor help desk ticket volume
- Track time-to-completion metrics
- Alert on failure rate spikes

## 17.11 Putting It All Together: Orchestrated Scripts

A simple orchestrator tying together preflight, consent, and `startosinstall`:

```bash
#!/bin/bash
set -euo pipefail

preflight="/usr/local/sbin/preflight_refresh.sh"
dialog="/usr/local/sbin/preflight_dialog.sh"

"$preflight"
"$dialog"

installer="$(ls -d /Applications/Install\ macOS*.app 2>/dev/null | head -n1)"
exec &> >(tee -a /var/log/os-refresh/orchestrator.log)

# Choose one of the flows below

# 1) In-place reinstall (repair):
"$installer/Contents/Resources/startosinstall"   --reinstall   --agreetolicense --forcequitapps --nointeraction

# 2) Upgrade (preserve data):
# "$installer/Contents/Resources/startosinstall" #   --agreetolicense --forcequitapps --nointeraction

# 3) Clean refresh (erase everything):
# "$installer/Contents/Resources/startosinstall" #   --eraseinstall --newvolumename "Macintosh HD" #   --agreetolicense --forcequitapps --nointeraction
```

Extend the orchestrator with **post‑install bootstrap** packages via `--installpackage` to re‑seed agents, certificates, or first‑boot scripts (ensure proper signing).

## Chapter 17 Exercise

**Build a safe refresh runbook**:

1. Write a **preflight** script that checks: root, AC/battery, FileVault, Bootstrap Token, installer presence, free disk space (recommend >= 25 GB).
2. Create a **swiftDialog** consent prompt with explicit language for both **in‑place** and **clean refresh** options.
3. Implement two subcommands in an **orchestrator** script:
   - `reinstall` – in‑place repair using `startosinstall --reinstall`.
   - `erase` – wipe and reinstall using `--eraseinstall --newvolumename` (danger).
4. Add structured **logging** and write an execution **manifest** (`/var/log/os-refresh/manifest.json`) with keys: `flow`, `user`, `arch`, `fv_state`, `bt_state`, `installer_version`, `return_code`, `start_time`, `end_time`.
5. (Bonus) **MDM mode**: when a config file flag is set, skip local flows and exit with a code signaling your management agent to trigger an MDM **EraseDevice** or **ScheduleOSUpdate** instead.

## macOS Scripting Tips

- `startosinstall --usage` is authoritative—flags vary slightly by release (added `--eraseinstall` in macOS 10.13.4); always verify on the target device.
- Budget **25–45 GB free space** for upgrades, especially when converting between APFS snapshots and preparing the installer.
- For Apple silicon, prefer **MDM/DDM** for no‑touch flows; user authorization may still appear with local scripts.
- Cache installers with **Content Caching** at sites; clean up old `Install macOS*.app` bundles after success.
- If **FileVault** is off but will be enforced later, plan first‑boot enablement (e.g., fdesetup and PPPC profile); if it’s on, test **authrestart** behavior on **Intel** separately from Apple silicon.
- If managing macOS 14+ devices, use **Declarative Device Management** software-update configurations for modern enforcement and reporting.
