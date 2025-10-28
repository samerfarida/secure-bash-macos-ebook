# Chapter 22: Privilege Elevation with SAP Privileges

## Learning Objectives

By the end of this chapter, you will be able to:

* Deploy and configure **SAP Privileges** for time-limited administrative rights.
* Integrate Privileges with MDM or Jamf for managed self-service elevation.
* Automate elevation and demotion with scripts and LaunchAgents.
* Implement least-privilege workflows that maintain user autonomy.

## Introduction

Privilege management is a cornerstone of macOS fleet security. Rather than granting full-time admin rights, organizations can use **SAP Privileges** to empower users with temporary elevation. This chapter provides practical examples and managed configuration tips to build a secure and user-friendly elevation workflow.



## 22.1 Overview

**SAP Privileges** is an open-source menubar app developed by SAP that enables users to temporarily promote themselves to administrator privileges with IT-defined limits. It fits perfectly within macOS environments enforcing least privilege — particularly in enterprises, education, and regulated industries.

When properly configured, Privileges allows standard users to:

* Elevate to admin temporarily.
* Automatically demote after a fixed time or logout.
* Log all privilege changes for auditing.
* Integrate seamlessly with MDM or Jamf for policy control.



## 22.2 Installation

For testing or individual deployment, install via Homebrew:

```bash
brew install --cask privileges
```

For managed environments, deploy the signed installer package from SAP’s official repository:

```bash
https://github.com/SAP/macOS-enterprise-privileges/releases
```

Deployment options include:

* **Manual installation** for pilots.
* **MDM payload** or **Jamf package** deployment for scale.
* **LaunchAgent automation** for timed revocation.



## 22.3 Configuration via Managed Preferences

### 3.1 Preference Domain

The managed preferences domain is:

```bash
corp.sap.privileges
```

### 3.2 Configuration Profile Example

Deploy this via MDM or include in a `.mobileconfig` file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <!-- Time-limited elevation (minutes). Set 0 to disable timeout -->
  <key>ExpirationInterval</key>
  <integer>15</integer>

  <!-- Maximum user-selectable interval (minutes). Optional -->
  <key>ExpirationIntervalMax</key>
  <integer>30</integer>

  <!-- Run an app or script after privilege change -->
  <key>PostChangeExecutablePath</key>
  <string>/usr/local/bin/after_priv_change.sh</string>

  <key>PostChangeActionOnGrantOnly</key>
  <false/>

  <!-- Optional UX and targeting keys -->
  <key>HelpButtonCustomURL</key>
  <string>https://intranet.example.com/help/privileges</string>
</dict>
</plist>
```

**Key Notes:**

* `ExpirationInterval` defines the default duration in minutes.
* Post-action scripts run under the logged-in user context.
* Use `RevokeAtLoginExcludedUsers` to skip automatic demotion for admin accounts.
* Combine this configuration with a PPPC payload granting Full Disk Access to Privileges for script execution.



## 22.4 Command-Line Interface (PrivilegesCLI)

The command-line utility allows scripting and automation of privilege changes. It is included inside the app bundle:

```bash
/Applications/Privileges.app/Contents/Resources/PrivilegesCLI --status
/Applications/Privileges.app/Contents/Resources/PrivilegesCLI --add
/Applications/Privileges.app/Contents/Resources/PrivilegesCLI --remove
```

To make the CLI globally available:

```bash
sudo bash -c 'echo "/Applications/Privileges.app/Contents/Resources" > /etc/paths.d/PrivilegesCLI'
```

Afterward, you can invoke it simply as `PrivilegesCLI`.

### 4.1 Automating Elevation and Demotion

A simple Bash automation script:

```bash
#!/bin/bash
PrivilegesCLI --add
sleep 900
PrivilegesCLI --remove
```

This grants admin rights for 15 minutes (900 seconds) and then automatically revokes them.



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

Privileges maintains a local log file:

```bash
~/Library/Logs/Privileges.log
```

For enterprise monitoring, forward this log to your SIEM (e.g., Splunk, Elastic, or Sentinel).  
Example collection snippet:

```bash
tail -F ~/Library/Logs/Privileges.log | logger -t Privileges
```

Combine with Jamf extension attributes or osquery queries to track admin group membership.



## Chapter 22 Exercise

**Goal:** Implement a controlled privilege elevation workflow.

**Tasks:**

1. Install SAP Privileges using Homebrew or MDM.
2. Configure a 15-minute timeout via configuration profile.
3. Create a `LaunchAgent` to revoke admin rights at login.
4. Build a Jamf Self Service policy for manual elevation.
5. Monitor the Privileges log to verify activity.

**Bonus Challenge:**  
Write a Bash wrapper script that checks if the user is already admin before running `PrivilegesCLI --add`, ensuring idempotent elevation.



## macOS Scripting Tips

* Always test timeouts and demotion scripts on a non-admin test user.
* Keep Privileges updated; new versions often add UX improvements and MDM keys.
* Use the same configuration UUID across your fleet to ensure consistent MDM enforcement.
* Combine Privileges with Santa or Endpoint Security tools for full least-privilege coverage.
* Regularly audit admin group membership with osquery or Jamf reports to ensure compliance.
* Leverage PPPC profiles to grant necessary permissions for scripts and the Privileges app itself.
