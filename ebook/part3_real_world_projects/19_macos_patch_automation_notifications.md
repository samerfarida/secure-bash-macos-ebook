# Chapter 19: macOS Patch Automation & Notifications (DDM-first)

## 19.1 Prerequisites, Scope & Limitations

- Requires macOS 14 or later for full Declarative Device Management (DDM) support.  
- Hybrid MDM environments may have inconsistent behavior; full DDM benefits require MDM vendors to implement support completely.  
- Vendor implementations vary: Intune, Jamf, and Workspace ONE differ in how they handle update declarations and reporting.  
- Thorough testing in your environment is essential before broad rollout to catch edge cases and integration issues.

## Learning Objectives

By the end of this chapter, you will be able to:

- Design a **Declarative Device Management (DDM)-first** strategy for macOS software updates.  
- Combine **DDM enforcement** with **Nudge**-driven user experience to maximize compliance.  
- Use **softwareupdate** primarily for diagnostics, verification, and edge cases.  
- Implement ring-based rollouts, deadlines, and deferrals that respect UX and security posture.  
- Observe and troubleshoot the Apple **Unified Logging** and **Software Update** subsystems.  
- Integrate notifications and compliance signals with your MDM and SIEM compliance signals.

## Introduction

Apple’s Declarative Device Management (DDM) fundamentally changes how fleets receive and report software update state: devices **proactively evaluate** their status and **report** back without constant polling. For macOS, this means **reliable, scalable enforcement** of OS updates, security updates, and Rapid Security Responses (RSRs), while keeping the end-user experience front and center.

This chapter takes a **DDM-first** approach: use DDM to define the *what* (required version, deadline, enforcement), use **Nudge** to deliver the *why/when* to users (clear guidance, deferrals, deadlines), and reserve **softwareupdate** CLI for *diagnostics and exceptional cases*. The result is higher compliance, fewer help desk calls, and fewer surprises on patch night.

## 19.2 DDM: Concepts and Update Controls (macOS 14+)

### Why DDM for Updates

- **Asynchronous & scalable**: Devices evaluate declarations locally and report changes immediately.  
- **Proactive status**: The server receives compliant/non-compliant state as it happens.  
- **Fewer moving parts**: Less server-initiated polling and fewer race conditions on patch windows.

### Core Building Blocks

- **Declarations** (server-authored, device-evaluated): include Software Update configuration (minimum OS, enforcement date/time, channel, beta enrollment, RSR policy).  
- **Extensible reports**: the device publishes status (e.g., eligible, deferred, installing, completed) back to your MDM.  
- **Audience targeting**: apply different declarations to different rings (pilot, canary, broad).

### MDM Vendor Integration & Constraints

Different MDM vendors have varying levels of support and idiosyncrasies when handling DDM update declarations:

- **Intune**: Supports DDM update declarations but may have delays in status reporting; some settings can disappear after profile refreshes.  
- **Jamf**: Offers robust DDM integration with support for rings and enforcement dates, but hybrid mode can cause conflicts between legacy and DDM policies.  
- **Workspace ONE**: Implements DDM declarations with some known issues around deferral counts and reporting accuracy.  

Known issues include disappearing configuration settings after profile updates, conflicts in hybrid MDM modes where legacy and DDM policies overlap, and differences in how enforcement dates are interpreted. It is critical to consult vendor documentation and test thoroughly.

> Minimum platform levels for DDM Software Update management are typically macOS 14+ for Mac and iOS/iPadOS 17+ on mobile. Always verify your MDM’s implementation notes.

### Example: Software Update Declaration (illustrative)

```json
{
  "Type": "com.apple.configuration.softwareupdate",
  "Identifier": "su-decl-macos-14-6-1",
  "ServerToken": "v3-2025-09-01",
  "Payload": {
    "MinimumOSVersion": "14.6.1",
    "InstallAction": "InstallASAP",
    "EnforceAt": "2025-11-15T02:00:00Z",
    "AllowUserDeferralUntil": "2025-11-14T23:59:00Z",
    "AllowRapidSecurityResponses": true,
    "IncludeBetas": false
  }
}
```

**Notes**  

- `InstallAction` can be set per your MDM’s schema (e.g., *InstallASAP*, *InstallLater*, or a windowed policy).  
- `EnforceAt` expresses a deadline in UTC.  
- Some MDMs expose additional toggles for RSRs, major upgrades vs minor updates, and notification timing.  
- Prefer **rings**: e.g., `su-decl-macos-14-6-1-pilot`, `-canary`, `-broad` with staggered dates.

## 19.3 Pairing DDM with Nudge for UX

Even with DDM enforcement, users benefit from clarity and control. **Nudge** (Swift/SwiftUI) provides **configurable, persistent** prompts that educate, allow limited deferral, and escalate as deadlines approach. Use Nudge to reduce surprise reboots and improve perceived trust.

### Nudge High-Level Flow

1. **MDM installs Nudge** (pkg + LaunchAgent).  
2. **MDM deploys a Nudge configuration** (JSON/plist) targeting the same ring & deadline as DDM.  
3. Users see **informative prompts** (why the update matters, ETA, deferral count/time).  
4. As `requiredInstallationDate` nears, Nudge becomes more insistent (reduced snooze windows, optional full-screen, or forced interaction).  
5. DDM enforces at deadline if the device has not updated.

### Delta Upgrade Complexity & Nudge Behavior

macOS updates can be delta (smaller, incremental) or full installers. Nudge differentiates these upgrade types to optimize user experience:

- Delta updates typically require less time and bandwidth and may allow shorter deferral windows.  
- Full upgrades are larger and more disruptive, requiring longer lead times and stronger user messaging.  
- Nudge can adjust prompts and deferral logic based on the upgrade type detected.

### Automation & SOFA-Based Updates

SOFA (Software Update Feed Automation) provides structured feeds of new macOS releases and Rapid Security Responses. By integrating SOFA feeds with nudge-auto-updater scripts, you can automate regeneration of Nudge configurations and DDM declarations aligned with the latest macOS versions. This reduces manual overhead and ensures timely rollout of new updates.

## 19.4 Using softwareupdate for Diagnostics & Edge Cases

Your primary enforcement is DDM, but **softwareupdate** remains invaluable for **verification, triage, and one-off remediation** (lab Macs, break-glass situations, or devices that missed a declaration).

### Common Checks

```bash
# List available updates (human-readable)
softwareupdate --list

# Show software update history
softwareupdate --history

# Fetch a full installer (for reimage/erase-install workflows)
softwareupdate --fetch-full-installer --full-installer-version 15.0

# Install all available updates immediately (edge case)
sudo softwareupdate -ia --restart

# Include additional configuration data (where applicable)
sudo softwareupdate -ia --include-config-data
```

### Observability & Logs

```bash
# View recent Software Update activity (1 day)
log show --last 1d --predicate 'subsystem == "com.apple.SoftwareUpdate"'

# Stream live Software Update logs
log stream --predicate 'subsystem == "com.apple.SoftwareUpdate"' --style syslog

# Check installer progress / RSR traces
log show --last 1d --predicate 'subsystem CONTAINS "com.apple.os" AND category CONTAINS "update"'
```

### Observability & Logging (Advanced)

In addition to Software Update logs, DDM-related activities can be observed using predicates targeting the declarative management subsystem:

```bash
log show --last 1d --predicate 'subsystem == "com.apple.declarative.machine"'
```

Correlate these logs with MDM compliance reports to gain a full picture of update enforcement and device state changes. This approach helps identify discrepancies between server-side declarations and client-side enforcement.

> Use `system_profiler SPSoftwareDataType` and `sw_vers` to capture the pre/post version in your scripts, and record to your asset inventory for compliance.

## 19.5 Rapid Security Responses (RSR)

RSRs deliver **critical security content** without a full OS update. They can be **enforced via DDM** and are automatically rolled into the next minor release. Treat RSRs as **high-priority rings** with shorter deadlines and minimal deferrals, and communicate the **limited size/impact** clearly via Nudge.

## 19.6 Operational Notes

- RSRs typically **don’t require a full reboot** but may still request a restart depending on payload.  
- RSRs can be **rolled back** under certain scenarios; pin your MDM to Apple’s latest RSR guidance.  
- Ensure Content Caching nodes are ready to serve RSRs to large populations.  
- Detect rollbacks by monitoring device compliance reports and reconcile with MDM logs.  
- Content Caching readiness is critical to avoid bandwidth spikes during RSR rollout; verify cache health and client connectivity.

## 19.7 Rollout Design: Rings, Deferrals, and Deadlines

A resilient patch cadence uses **rings** and **clear timeframes**:

1. **Pilot (1–3%)**: power users, IT, and MacAdmins. Monitor new issues.  
2. **Canary (10–15%)**: broad device mix and critical workflows.  
3. **Broad (80%+)**: staged over days with geographically-aware windows.

**Deferral policy**  

- Align **Nudge deferrals** with **DDM AllowUserDeferralUntil**.  
- For RSRs: smaller deferral counts and hours.  
- For major upgrades: larger windows but keep **final enforcement** date firm.

**Deadlines & maintenance windows**  

- Prefer **off-hours enforcement** in device local time to minimize user disruption.  
- Offer **pre-download windows** (Content Caching + MDM) to stage updates in advance and reduce bandwidth spikes.  
- Communicate **reboot expectations** (Nudge banner text, email/Slack, status page).

## 19.8 Example: End-to-End Automation Blueprint

### 1) Targeting & Inventory

- Build Smart Groups (or dynamic device groups) for **ring membership**.  
- Feed in **hardware constraints** (SSD space, RAM) and **network** traits (remote vs office).  
- Exclude actively constrained devices (FileVault recovery pending, battery low).

### 2) Declarations

- Publish DDM Software Update declarations per ring.  
- Advance **EnforceAt** by ring: pilot (T0), canary (T0+2d), broad (T0+5–7d).  
- Keep **MinimumOSVersion** consistent across rings (or roll forward when stable).

### 3) UX

- Deploy Nudge with JSON/plist config aligned to the same deadline.  
- Increase insistence **as the deadline approaches** (reduced snooze; optional full-screen).  
- Provide **self-service guidance** (how to free disk space, backup reminders).

### 4) Observability

- Collect **DDM compliance** signals in your MDM/SIEM.  
- Tail **Software Update logs** during enforcement windows (see predicates above).  
- Track **time-to-compliance** per ring; watch for outliers and stuck states.

### 5) Remediation & Edge Cases

- If a device misses enforcement, trigger **softwareupdate** remotely or reprovision with a **full installer**.  
- Consider **erase-install** or **startosinstall** when devices cannot reconcile system state.  
- Close the loop by updating **inventory baselines** and **exceptions** (temporary deferral approvals).

## 19.9 Troubleshooting Playbook

**“No updates found” but device is out-of-date**  

- Confirm device eligibility (model, free disk, power) and **network reachability** to Apple CDNs.  
- Validate **declaration audience** and MDM logs.  
- Manually run `softwareupdate --list` and check `log show` for server handshake issues.

**Updates download slowly**  

- Validate **Content Caching** status (`AssetCacheManagerUtil status`).  
- Ensure caches have sufficient disk and are on the same subnet as clients.

**User reports repeated prompts**  

- Cross-check **Nudge** config vs DDM **deadline** and **minimum version**.  
- Verify that the upgrade actually completed (`sw_vers`, `system_profiler`); look for pending RSR.

**Stuck at “InstallPending”**  

- Inspect `log stream` for installer stages; ensure **power** and **storage** are adequate.  
- Retry with `softwareupdate -ia --restart` (edge case), or schedule full installer deployment.

**Nudge does not display**  

- Check that the LaunchAgent is installed and running correctly.  
- Verify that the user context is active and not locked or logged out.  
- Confirm that the Nudge configuration matches the device’s ring and deadline.  
- Inspect logs for errors or permission issues preventing Nudge from launching.

## 19.10 Security & Compliance Considerations

- Treat **patch SLAs** as policy: encode them into declarations and Nudge JSON.  
- Keep **audit logs**: device version before/after, enforcement timestamps, deferral counts, Nudge interactions.  
- Avoid long-term deferral exceptions; require **manager/security approval** and time-bound waivers.  
- Align with **RSR** timelines for high-risk CVEs; prioritize **faster rings**.

## Chapter 19 Exercise

**Goal:** Build a DDM+Nudge update plan for macOS 14 → 14.6.1 with a 7-day deadline and a 3-ring rollout.

**Tasks:**

1. Author three **DDM Software Update declarations** (pilot/canary/broad) with staggered `EnforceAt` values.  
2. Create matching **Nudge JSON** with the same `requiredMinimumOSVersion` and `requiredInstallationDate`.  
3. Simulate **observability** by tailing Software Update logs during a lab rollout.  
4. Trigger an **edge-case remediation** on a lab Mac using `softwareupdate -ia --restart`, then validate with `--history`.

**Bonus:** Add a **Content Caching** node and measure download time improvements during pilot.

## macOS Scripting Tips

- Prefer **DDM enforcement** over ad-hoc scripts; reserve `softwareupdate` for break-glass scenarios only.  
- Use **`log show` predicates** to filter noise and focus on relevant events during patch windows.  
- Pair **Nudge** with internal **patch notes** and **FAQ links** to reduce help desk tickets.  
- Maintain **ring labels** and metadata in your asset inventory to simplify scoping and reporting.  
- Test RSR handling and rollbacks before broad deployment to avoid surprises.  
- Automate deadline calculations and update declarations using **SOFA feeds** combined with CVE data for timely and accurate patch management.
