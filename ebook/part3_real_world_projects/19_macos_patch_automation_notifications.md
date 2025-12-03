# Chapter 19: macOS Patch Automation & Notifications (DDM-first)

## Learning Objectives

By the end of this chapter, you will be able to:

- Design a **Declarative Device Management (DDM)-first** strategy for macOS software updates.  
- Combine **DDM enforcement** with **Nudge**-driven user experience to maximize compliance.  
- Use **softwareupdate** primarily for diagnostics, verification, and edge cases.  
- Implement ring-based rollouts, deadlines, and deferrals that respect UX and security posture.  
- Observe and troubleshoot the Apple **Unified Logging** and **Software Update** subsystems.  
- Integrate notifications and compliance signals with your MDM and SIEM compliance signals.

## Introduction

Apple's Declarative Device Management (DDM) fundamentally changes how fleets receive and report software update state: devices **proactively evaluate** their status and **report** back without constant polling. For macOS, this means **reliable, scalable enforcement** of OS updates, security updates, and Rapid Security Responses (RSRs), while keeping the end-user experience front and center.

This chapter takes a **DDM-first** approach: use DDM to define the *what* (required version, deadline, enforcement), use **Nudge** to deliver the *why/when* to users (clear guidance, deferrals, deadlines), and reserve **softwareupdate** CLI for *diagnostics and exceptional cases*. The result is higher compliance, fewer help desk calls, and fewer surprises on patch night.

## 19.1 Prerequisites, Scope & Limitations

### System Requirements

**macOS Version Requirements:**

- **DDM Support**: macOS 14.0 or later required for Declarative Device Management
- **iOS/iPadOS**: iOS 17.0+ and iPadOS 17.0+ for mobile DDM support
- **Legacy Devices**: Devices on macOS 13.x or earlier require traditional MDM update commands
- Verify OS version: `sw_vers -productVersion`

**MDM Platform Requirements:**

- MDM must support Declarative Device Management (DDM) declarations
- MDM must support Software Update declarations (com.apple.configuration.softwareupdate)
- MDM API access for programmatic declaration management
- Device enrollment via DEP/ADM for automated management

### Verifying MDM Capabilities

**Check DDM Support in Your MDM:**

```bash
# Check device DDM status
profiles status -type declarative

# Verify Software Update declarations are supported
profiles show -type declarative | grep -i "softwareupdate\|software.update"

# Check MDM enrollment status
profiles status -type enrollment
```

**MDM Console Verification:**

- Check vendor documentation for DDM Software Update feature availability
- Verify your MDM license/tier includes DDM features
- Test creation of Software Update declarations in MDM console
- Confirm reporting/status visibility for update declarations

### Limitations and Known Issues

**Hybrid MDM Environments:**

- Mixed legacy and DDM policies may conflict
- Test carefully when transitioning from legacy to DDM workflows
- Some MDM vendors require explicit migration steps

**Vendor Implementation Variations:**

- Intune: Supports DDM but may have delays in status reporting; settings can disappear after profile refreshes
- Jamf: Robust DDM support but hybrid mode can cause conflicts between legacy and DDM policies
- Workspace ONE: DDM support with known issues around deferral counts and reporting accuracy
- Kandji/Mosyle/Addigy: Varying levels of DDM support; check vendor documentation

**Device Limitations:**

- Not all Mac models support all macOS versions (check compatibility)
- Older devices may not receive latest updates
- Network constraints may limit update download capabilities
- FileVault recovery scenarios may delay updates

**Testing Requirements:**

- Thorough testing in your environment is essential before broad rollout
- Test with multiple device models and macOS versions
- Validate edge cases (low disk space, network constraints, user absences)
- Document vendor-specific behaviors and workarounds

## Setting Up Your Patch Management Program

Before implementing DDM-based patch automation, establish the foundational elements of your patch management program. This includes defining policies, processes, and success criteria.

### Define Patch Management Policies

**Patch SLAs and Deadlines:**

- **Critical Security Updates**: Deploy within 24-48 hours (RSRs may require faster)
- **Standard Security Updates**: Deploy within 7-14 days
- **Feature Updates**: Deploy within 30-60 days (allow testing time)
- Document patch SLAs in security policy and communicate to stakeholders

**Risk Classification:**

- Classify updates by severity (Critical, High, Medium, Low)
- Align with CVE scores and Apple security advisories
- Adjust deployment speed based on risk classification
- Prioritize RSRs and zero-day patches

**Exception Process:**

- Define criteria for temporary deferrals (business continuity, testing needs)
- Require manager/security approval for exceptions
- Set maximum exception duration (typically 30-90 days)
- Document all exceptions with business justification

### Establish Ring-Based Deployment Strategy

**Ring Definitions:**

- **Pilot Ring (1-5%)**: IT team, security team, technical power users
- **Canary Ring (10-15%)**: Representative sample across departments and device types
- **Broad Ring (80%+)**: Remaining production devices

**Ring Advancement Criteria:**

- Pilot: >95% success rate, <5 help desk tickets per 100 devices
- Canary: >90% success rate, stable remediation process
- Broad: >85% success rate, no critical issues identified

**Communication Plan:**

- Notify users before deployment to their ring
- Provide patch notes and known issues
- Offer self-service deferral for legitimate business needs
- Communicate expected downtime/reboot requirements

### Infrastructure Requirements

**MDM Platform:**

- Verify DDM Software Update declaration support
- Test declaration creation and deployment workflows
- Validate status reporting and compliance dashboards
- Ensure API access for automation

**Content Caching:**

- Deploy Content Caching servers for large fleets
- Place caches on same network segments as clients
- Monitor cache health and disk space
- Test cache effectiveness with pilot group

**Monitoring and Alerting:**

- Set up compliance monitoring dashboards
- Configure alerts for low compliance rates
- Track time-to-compliance metrics
- Monitor help desk ticket volume

### Success Metrics

Define key performance indicators (KPIs) for your patch management program:

- **Compliance Rate**: Percentage of devices on target OS version
- **Time to Compliance**: Average time from patch release to fleet compliance
- **Patch Window Duration**: Time from deployment start to 95% compliance
- **Exception Rate**: Percentage of devices with approved deferrals
- **Help Desk Ticket Volume**: Number of patch-related support requests
- **Failed Installations**: Percentage of devices requiring remediation

### Stakeholder Alignment

**Key Stakeholders:**

- Security team: Define patch SLAs and risk tolerance
- IT operations: Execute deployment and remediation
- Help desk: Handle user issues and exceptions
- Business units: Approve exceptions and communicate to users
- Executive leadership: Review compliance metrics and program effectiveness

**Regular Reviews:**

- Monthly compliance review meetings
- Quarterly program effectiveness assessment
- Annual policy review and updates
- Continuous improvement based on metrics and feedback

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

Different MDM vendors have varying levels of support and idiosyncrasies when handling DDM update declarations. This section provides detailed guidance for common MDM platforms.

#### Microsoft Intune

**Capabilities:**

- Supports DDM Software Update declarations on macOS 14+
- Integration with Endpoint Manager (MEM) console
- Status reporting via device compliance and configuration reports

**Known Issues and Workarounds:**

1. **Delayed Status Reporting:**
   - Status updates may lag by 15-30 minutes
   - **Workaround**: Use device configuration reports rather than real-time status
   - **Monitor**: Check compliance reports for update status, not live device status

2. **Settings Disappearing After Profile Refresh:**
   - DDM declarations may reset after profile refresh cycles
   - **Workaround**: Ensure declarations are included in all policy refreshes
   - **Prevention**: Use Intune's policy refresh scheduling carefully

3. **Deferral Count Limitations:**
   - Limited granularity in deferral configuration
   - **Workaround**: Combine Intune declarations with Nudge for finer control
   - **Best Practice**: Set conservative deferral limits in Intune, use Nudge for user experience

**Best Practices for Intune:**

- Create separate update policies for each ring (pilot, canary, broad)
- Use device filters or groups to scope declarations
- Monitor via Intune reporting rather than expecting real-time updates
- Test declaration persistence after profile refresh cycles

#### Jamf Pro

**Capabilities:**

- Robust DDM integration with comprehensive Software Update management
- Support for rings and staggered enforcement dates
- Excellent status reporting and compliance dashboards
- Integration with Jamf's patch management workflows

**Known Issues and Workarounds:**

1. **Hybrid Mode Conflicts:**
   - Legacy Software Update policies can conflict with DDM declarations
   - **Workaround**: Disable legacy Software Update payloads when using DDM
   - **Migration**: Create explicit migration plan from legacy to DDM workflows

2. **Declaration Precedence:**
   - Multiple declarations may create conflicts
   - **Workaround**: Use scope exclusions and clear declaration hierarchy
   - **Best Practice**: One active declaration per device group/ring

3. **Enforcement Date Interpretation:**
   - Timezone handling may differ from expected behavior
   - **Workaround**: Specify dates in UTC and verify timezone conversion
   - **Test**: Validate enforcement timing in pilot before broad deployment

**Best Practices for Jamf:**

- Use Smart Computer Groups for ring membership
- Leverage Jamf's compliance reporting for metrics
- Integrate with Jamf Self Service for user notifications
- Use Jamf API for programmatic declaration management

#### VMware Workspace ONE (AirWatch)

**Capabilities:**

- DDM Software Update declaration support
- Integration with Workspace ONE UEM console
- Status reporting via device compliance

**Known Issues and Workarounds:**

1. **Deferral Count Accuracy:**
   - Deferral count reporting may not match actual device state
   - **Workaround**: Monitor device logs directly rather than relying solely on console
   - **Verification**: Use `profiles show -type declarative` on devices to verify actual state

2. **Reporting Delays:**
   - Status updates may be delayed in console
   - **Workaround**: Use device query APIs for more timely status
   - **Alternative**: Integrate with SIEM for real-time status monitoring

3. **Declaration Deployment:**
   - Declarations may require multiple profile pushes to take effect
   - **Workaround**: Force profile refresh after declaration deployment
   - **Verification**: Confirm declaration receipt with device commands

**Best Practices for Workspace ONE:**

- Test declaration deployment thoroughly in pilot
- Monitor device-side state, not just console reporting
- Use Workspace ONE's device query features for status verification
- Integrate with compliance policies for automated remediation

#### Kandji

**Capabilities:**

- DDM Software Update management via Kandji's patch management features
- Simplified interface for update enforcement
- Status reporting in Kandji dashboard

**Considerations:**

- Verify DDM support in your Kandji plan/tier
- Test declaration behavior with Kandji's implementation
- Monitor status reporting accuracy

#### Mosyle

**Capabilities:**

- DDM Software Update declarations supported
- Integration with Mosyle Manager console
- Status reporting and compliance tracking

**Considerations:**

- Verify DDM features are enabled in your Mosyle account
- Test declaration deployment and persistence
- Monitor status reporting for accuracy

#### General Best Practices for All MDM Vendors

**Testing:**

- Always test DDM declarations in a pilot environment first
- Verify declaration persistence after profile refresh
- Test status reporting accuracy and timeliness
- Validate enforcement behavior before broad deployment

**Documentation:**

- Document vendor-specific behaviors and limitations
- Maintain runbooks for vendor-specific troubleshooting
- Track known issues and workarounds
- Keep vendor documentation links for reference

**Monitoring:**

- Don't rely solely on MDM console reporting
- Use device-side commands to verify actual state
- Integrate with SIEM for comprehensive monitoring
- Set up alerts for declaration deployment failures

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
- Confirm that the Nudge configuration matches the device's ring and deadline.  
- Inspect logs for errors or permission issues preventing Nudge from launching.

**Vendor-Specific Troubleshooting:**

**Intune: Declaration Not Applying**

- Verify device is enrolled and compliant in Intune
- Check device configuration policy assignment
- Force policy sync: `sudo profiles -N`
- Verify declaration appears: `profiles show -type declarative`
- Check Intune logs: `/Library/Logs/Microsoft/Intune/` or via Intune portal

**Jamf: Legacy and DDM Policy Conflicts**

- Disable legacy Software Update payloads in conflicting policies
- Check for policy scope overlaps in Jamf console
- Review Jamf logs: `/Library/Logs/jamf.log`
- Use Jamf's DDM status commands to verify declaration state

**Workspace ONE: Status Reporting Inconsistencies**

- Query device directly: `profiles show -type declarative`
- Check Workspace ONE device logs
- Use Workspace ONE API to verify device state
- Compare console status with actual device state

**DDM Declaration Disappearing After Refresh**

- Common in Intune: Ensure declaration is part of persistent policy
- Verify declaration scope and exclusions
- Test declaration persistence across profile refresh cycles
- Document refresh behavior and adjust deployment strategy

## 19.10 Measuring Success

Effective patch management requires metrics to measure program effectiveness and identify areas for improvement.

### Key Performance Indicators (KPIs)

**Compliance Metrics:**

1. **Overall Compliance Rate**
   - Percentage of devices on target OS version
   - Target: >95% compliance within patch SLA timeframe
   - Calculate: `(compliant_devices / total_devices) * 100`

2. **Time to Compliance**
   - Average time from patch release to device compliance
   - Target: Meet patch SLA deadlines (e.g., 7 days for standard updates)
   - Track: Time from deployment start to device compliance

3. **Ring Advancement Rate**
   - Time to advance between rings (pilot → canary → broad)
   - Target: 2-3 days per ring for standard updates
   - Monitor: Time in each ring before advancement criteria met

4. **Exception Rate**
   - Percentage of devices with approved deferrals
   - Target: <5% of fleet with exceptions
   - Track: Number and duration of exceptions

**Operational Metrics:**

1. **Help Desk Ticket Volume**
   - Number of patch-related support requests
   - Target: <10 tickets per 1000 devices per patch cycle
   - Trend: Track over time to measure program maturity

2. **Failed Installation Rate**
   - Percentage of devices requiring remediation
   - Target: <5% failure rate
   - Action: Identify and address common failure patterns

3. **Patch Window Duration**
   - Time from deployment start to 95% compliance
   - Target: Complete within patch SLA window
   - Optimize: Reduce time through better automation

### Dashboards and Reporting

**Executive Dashboard:**

- High-level compliance percentages
- Patch SLA adherence
- Exception rates and trends
- Monthly/quarterly trend analysis

**Operational Dashboard:**

- Real-time compliance status by ring
- Devices requiring attention
- Failed installations and remediation status
- Help desk ticket trends

**Example Dashboard Queries (Splunk/Elastic):**

```splunk
# Overall compliance rate
index=mdm event_type=compliance_report | stats count by os_version | 
  eval target_version="14.6.1" | eval compliant=if(os_version==target_version, 1, 0) | 
  stats sum(compliant) as compliant_devices, count as total_devices | 
  eval compliance_rate=round((compliant_devices/total_devices)*100, 2)

# Time to compliance
index=mdm event_type=patch_deployment | stats 
  earliest(deployment_start) as start, 
  latest(device_compliant_time) as last_compliant by patch_version | 
  eval time_to_compliance=last_compliant-start
```

### Continuous Improvement

**Regular Reviews:**

- Weekly: Review compliance rates and identify blockers
- Monthly: Analyze trends and exception patterns
- Quarterly: Assess program effectiveness and policy adjustments
- Annually: Review and update patch management strategy

**Feedback Loops:**

- Collect user feedback on patch experience
- Review help desk tickets for common issues
- Analyze failure patterns to improve processes
- Adjust policies based on operational learnings

## 19.11 Handling Exceptions

Not all devices can or should receive updates on the standard schedule. Establishing clear exception processes ensures security while accommodating legitimate business needs.

### Exception Criteria

**Valid Exception Reasons:**

- Critical business operations cannot be interrupted
- Application compatibility issues requiring vendor updates
- Hardware constraints preventing update installation
- Temporary business constraints (e.g., month-end processes)
- Testing requirements for specialized applications

**Invalid Exception Reasons:**

- User inconvenience or preference
- Lack of time to install updates
- Concerns about update impact (address through testing)
- Historical issues with updates (investigate root cause instead)

### Exception Approval Process

**Request Submission:**

1. User/manager submits exception request with justification
2. Include device details (serial, hostname, current OS version)
3. Specify exception duration (maximum typically 30-90 days)
4. Provide business justification and risk assessment

**Approval Workflow:**

1. **Initial Review**: IT/Security team evaluates request
2. **Risk Assessment**: Determine security risk of deferral
3. **Manager Approval**: Require manager sign-off for extended exceptions
4. **Security Review**: Security team approval for high-risk exceptions
5. **Documentation**: Record exception in tracking system

**Exception Tracking:**

- Maintain exception database or spreadsheet
- Track: Device, reason, approver, duration, expiry date
- Set reminders for exception review/renewal
- Regular audit of exceptions for continued validity

### Technical Exception Implementation

**MDM-Based Exceptions:**

- Exclude device from update declaration scope
- Use device groups/filters to exclude specific devices
- Document exclusion reason in device notes/attributes

**Temporary Device Groups:**

```bash
# Example: Create exception group in MDM
# Devices in "PatchException-2025-Q1" group excluded from declarations
# Review group membership monthly
```

**Exception Monitoring:**

- Alert when exception approaches expiry
- Regular review of exception justifications
- Automatic re-inclusion after exception expiry
- Quarterly audit of all active exceptions

### Exception Renewal and Expiry

**Renewal Process:**

- Review exception 7 days before expiry
- Verify original justification still valid
- Require re-approval for renewal
- Document renewed duration and approval

**Automatic Expiry:**

- Set maximum exception duration (e.g., 90 days)
- Automatically include device in next patch cycle after expiry
- Notify user/manager before automatic inclusion
- Provide grace period for addressing blocking issues

**Compensating Controls:**

- For extended exceptions, implement additional security measures
- Enhanced monitoring for excepted devices
- Network segmentation if appropriate
- Regular security assessments

## 19.12 Security & Compliance Considerations

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
