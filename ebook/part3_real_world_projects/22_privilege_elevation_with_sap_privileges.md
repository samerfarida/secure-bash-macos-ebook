# Chapter 22: Privilege Elevation with SAP Privileges

## Learning Objectives

By the end of this chapter, you will be able to:

* Deploy and configure **SAP Privileges** for time-limited administrative rights.
* Integrate Privileges with MDM or Jamf for managed self-service elevation.
* Automate elevation and demotion with scripts and LaunchAgents.
* Implement least-privilege workflows that maintain user autonomy.

## Introduction

Privilege management is a cornerstone of macOS fleet security. Rather than granting full-time admin rights, organizations can use **macOS Enterprise Privileges** (formerly SAP Privileges) to empower users with temporary elevation. This open-source tool developed by SAP provides time-limited admin rights with customizable expiration intervals and seamless MDM integration.

This chapter provides practical examples and managed configuration tips to build a secure and user-friendly elevation workflow using Privileges.

## 22.1 Overview

**macOS Enterprise Privileges** (commonly referred to as SAP Privileges or simply "Privileges") is an open-source menubar application developed by SAP that enables users to temporarily promote themselves to administrator privileges with IT-defined limits. It fits perfectly within macOS environments enforcing least privilege—particularly in enterprises, education, and regulated industries.

When properly configured, Privileges allows standard users to:

* Elevate to admin temporarily with configurable timeouts.
* Automatically demote after a fixed time, logout, or system time changes.
* Provide reason codes for privilege requests (audit trail).
* Log all privilege changes for compliance and auditing.
* Integrate seamlessly with MDM or Jamf for centralized policy control.
* Be limited to specific groups or users via configuration profiles.

## 22.2 Installation

### Installing via Homebrew (Testing/Development)

For testing or individual deployment, install via Homebrew:

```bash
brew install --cask privileges
```

### Installing via Signed Package (Production)

For managed environments, download and deploy the signed installer package from the [official SAP repository](https://github.com/SAP/macOS-enterprise-privileges/releases):

```bash
# Download latest release
curl -L https://github.com/SAP/macOS-enterprise-privileges/releases/latest/download/Privileges.pkg -o /tmp/Privileges.pkg

# Install
sudo installer -pkg /tmp/Privileges.pkg -target /
```

### Post-Installation Verification

After installation, verify Privileges is running:

```bash
# Check if Privileges.app is installed
ls /Applications/Privileges.app

# Launch the application to check for system extension approval
open /Applications/Privileges.app
```

**Important:** On first launch, macOS will prompt for system extension approval. Deploy a PPPC (Privacy Preferences Policy Control) payload via MDM to pre-approve the system extension and avoid user prompts.

### PPPC Configuration for Privileges

Create a PPPC payload to grant necessary permissions:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadType</key>
      <string>com.apple.TCC.configuration.profile</string>
      <key>PayloadIdentifier</key>
      <string>com.example.privileges.pppc</string>
      <key>PayloadUUID</key>
      <string>22222222-2222-2222-2222-222222222222</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
      <key>Services</key>
      <array>
        <string>SystemPolicyAllFiles</string>
        <string>SystemPolicySysAdminFiles</string>
      </array>
      <key>Identifier</key>
      <string>corp.sap.privileges</string>
      <key>CodeRequirement</key>
      <string>identifier "corp.sap.privileges" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] and certificate leaf[field.1.2.840.113635.100.6.1.13]</string>
      <key>StaticCode</key>
      <integer>0</integer>
      <key>Comment</key>
      <string>Grant Privileges full disk access</string>
      <key>Allowed</key>
      <true/>
    </dict>
  </array>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadIdentifier</key>
  <string>com.example.privileges.pppc.profile</string>
  <key>PayloadUUID</key>
  <string>33333333-3333-3333-3333-333333333333</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
  <key>PayloadDisplayName</key>
  <string>Privileges PPPC</string>
</dict>
</plist>
```

For comprehensive installation documentation, visit the [Privileges Wiki](https://github.com/SAP/macOS-enterprise-privileges/wiki).

## 22.3 Configuration via Managed Preferences

### Preference Domain

The managed preferences domain is:

```xml
corp.sap.privileges
```

### Essential Configuration Keys

Key configuration options include:

* **ExpirationInterval**: Fixed time interval (minutes) before privileges expire. Set to `0` to disable timeout.
* **ExpirationIntervalMax**: Maximum allowed interval (minutes) users can select. Recommended over fixed intervals.
* **MaxIntervalInitial**: Initial timeout (minutes) if user hasn't set a preference yet
* **EnforcePrivileges**: Force demotion even if user manually added themselves to admin group. Prevents bypass attempts.
* **RequireAuthentication**: Require user password/Touch ID before elevation. Adds security layer.
* **RequireBiometricAuthentication**: Force Touch ID or Face ID for elevation
* **RevokePrivilegesAtLogin**: Automatically revoke at login/reboot. Prevents persistent admin rights.
* **RevokePrivilegesAfterSystemTimeChange**: Demote if system clock is tampered. Prevents time manipulation.
* **LimitToGroup**: Restrict Privileges to specific AD/LDAP group (e.g., `corp\helpdesk`)
* **LimitToUser**: Restrict Privileges to specific users (comma-separated)
* **ReasonRequired**: Require users to provide reason for elevation
* **ReasonMinLength/ReasonMaxLength**: Control reason text length
* **RemoteLogging**: Forward events to syslog server for centralized monitoring

For a complete list of all configuration keys, see the [Managing Privileges Wiki](https://github.com/SAP/macOS-enterprise-privileges/wiki/Managing-Privileges).

### Configuration Profile Example

Deploy this via MDM or include in a `.mobileconfig` file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadType</key>
      <string>com.apple.ManagedClient.preferences</string>
      <key>PayloadIdentifier</key>
      <string>corp.sap.privileges</string>
      <key>PayloadUUID</key>
      <string>00000000-0000-0000-0000-000000000000</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
      <key>PayloadEnabled</key>
      <true/>
      <key>PayloadDisplayName</key>
      <string>Privileges Configuration</string>
      <key>PayloadDescription</key>
      <string>Configure Privileges time-limited admin rights</string>
      
      <!-- Time-limited elevation (minutes). Set 0 to disable timeout -->
      <key>Forced</key>
      <array>
        <dict>
          <key>mcx_preference_settings</key>
          <dict>
            <key>ExpirationInterval</key>
            <integer>15</integer>
            
            <!-- Maximum user-selectable interval (minutes). Recommended over fixed interval -->
            <key>ExpirationIntervalMax</key>
            <integer>30</integer>
            
            <!-- Revoke privileges when user logs out or restarts -->
            <key>RevokePrivilegesAtLogin</key>
            <true/>
            
            <!-- Optional: require reason for elevation -->
            <key>ReasonRequired</key>
            <true/>
            <key>ReasonMinLength</key>
            <integer>10</integer>
            
            <!-- Custom help URL -->
            <key>HelpButtonCustomURL</key>
            <string>https://intranet.example.com/help/privileges</string>
          </dict>
        </dict>
      </array>
    </dict>
  </array>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadIdentifier</key>
  <string>com.example.privileges.profile</string>
  <key>PayloadUUID</key>
  <string>11111111-1111-1111-1111-111111111111</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
  <key>PayloadDisplayName</key>
  <string>Privileges Configuration</string>
  <key>PayloadDescription</key>
  <string>Configures time-limited admin privileges</string>
  <key>PayloadOrganization</key>
  <string>Example Corp</string>
</dict>
</plist>
```

**Configuration Notes:**

* Use `ExpirationIntervalMax` instead of `ExpirationInterval` for better user experience—allows users to choose their own interval up to the maximum.
* `RevokePrivilegesAtLogin` ensures no user retains admin rights across sessions.
* `ReasonRequired` creates an audit trail of why privilege elevation was requested.
* Combine this configuration with a PPPC payload granting **Full Disk Access** to Privileges for proper script execution and logging.
* For Jamf users, download the JSON Schema manifest from the [Managing Privileges Wiki](https://github.com/SAP/macOS-enterprise-privileges/wiki/Managing-Privileges) to create configurations in Jamf Pro.

## 22.4 Command-Line Interface (PrivilegesCLI)

The command-line utility allows scripting and automation of privilege changes. It is included inside the app bundle:

```bash
# Check current privilege status
/Applications/Privileges.app/Contents/Resources/PrivilegesCLI --status

# Request admin rights
/Applications/Privileges.app/Contents/Resources/PrivilegesCLI --add

# Remove admin rights and return to standard user
/Applications/Privileges.app/Contents/Resources/PrivilegesCLI --remove
```

To make the CLI globally available (use with caution in managed environments):

```bash
sudo bash -c 'echo "/Applications/Privileges.app/Contents/Resources" > /etc/paths.d/PrivilegesCLI'
```

Afterward, you can invoke it simply as `PrivilegesCLI`. However, for managed environments, explicitly reference the full path in scripts for reliability.

### Automating Elevation and Demotion

A simple Bash automation script with error handling:

```bash
#!/bin/bash
set -euo pipefail

# Full path to avoid PATH issues
PRIVILEGES_CLI="/Applications/Privileges.app/Contents/Resources/PrivilegesCLI"

# Check if user is already admin
if $PRIVILEGES_CLI --status | grep -q "admin"; then
    echo "User already has admin rights"
    exit 0
fi

# Request admin rights
$PRIVILEGES_CLI --add

# Wait 15 minutes (900 seconds)
sleep 900

# Remove admin rights
$PRIVILEGES_CLI --remove

# Log the automation
echo "$(date): Admin rights granted and auto-revoked after 15 minutes" >> ~/Library/Logs/Privileges.log
```

This grants admin rights for 15 minutes (900 seconds) and then automatically revokes them. Note that this approach is less secure than using configuration profiles with `ExpirationInterval` or `ExpirationIntervalMax`, as scripts can be terminated.

## 22.5 Integration with MDM and Jamf

MDM systems like Jamf can integrate SAP Privileges through **Self Service** or policy scripts.

Example Jamf script:

```bash
#!/bin/bash
/Applications/Privileges.app/Contents/Resources/PrivilegesCLI --add
osascript -e 'display notification "Temporary admin rights granted for 15 minutes" with title "Privileges"'
sleep 900
/Applications/Privileges.app/Contents/Resources/PrivilegesCLI --remove
osascript -e 'display notification "Admin rights revoked" with title "Privileges"'
```

Best practices:

* Notify the user when elevation is granted or revoked.
* Enforce limits via configuration profiles rather than script timers alone.
* Log all actions for auditability.

## 22.6 Automation with LaunchAgents

You can automate demotion at login by creating a LaunchAgent:

```bash
cat <<EOF | sudo tee /Library/LaunchAgents/com.example.demoteatlogin.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.example.demoteatlogin</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Applications/Privileges.app/Contents/Resources/PrivilegesCLI</string>
    <string>--remove</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF
```

Load it:

```bash
sudo launchctl load -w /Library/LaunchAgents/com.example.demoteatlogin.plist
```

This ensures any user is reverted to standard privileges upon login.

## 22.7 Auditing and Logging

Privileges maintains comprehensive local logging and supports remote logging via syslog.

### Local Logging

Privileges maintains a local log file:

```bash
~/Library/Logs/Privileges.log
```

For enterprise monitoring, forward this log to your SIEM (e.g., Splunk, Elastic, or Sentinel). Example collection snippet:

```bash
tail -F ~/Library/Logs/Privileges.log | logger -t Privileges
```

### Remote Logging via Syslog

For centralized logging, configure remote syslog in your configuration profile:

```xml
<key>RemoteLogging</key>
<dict>
  <key>ServerAddress</key>
  <string>syslog.example.com</string>
  <key>ServerPort</key>
  <integer>514</integer>
  <key>UseTLS</key>
  <true/>
  <key>LogFacility</key>
  <integer>4</integer>
  <key>LogSeverity</key>
  <integer>6</integer>
</dict>
```

This forwards Privileges events to your centralized logging infrastructure for compliance and security monitoring.

### Remote Logging Configuration in Profile

Here's a complete example showing RemoteLogging in the profile structure:

```xml
<key>RemoteLogging</key>
<dict>
  <key>ServerAddress</key>
  <string>syslog.example.com</string>
  <key>ServerPort</key>
  <integer>514</integer>
  <key>UseTLS</key>
  <true/>
  <key>TLSIdentity</key>
  <string>CN=syslog.example.com</string>
  <key>LogFacility</key>
  <integer>4</integer>
  <key>LogSeverity</key>
  <integer>6</integer>
  <key>MaximumMessageSize</key>
  <integer>480</integer>
</dict>
```

### Monitoring Admin Access

Combine with Jamf extension attributes, osquery queries, or endpoint detection tools to track admin group membership and privilege elevation events.

### Example osquery Query to Monitor Admin Access

```sql
SELECT * FROM groups WHERE groupname = 'admin';
```

This query can be scheduled to track when users are added to or removed from the admin group.

### Example Jamf Extension Attribute for Compliance

```bash
#!/bin/bash
# Check if user is in admin group
if /usr/bin/dscl . -read /Groups/admin GroupMembership | grep -q "$(whoami)"; then
    echo "<result>Has Admin</result>"
else
    echo "<result>Standard User</result>"
fi
```

This extension attribute reports admin status back to Jamf for compliance dashboards.

## Chapter 22 Exercise

**Goal:** Implement a controlled privilege elevation workflow.

**Tasks:**

1. Install SAP Privileges using Homebrew or MDM:
   * Download from [GitHub releases](https://github.com/SAP/macOS-enterprise-privileges/releases)
   * Deploy PPPC payload to pre-approve system extension

2. Configure a 15-minute maximum timeout via configuration profile:
   * Use `ExpirationIntervalMax` for user flexibility
   * Set `RevokePrivilegesAtLogin` for security
   * Enable `ReasonRequired` for audit trail
   * Deploy via MDM to test client

3. Create a `LaunchAgent` to revoke admin rights at login:
   * Place plist in `/Library/LaunchAgents/`
   * Load with `launchctl load -w`
   * Verify revoke on next login

4. Build a Jamf Self Service policy for manual elevation:
   * Create script that calls `PrivilegesCLI --add`
   * Add to Self Service with clear description
   * Test elevation and automatic demotion

5. Monitor the Privileges log to verify activity:
   * Check `~/Library/Logs/Privileges.log` for events
   * Configure remote syslog if available
   * Verify audit trail includes reason codes (if enabled)

**Bonus Challenge:**  
Write a Bash wrapper script that checks if the user is already admin before running `PrivilegesCLI --add`, ensuring idempotent elevation. Use `dscl` or `groups` command to check admin group membership.

## macOS Scripting Tips

* Always test timeouts and demotion scripts on a non-admin test user before production rollout.
* Keep Privileges updated; new versions often add UX improvements and additional configuration keys.
* Use `ExpirationIntervalMax` instead of `ExpirationInterval` for better user experience—allows flexibility while maintaining IT control.
* Set `RevokePrivilegesAtLogin` to ensure no user retains admin rights across sessions or reboots.
* Use `EnforcePrivileges` to prevent users from manually adding themselves to the admin group.
* Leverage `LimitToGroup` or `LimitToUser` to restrict Privileges access to specific authorized users.
* Configure remote logging via syslog to forward privilege elevation events to your SIEM for compliance.
* Combine Privileges with Santa or Endpoint Security tools for full least-privilege coverage and defense-in-depth.
* Regularly audit admin group membership with osquery or Jamf reports to ensure compliance.
* Leverage PPPC profiles to grant necessary permissions (Full Disk Access) for scripts and the Privileges app itself.
* Review the [official Privileges Wiki](https://github.com/SAP/macOS-enterprise-privileges/wiki) for the latest configuration options and best practices.
