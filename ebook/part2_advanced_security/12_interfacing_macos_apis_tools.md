# Chapter 12: Interfacing with macOS APIs and Tools

## Learning Objectives

By the end of this chapter, you will be able to:

1. Use `osascript` for user prompts and notifications when appropriate.
2. Understand how to test Keychain access securely.
3. Work with Gatekeeper, TCC, and privacy controls using Bash.
4. Use `profiles` and `mdmclient` for verifying MDM status.
5. Encourage or force macOS updates using built-in tools and open-source solutions.
6. Recognize where MDM and purpose-built tools should take priority over scripting.

## Introduction: Know Your Boundaries

In real-world enterprise environments, tasks like deploying FileVault keys, configuration profiles, and enforcing macOS updates are best handled through a Unified Endpoint Management (UEM) or MDM solution like Jamf, Intune, or Kandji. Trying to fully replace MDM with Bash scripts can create compliance risks and redundant effort.

> **Note:** The techniques in this chapter show how macOS native tools work under the hood. Use these scripts for testing, compliance checks, or troubleshooting — not as a replacement for managed deployment.

## 12.1 Using osascript for Secure User Prompts

AppleScript remains helpful for simple GUI prompts when you need user interaction alongside scripts.

### Example: Admin Approval Prompt

```bash
#!/bin/bash

response=$(osascript <<EOD
tell application "System Events"
    display dialog "An admin-level task is about to run. Continue?" buttons {"Cancel", "Continue"} default button "Continue"
end tell
EOD
)

if [[ "$response" == *"Continue"* ]]; then
  echo "User approved."
else
  echo "User cancelled."
  exit 1
fi
```

### Example: Send a User Notification

```bash
#!/bin/bash

osascript -e 'display notification "Your device security settings were updated by IT." with title "Security Agent"'
```

## 12.2 Understanding Keychain Access for Testing

Your MDM should deploy and rotate secrets in production. But understanding Keychain commands helps you test and verify local workflows.

### Example: Add and Retrieve a Test Secret

```bash
#!/bin/bash

# Add a generic password
security add-generic-password -a "$USER" -s "TestAPIKey" -w "SuperSecret123"

# Retrieve it
password=$(security find-generic-password -s "TestAPIKey" -w)
echo "Password is: $password"
```

> **Best Practice:** Never hard-code real credentials in scripts — use MDM payloads for production secrets.

## 12.3 Gatekeeper, TCC, and Privacy Controls

You can audit and verify your system’s security posture using these commands.

### Query Gatekeeper Status

```bash
#!/bin/bash

spctl --status
```

### Add or Remove Gatekeeper Exceptions

```bash
sudo spctl --add --label "Trusted" /Applications/CustomApp.app
```

### Reset Privacy (TCC) Permissions for Testing

```bash
#!/bin/bash

# Reset all permissions for a specific app bundle ID
tccutil reset All com.yourcompany.yourapp
```

This is useful when testing new Privacy Preferences Policy Control (PPPC) profiles before pushing them via MDM.

## 12.4 Using profiles and mdmclient

The `profiles` and `mdmclient` commands help you verify your MDM status and what profiles are installed.

### Check Enrollment Status

```bash
profiles status -type enrollment
```

### List Installed Profiles

```bash
profiles list
```

### Renew MDM Enrollment

```bash
sudo profiles renew -type enrollment
```

> **Tip:** Never remove MDM profiles manually — always manage them through your MDM console.

## 12.5 Forcing and Encouraging macOS Updates

Keeping devices up to date is a core security control. Use your MDM’s built-in macOS update commands and deferral settings whenever possible.

But you can supplement this with native CLI tools and open-source solutions for better user experience.

### Example: Use softwareupdate CLI

```bash
#!/bin/bash

# List available updates
softwareupdate -l

# Install all available updates and restart if needed
sudo softwareupdate -iaR
```

### Using Nudge and swiftDialog

Instead of building your own `osascript` loops, consider using these community tools:

- [Nudge](https://github.com/macadmins/nudge): Enforce and defer OS updates with clear user messaging.
- [swiftDialog](https://github.com/swiftDialog/swiftDialog): Create modern GUI dialogs that feel native.

These tools integrate well with your MDM but can also be invoked by scripts or `launchd` jobs for local checks and user experience improvements.

## 12.6 Combining with launchd for Compliance Checks

Even with MDM, local scripts can verify compliance and notify IT of drifts.

### Example: Check for Required Profile and Gatekeeper Status

```bash
#!/bin/bash

profiles list | grep "com.company.requiredsecurity"
if [ $? -ne 0 ]; then
  echo "Required security profile is missing!" >> /var/log/local_compliance_check.log
  osascript -e 'display notification "Security profile missing! Contact IT." with title "Compliance Check"'
fi

# Confirm Gatekeeper is enabled
spctl --status | grep "assessments enabled"
if [ $? -ne 0 ]; then
  echo "Gatekeeper is disabled!" >> /var/log/local_compliance_check.log
fi
```

Use a `LaunchAgent` or `LaunchDaemon` to run this script on a schedule.

## Chapter 12 Exercise

### Build a Local Update Enforcement Script

1. Write a script that:

   - Uses `softwareupdate` to check for pending updates.
   - Prompts the user with `osascript` or `swiftDialog` to install them.
   - Installs updates automatically after a deferral period.
   - Logs all actions to `/var/log/local_update_enforcement.log`.

2. Combine this script with a `LaunchAgent` so it runs daily or when a user logs in.

## macOS Scripting Tips

- Always use MDM for production updates, profiles, and secrets.
- Use local scripts for compliance checks, small automations, and custom notifications.
- For complex user interactions, prefer modern tools like Nudge and swiftDialog.
- Test update and security controls on a pilot group before rolling out broadly.

By blending native macOS tools, open-source utilities, and MDM policy, you can maintain a secure, compliant, and up-to-date macOS fleet — without relying on fragile manual scripts alone.

Happy secure scripting!
