# Chapter 21: Application Control with Santa

## Learning Objectives

By the end of this chapter, you will be able to:

* Deploy and configure **Santa** as a macOS binary authorization and application control system.  
* Build and test allowlists and blocklists for safe and unwanted applications.  
* Transition Santa from Monitor to Lockdown mode safely.  
* Detect and block unapproved or malicious binaries using TeamID, SigningID, or hash-based rules.  
* Use Santa logs to audit application execution and maintain compliance.

## Introduction

Application control is a cornerstone of macOS endpoint security. Even in environments with MDM and Gatekeeper, administrators often need finer-grained control over what software users can run. **Santa** is a high-performance open-source security agent for macOS that provides binary and file-access authorization.

Santa runs as a system extension leveraging Apple's Endpoint Security (ES) framework. It observes every binary execution event and decides—based on policy—whether to allow or block it. By starting in Monitor mode, you can safely observe the software ecosystem on your fleet before enforcing block or allow policies.

> **Important:** As of February 2025, Google's original Santa repository ([github.com/google/santa](https://github.com/google/santa)) was archived. Santa is now actively maintained by **North Pole Security** ([github.com/northpolesec/santa](https://github.com/northpolesec/santa)). For official documentation, deployment guides, and sync server options, visit [northpole.dev](https://northpole.dev). North Pole Security also offers **Workshop**, a commercial sync server for enterprise Santa management.

## 21.1 Overview and Installation

Santa is a binary authorization system for macOS that monitors and optionally blocks the execution of binaries based on rule sets you define. Originally developed by Google, Santa is now actively maintained by **North Pole Security**. Santa runs as a system extension and uses Apple's Endpoint Security (ES) framework to provide binary and file-access authorization with rich system event logging.

Santa operates in two primary modes:

* **Monitor Mode** – records execution events, does not block.  
* **Lockdown Mode** – enforces allow/deny rules.

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

If you see “ActivationState: Activated,” the system extension is live.

## 21.2 Configuration via Configuration Profile

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

## 21.3 Creating and Managing Rules

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

## 21.4 Testing and Transition to Lockdown Mode

When transitioning from Monitor to Lockdown mode, follow this workflow:

1. Start in **Monitor** mode for 2–4 weeks to baseline.  
2. Collect observed executions:  
   * If using file logs: `sudo tail -F /var/db/santa/santa.log` (or ship the file to your SIEM).  
   * If using protobuf logs: `sudo santactl printlog --json > /tmp/santa_events.json`.  
3. Build allowlists from observed data (favor TeamID/SigningID rules). Optionally enable **transitive allowlisting** for compilers on developer Macs.  
4. Pilot **Lockdown** (or **Standalone**) with a small group, then expand by department.  
5. Maintain an emergency override (temporary allow rule) and a documented rollback to Monitor.

To change modes, update the **ClientMode** in your Santa configuration profile and redeploy via MDM (no direct `defaults write` against `santa.conf`).

## 21.5 Blocking Unwanted Applications

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

## macOS Scripting Tips

* Start Santa in Monitor mode for 2–4 weeks to baseline your environment before enforcing blocks.
* Prefer TeamID or SigningID rules over binary hashes for easier maintenance and fewer false positives.
* Use transitive allowlisting for developer machines to allow Xcode builds automatically.
* Ship Santa logs to your SIEM for compliance and security monitoring.
* Always maintain documented emergency override procedures for critical applications.
* For the latest updates and community support, visit [northpolesec/santa](https://github.com/northpolesec/santa).
* For official documentation and deployment guides, visit [northpole.dev](https://northpole.dev).
* For enterprise rule management, consider North Pole Security's **Workshop** sync server.

## Chapter 21 Exercise

**Goal:** Create a working Santa-based application control policy.

1. Install and configure Santa in Monitor mode.  
2. Review logs to identify common applications.  
3. Create an allowlist for essential apps and block rules for unwanted or unsigned binaries.  
4. Test Lockdown mode with sample blocks.  
5. Document results and identify any false positives.

**Bonus:** Write a Bash script that automatically detects and blocks apps installed in `/Users/*/Downloads/` that are unsigned or lack a TeamID.
