# Chapter 21: Application Control with Santa

## Learning Objectives

By the end of this chapter, you will be able to:

- Deploy and configure **Santa** as a macOS binary authorization and application control system.  
- Build and test allowlists and blocklists for safe and unwanted applications.  
- Transition Santa from Monitor to Lockdown mode safely.  
- Detect and block unapproved or malicious binaries using TeamID, SigningID, or hash-based rules.  
- Use Santa logs to audit application execution and maintain compliance.

## Introduction

Application control is a cornerstone of macOS endpoint security. Even in environments with MDM and Gatekeeper, administrators often need finer-grained control over what software users can run. **Santa** is a high-performance open-source security agent for macOS that provides binary and file-access authorization.

Santa runs as a system extension leveraging Apple's Endpoint Security (ES) framework. It observes every binary execution event and decides—based on policy—whether to allow or block it. By starting in Monitor mode, you can safely observe the software ecosystem on your fleet before enforcing block or allow policies.

### Enterprise Application Control Context

In enterprise environments, application control serves multiple critical security functions beyond what Gatekeeper and MDM provide. Organizations face increasing threats from malware, unauthorized software installations, and software supply chain attacks. While Gatekeeper provides baseline protection, it doesn't prevent users from running applications once they're approved or bypassed.

**Security Benefits:**

- **Zero Trust Application Execution**: Only explicitly approved applications can run
- **Malware Prevention**: Block known malicious software and unsigned binaries
- **Compliance Enforcement**: Prevent unauthorized software that violates policies
- **Attack Surface Reduction**: Limit execution to approved software only
- **Audit Trail**: Comprehensive logging of all execution attempts

**Business Drivers:**

- **Regulatory Compliance**: Frameworks like NIST, CIS require application control capabilities
- **Risk Mitigation**: Reduce risk from malware and unauthorized software
- **License Compliance**: Prevent unauthorized software installations
- **Productivity Protection**: Block productivity-draining or risky applications
- **Incident Response**: Rapid containment by blocking malicious software execution

**Operational Considerations:**

- **User Experience**: Balance security with user productivity
- **False Positives**: Legitimate software may be blocked without proper allowlisting
- **Maintenance Overhead**: Ongoing rule management and exception handling
- **Scale**: Managing rules across large fleets requires automation and centralized management

## Building Your Application Control Strategy

Before deploying Santa, develop a comprehensive application control strategy that balances security requirements with operational feasibility.

### Define Your Control Objectives

**Security Goals:**

- What threats are you protecting against? (malware, unauthorized software, supply chain attacks)
- What's your risk tolerance for software execution?
- What compliance requirements drive application control needs?

**Operational Goals:**

- How will you handle legitimate business software needs?
- What's your process for approving new applications?
- How will you minimize user disruption?

### Policy Development

**Allowlist vs. Blocklist Strategy:**

**Allowlist Approach (Most Secure):**

- Only explicitly approved applications can execute
- Requires comprehensive baseline of approved software
- Higher maintenance overhead but strongest security
- Best for high-security environments (finance, healthcare, government)

**Blocklist Approach (Less Restrictive):**

- Block known bad or unauthorized software
- Everything else allowed by default
- Lower maintenance but weaker security posture
- May be appropriate for less restrictive environments

**Hybrid Approach:**

- Allowlist for critical/restricted categories
- Blocklist for known problematic software
- Balance security and operational flexibility

### Baseline Development Process

**Monitor Phase Planning:**

- Deploy Santa in Monitor mode across representative sample
- Run for 2-4 weeks to observe software ecosystem
- Collect execution data from all user roles and departments
- Identify legitimate business applications and workflows

**Rule Development:**

- Build allowlist from monitored execution data
- Prioritize TeamID/SigningID rules over binary hashes
- Document business justification for each approved application
- Plan for exceptions and edge cases

### Department and Role Considerations

**Different Control Levels:**

- **High Security**: Restrictive allowlist, minimal exceptions
- **Standard Users**: Balanced allowlist with standard productivity tools
- **Developers**: More permissive with transitive allowlisting for builds
- **Executives**: Custom policies based on business needs

**Policy Customization:**

- Define standard application sets per role
- Document approved software categories
- Establish exception approval process
- Plan for role-specific rule sets

> **Important:** As of February 2025, Google's original Santa repository ([github.com/google/santa](https://github.com/google/santa)) was archived. Santa is now actively maintained by **North Pole Security** ([github.com/northpolesec/santa](https://github.com/northpolesec/santa)). For official documentation, deployment guides, and sync server options, visit [northpole.dev](https://northpole.dev). North Pole Security also offers **Workshop**, a commercial sync server for enterprise Santa management.

## 21.1 Prerequisites and Requirements

Before deploying Santa, ensure your environment meets these requirements and understand the permissions needed.

### System Requirements

**macOS Version:**

- macOS 10.15 (Catalina) or later required
- Endpoint Security framework requires macOS 10.15+
- Latest Santa versions support macOS 14+ (Sequoia) and newer
- Verify OS version: `sw_vers -productVersion`

**Hardware:**

- Apple silicon (M1/M2/M3) and Intel Macs supported
- No special hardware requirements beyond standard macOS systems

**Permissions Required:**

- **Full Disk Access (FDA)**: Required for Santa daemon to monitor all executions
- **System Extension Approval**: Santa runs as system extension requiring approval
- **Administrator Privileges**: For installation and rule management (local or via MDM)

### MDM and Deployment Requirements

**MDM Platform:**

- MDM with configuration profile deployment capability
- System extension approval via PPPC profiles
- Full Disk Access (PPPC) profile deployment
- Optional: Centralized rule management (Workshop sync server or custom solution)

**Device Enrollment:**

- Devices should be supervised or have managed user enrollment for reliable deployment
- System extension approval works best on supervised/managed devices
- Bootstrap Token escrow recommended for seamless operation

### Network and Infrastructure

**Sync Server (Optional):**

- Centralized rule management requires sync server infrastructure
- Workshop (commercial) or custom sync server
- HTTPS endpoint for rule synchronization
- Authentication/authorization for sync access

**Logging Infrastructure:**

- SIEM integration for log forwarding (recommended)
- Centralized log storage for compliance and analysis
- Log retention based on compliance requirements

## 21.2 Overview and Installation

Santa is a binary authorization system for macOS that monitors and optionally blocks the execution of binaries based on rule sets you define. Originally developed by Google, Santa is now actively maintained by **North Pole Security**. Santa runs as a system extension and uses Apple's Endpoint Security (ES) framework to provide binary and file-access authorization with rich system event logging.

Santa operates in two primary modes:

- **Monitor Mode** – records execution events, does not block.  
- **Lockdown Mode** – enforces allow/deny rules.

> **Also available:** **Standalone** mode (ClientMode=`3`) prompts end users to request approvals without default allow/block behavior. Recent releases also add optional **USB media control** and **file access authorization** features; these are outside this chapter's scope but worth exploring for comprehensive control.

### Installing Santa

```bash
# Step 1: Install via Homebrew (for testing)
brew install santa

# Step 2: Verify installation
santactl version
```

> **Note:** For production, deploy the signed package and an MDM configuration profile to set ClientMode and logging.

For production deployment, download the signed package from [northpolesec/santa releases](https://github.com/northpolesec/santa/releases) or use the deployment guides at [northpole.dev](https://northpole.dev) and deploy a `com.google.santa` configuration profile to set `ClientMode`, logging, and any additional options.

```bash
# Example: Download latest release
curl -L https://github.com/northpolesec/santa/releases/latest/download/santa.pkg -o santa.pkg

# Install
sudo installer -pkg santa.pkg -target /
```

For enterprise deployments requiring centralized rule management, North Pole Security offers **Workshop**, a commercial sync server that provides a web-based interface for managing Santa across your fleet.

### Verifying System Extension and Daemon

After installation, confirm Santa's components are running:

```bash
sudo santactl status
sudo systemextensionsctl list | grep com.google.santa.daemon
```

If you deploy via MDM, also pre-approve the **system extension** and grant **Full Disk Access** to Santa components via a PPPC payload to avoid user prompts.

If you see "ActivationState: Activated," the system extension is live.

## 21.3 Configuration via Configuration Profile

Santa is configured with a **Configuration Profile** (payload domain `com.google.santa`), not by editing a local `santa.conf`. Client mode and logging are set with profile keys.

Minimal example payload content (for MDM or a custom mobileconfig):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadType</key>
      <string>com.google.santa</string>
      <key>PayloadIdentifier</key>
      <string>com.example.santa</string>
      <key>PayloadUUID</key>
      <string>00000000-0000-0000-0000-000000000000</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
      <!-- 1 = MONITOR, 2 = LOCKDOWN, 3 = STANDALONE (2024.11+) -->
      <key>ClientMode</key>
      <integer>1</integer>
      <!-- File log (default path shown). See also protobuf logging below. -->
      <key>EventLogType</key>
      <string>filelog</string>
      <key>EventLogPath</key>
      <string>/var/db/santa/santa.log</string>
      <key>SyncBaseURL</key>
      <string>https://santa.example.com</string>
      <key>EnablePageZeroProtection</key>
      <true/>
      <key>EnableTransitiveWhitelisting</key>
      <true/>
    </dict>
  </array>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadIdentifier</key>
  <string>com.example.santa.profile</string>
  <key>PayloadUUID</key>
  <string>11111111-1111-1111-1111-111111111111</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
</dict>
</plist>
```

Transitive Whitelisting allows trusted compilers (like Xcode) to automatically trust their own builds—a useful option for developer machines.

To change modes, modify the `ClientMode` integer and redeploy the profile (e.g., `1` → Monitor, `2` → Lockdown, `3` → Standalone). If using protobuf logging instead of a flat file, set `EventLogType` to `protobuf`; Santa will then spool events under `/var/db/santa/spool` and you can render them with `santactl printlog`.

## 21.4 Creating and Managing Rules

Santa evaluates rules from most specific to least specific: **CDHash → Binary → SigningID → Certificate → TeamID**.

**Rule types and precedence:** Santa evaluates rules from most specific to least specific: **CDHash → Binary → SigningID → Certificate → TeamID**.

Examples (local rules when no sync server is configured):

1. **Allow by TeamID**

   ```bash
   sudo santactl rule --allow --teamid --identifier TEAMID1234 --reason "Team trusted"
   ```

2. **Allow by Certificate SHA-256**

   ```bash
   sudo santactl rule --allow --certificate --sha256 <cert_sha256> --reason "Trusted developer cert"
   ```

3. **Allow by Binary/CDHash**

   ```bash
   sudo santactl fileinfo "/Applications/App.app/Contents/MacOS/App"  # shows CDHash and SigningID
   sudo santactl rule --allow --cdhash <cdhash> --reason "Specific version approved"
   ```

4. **Block examples**

   ```bash
   sudo santactl rule --block --path "/Applications/BadApp.app" --reason "Unauthorized"
   sudo santactl rule --block --signingid --identifier TEAMID1234:com.vendor.badapp --reason "Block this product"
   ```

> Prefer **TeamID** or **SigningID** where possible; use CDHash/Binary only for pinning specific builds.

## 21.5 Testing and Transition to Lockdown Mode

When transitioning from Monitor to Lockdown mode, follow this workflow:

1. Start in **Monitor** mode for 2–4 weeks to baseline.  
2. Collect observed executions:  
   - If using file logs: `sudo tail -F /var/db/santa/santa.log` (or ship the file to your SIEM).  
   - If using protobuf logs: `sudo santactl printlog --json > /tmp/santa_events.json`.  
3. Build allowlists from observed data (favor TeamID/SigningID rules). Optionally enable **transitive allowlisting** for compilers on developer Macs.  
4. Pilot **Lockdown** (or **Standalone**) with a small group, then expand by department.  
5. Maintain an emergency override (temporary allow rule) and a documented rollback to Monitor.

To change modes, update the **ClientMode** in your Santa configuration profile and redeploy via MDM (no direct `defaults write` against `santa.conf`).

## 21.6 Blocking Unwanted Applications

In enterprise macOS environments, some applications are explicitly disallowed due to licensing, productivity, or security risks. Santa enables administrators to identify and block them precisely using TeamID, SigningID, or binary hash.

### Block Torrent Clients

To block uTorrent and Transmission:

```bash
sudo santactl fileinfo "/Applications/Transmission.app/Contents/MacOS/Transmission"
sudo santactl rule --block --signingid --identifier TEAMID1234:org.m0k.transmission --reason "Unauthorized file sharing software"
```

### Block Remote Access Tools

Block TeamViewer or AnyDesk by TeamID:

```bash
sudo santactl rule --block --teamid TEAMID5678 --reason "Unauthorized remote access"
```

### Block Unsigned or Unknown Apps

Identify unsigned binaries:

```bash
santactl fileinfo /Applications/SomeApp.app/Contents/MacOS/SomeApp
```

If `Signing ID` is missing, it's unsigned. Block it explicitly:

```bash
sudo santactl rule --block --path "/Applications/SomeApp.app" --reason "Unsigned binary not permitted"
```

### Temporary Quarantine Enforcement

You can use Santa rules to block any app stored in `/Users/Shared/Downloads` to prevent execution from untrusted download folders:

```bash
find /Users -type f -path "*/Downloads/*.app" -exec santactl rule --block --path {} --reason "Execution from Downloads folder blocked" \;
```

This ensures binaries downloaded but not yet vetted remain unexecutable until explicitly approved.

### Script Automation for Audit

Generate a list of all unique TeamIDs seen in the last 7 days:

```bash
sudo santactl printlog --json | jq -r '.team_id' | sort -u > /tmp/teamids_seen.txt
```

Use this list to identify unapproved or unexpected vendors.

## 21.7 Rule Management at Scale

Managing Santa rules across large fleets requires systematic approaches to maintain consistency and reduce administrative overhead.

### Centralized Rule Management

**Sync Server Benefits:**

- Centralized rule management from single interface
- Automatic rule distribution to all devices
- Consistent policy enforcement across fleet
- Audit trail of rule changes
- Reduced administrative overhead

**Workshop Sync Server:**

- Commercial sync server from North Pole Security
- Web-based interface for rule management
- Integration with identity systems (AD, Okta)
- Role-based access control
- Comprehensive reporting and analytics

**Custom Sync Server:**

- Open-source sync server implementations available
- Requires infrastructure and maintenance
- More control but higher operational overhead
- Suitable for organizations with development resources

### Rule Organization Strategies

**Hierarchical Rule Sets:**

- Global rules: Apply to all devices (e.g., block known malware)
- Department rules: Apply to specific business units
- Role-based rules: Apply based on user role (developer, executive, standard)
- Device-specific rules: Overrides for individual devices

**Rule Naming Conventions:**

- Use descriptive reasons for rules: "Business Justification - Approved by Security Team"
- Include rule creation date in reason field
- Reference ticket numbers or approval documentation
- Version control rule sets for change tracking

**Rule Lifecycle Management:**

- Document all rules with business justification
- Regular review of rules for continued relevance
- Archive deprecated rules with removal date
- Track rule changes and approvals

### Automating Rule Deployment

**Bulk Rule Import:**

- Export rules from monitoring phase as CSV/JSON
- Script bulk rule creation: `santactl rule --allow --teamid --identifier TEAMID --reason "Bulk import"`
- Validate rules before deployment
- Test rule sets in pilot before broad deployment

**Version Control:**

- Store rule configurations in Git repository
- Track changes and approvals
- Automated rule deployment from version control
- Rollback capabilities for problematic rule sets

**Example Bulk Rule Script:**

```bash
#!/bin/bash
# bulk_import_rules.sh - Import rules from CSV

CSV_FILE="/path/to/approved_teamids.csv"

while IFS=',' read -r teamid reason; do
    sudo santactl rule --allow --teamid --identifier "$teamid" --reason "$reason"
done < "$CSV_FILE"
```

## 21.8 Workshop Sync Server for Enterprise Deployments

For enterprise environments managing hundreds or thousands of devices, North Pole Security's **Workshop** sync server provides centralized rule management and operational capabilities.

### Workshop Overview

**Key Features:**

- Web-based rule management interface
- Centralized rule distribution to all devices
- Integration with identity systems (LDAP, AD, Okta)
- Role-based access control for rule management
- Comprehensive reporting and analytics
- Audit logging of all rule changes

**Benefits:**

- Reduced administrative overhead vs. local rule management
- Consistent policy enforcement across fleet
- Scalable to thousands of devices
- Professional support and maintenance

### Workshop Setup and Integration

**Infrastructure Requirements:**

- Server hosting Workshop (cloud or on-premises)
- HTTPS endpoint for device connections
- Identity provider integration (optional but recommended)
- Database for rule storage

**Device Configuration:**

- Configure Santa with Workshop sync URL in configuration profile
- Authenticate devices to Workshop (certificate-based or OAuth)
- Devices automatically sync rules from Workshop

**Rule Management Workflow:**

1. Create rules in Workshop web interface
2. Assign rules to device groups or tags
3. Rules automatically distributed to devices
4. Monitor rule application and compliance

### Alternative: Custom Sync Server

For organizations preferring open-source solutions, custom sync server implementations are available:

- **Kolide Fleet**: Open-source endpoint management with Santa integration
- **Custom API**: Build custom sync server using Santa sync protocol
- **Git-based**: Use Git repository as sync source (advanced)

## 21.9 Operational Considerations

Successful application control requires careful attention to user experience, false positive management, and operational processes.

### Managing False Positives

**Common False Positive Scenarios:**

- Legitimate software not in allowlist
- Updated applications with new signatures
- Developer-built tools requiring approval
- Third-party tools required for business workflows

**False Positive Resolution Process:**

1. User reports blocked application
2. Security team reviews application
3. Verify application legitimacy and business need
4. Add to allowlist if approved (TeamID/SigningID preferred)
5. Document approval and business justification

**Preventing False Positives:**

- Comprehensive baseline during Monitor phase
- Regular allowlist reviews and updates
- Clear communication to users about approved software
- Self-service request portal for new applications

### User Experience Optimization

**Communication:**

- Educate users about application control policies
- Provide clear guidance on requesting software approval
- Set expectations about approval timelines
- Regular updates on policy changes

**Approval Process:**

- Streamlined request process (ticket system, portal)
- Clear SLA for approval times (e.g., 24-48 hours)
- Self-service portal for common applications
- Automated approvals for pre-approved software categories

**Error Messages:**

- Configure Santa to show clear block messages
- Include contact information for approval requests
- Provide temporary workarounds when possible
- Regular user feedback collection

### Exception Management

**Temporary Exceptions:**

- Time-bound allow rules for urgent business needs
- Document exception justification
- Set expiration dates for temporary approvals
- Regular review and renewal process

**Permanent Exceptions:**

- Formal approval process with security review
- Document business justification
- Include in standard allowlist
- Regular review for continued validity

### Performance and Resource Impact

**System Impact:**

- Santa has minimal performance overhead (<1% CPU typical)
- Memory usage: ~50-100 MB for daemon
- Endpoint Security framework is highly optimized
- No noticeable impact on application launch times

**Monitoring Performance:**

- Track CPU and memory usage: `top -pid $(pgrep santad)`
- Monitor log file growth: `ls -lh /var/db/santa/santa.log`
- Watch for performance issues in large deployments
- Adjust logging verbosity if needed

## 21.10 Comprehensive Troubleshooting

This section addresses common issues encountered when deploying Santa in enterprise environments.

### Installation and Configuration Issues

**System Extension Not Activating:**

**Symptom**: `systemextensionsctl list` shows extension as pending or not activated

**Diagnosis:**

```bash
# Check extension status
sudo systemextensionsctl list | grep santa

# Check for extension approval prompts
log show --predicate 'subsystem == "com.apple.systemextensions"' --last 1h
```

**Solutions:**

- Deploy PPPC profile for system extension approval
- Verify device is supervised/managed for automatic approval
- Manual approval: System Settings → Privacy & Security → System Extensions
- Restart device if extension stuck in pending state

**Full Disk Access Not Working:**

**Symptom**: Santa not detecting executions, empty event logs

**Diagnosis:**

```bash
# Check FDA status
tccutil reset SystemPolicyAllFiles com.google.santa.daemon

# Verify PPPC profile applied
profiles -P | grep -i "full.disk\|systempolicyallfiles"
```

**Solutions:**

- Deploy PPPC profile granting Full Disk Access to Santa daemon
- Verify profile targets correct binary path: `/opt/santa/bin/santad`
- Restart Santa daemon after profile deployment: `sudo santactl sync`
- Check System Settings → Privacy & Security → Full Disk Access

**Configuration Profile Not Applying:**

**Symptom**: Santa running in wrong mode or with incorrect settings

**Diagnosis:**

```bash
# Check current configuration
sudo santactl status

# Verify profile is installed
profiles -P | grep -i santa

# Check profile payload
profiles -P -o stdout-xml | grep -A 20 "com.google.santa"
```

**Solutions:**

- Verify profile scope in MDM console
- Check for profile conflicts
- Force profile refresh: `sudo profiles -N`
- Verify profile format is correct

### Rule Management Issues

**Rules Not Applying:**

**Symptom**: Applications blocked/allowed despite rules

**Diagnosis:**

```bash
# List all rules
sudo santactl rule --list

# Check rule for specific binary
santactl fileinfo "/Applications/App.app/Contents/MacOS/App"

# Verify rule precedence (most specific wins)
sudo santactl rule --list | grep -i "appname"
```

**Solutions:**

- Verify rule matches binary (check TeamID, SigningID, path)
- Check rule precedence (more specific rules override general ones)
- Ensure rules are synced: `sudo santactl sync`
- Clear and recreate rules if corrupted

**Sync Server Connection Issues:**

**Symptom**: Devices not receiving rules from sync server

**Diagnosis:**

```bash
# Check sync status
sudo santactl status | grep -i sync

# Test sync server connectivity
curl -v https://santa.example.com

# Check sync logs
tail -50 /var/db/santa/santa.log | grep -i sync
```

**Solutions:**

- Verify sync URL in configuration profile
- Check network connectivity to sync server
- Verify authentication credentials/certificates
- Check sync server logs for connection issues

### Operational Issues

**High False Positive Rate:**

**Symptom**: Many legitimate applications being blocked

**Solutions:**

- Review allowlist coverage during Monitor phase
- Add common applications to allowlist proactively
- Use broader rules (TeamID) rather than specific binaries
- Enable transitive allowlisting for developer machines
- Regular allowlist reviews and updates

**User Complaints About Blocked Applications:**

**Symptom**: Users cannot run legitimate business software

**Resolution Process:**

1. Verify application is legitimate and business-justified
2. Check if application is already in allowlist (may be rule issue)
3. Add to allowlist using appropriate rule type
4. Communicate resolution to user
5. Document approval for future reference

**Performance Issues:**

**Symptom**: System slowdown or high resource usage

**Diagnosis:**

```bash
# Check Santa daemon resource usage
top -pid $(pgrep santad)

# Monitor log file size
ls -lh /var/db/santa/santa.log

# Check for excessive logging
tail -1000 /var/db/santa/santa.log | wc -l
```

**Solutions:**

- Reduce logging verbosity if excessive
- Implement log rotation for large log files
- Review rule count (too many rules may impact performance)
- Check for system resource constraints

### Monitoring and Maintenance

**Regular Maintenance Tasks:**

- Review false positive reports monthly
- Update allowlist based on new software deployments
- Audit rule set quarterly for relevance
- Monitor Santa daemon health and resource usage
- Review and update sync server connectivity

**Health Checks:**

```bash
#!/bin/bash
# santa_health_check.sh - Verify Santa is operating correctly

# Check daemon is running
if ! pgrep -x santad > /dev/null; then
    echo "ERROR: Santa daemon not running"
    exit 1
fi

# Check system extension is active
if ! systemextensionsctl list | grep -q "ActivationState: Activated"; then
    echo "WARNING: System extension not activated"
fi

# Check recent events
recent_events=$(santactl printlog --json --last 1h | jq '. | length')
echo "Events in last hour: $recent_events"

# Verify configuration
santactl status
```

## macOS Scripting Tips

- Start Santa in Monitor mode for 2–4 weeks to baseline your environment before enforcing blocks.
- Prefer TeamID or SigningID rules over binary hashes for easier maintenance and fewer false positives.
- Use transitive allowlisting for developer machines to allow Xcode builds automatically.
- Ship Santa logs to your SIEM for compliance and security monitoring.
- Always maintain documented emergency override procedures for critical applications.
- For the latest updates and community support, visit [northpolesec/santa](https://github.com/northpolesec/santa).
- For official documentation and deployment guides, visit [northpole.dev](https://northpole.dev).
- For enterprise rule management, consider North Pole Security's **Workshop** sync server.

## Chapter 21 Exercise

**Goal:** Create a working Santa-based application control policy.

1. Install and configure Santa in Monitor mode.  
2. Review logs to identify common applications.  
3. Create an allowlist for essential apps and block rules for unwanted or unsigned binaries.  
4. Test Lockdown mode with sample blocks.  
5. Document results and identify any false positives.

**Bonus:** Write a Bash script that automatically detects and blocks apps installed in `/Users/*/Downloads/` that are unsigned or lack a TeamID.
