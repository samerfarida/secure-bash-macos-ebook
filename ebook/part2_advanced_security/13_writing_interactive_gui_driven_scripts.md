# Chapter 13: Writing Interactive and GUI-Driven Scripts

## Learning Objectives

By the end of this chapter, you will be able to:

1. Build user prompts with osascript for interactive Bash scripts.
2. Create dialogs, notifications, and file pickers using AppleScript and osascript.
3. Integrate swiftDialog with Bash for professional user interfaces.
4. Use Platypus to create app-like wrappers for your Bash scripts.
5. Implement best practices for secure, user-friendly interactive scripts.

## Introduction

While command-line automation is powerful, many tasks benefit from graphical user interfaces. macOS provides several tools that allow Bash scripts to interact with users through dialogs, notifications, and file selection interfaces. This chapter covers osascript, swiftDialog, and Platypus—tools that bridge command-line automation and user-friendly interfaces.

Enterprise administrators often need scripts that prompt for approval, show progress, or allow users to select files. Whether deploying updates, requesting admin credentials, or collecting user input, GUI-driven scripts enhance both security and user experience.

## 13.1 Building User Prompts with osascript

osascript executes AppleScript from the command line, enabling Bash scripts to show dialogs, notifications, and system dialogs.

### Basic Dialog Prompts

A simple yes/no dialog:

```bash
#!/bin/bash

response=$(osascript <<'EOF'
tell application "System Events"
    display dialog "Do you want to proceed with the security update?" buttons {"Cancel", "Proceed"} default button "Proceed" giving up after 30
end tell
EOF
)

if [[ "$response" =~ "button returned:Proceed" ]]; then
    echo "User approved the update"
else
    echo "User cancelled or timed out"
    exit 1
fi
```

### Text Input from Users

Collecting user input:

```bash
#!/bin/bash

user_input=$(osascript <<'EOF'
tell application "System Events"
    display dialog "Enter the ticket number:" default answer "" buttons {"Cancel", "OK"} default button "OK"
    set response to text returned of result
    return response
end tell
EOF
)

if [ -z "$user_input" ]; then
    echo "User cancelled"
    exit 1
fi

echo "Ticket number: $user_input"
```

### File Selection Dialogs

Opening file picker dialogs:

```bash
#!/bin/bash

selected_file=$(osascript <<'EOF'
tell application "Finder"
    activate
    set selectedFile to choose file with prompt "Select a configuration file:"
    return POSIX path of selectedFile
end tell
EOF
)

if [ -n "$selected_file" ]; then
    echo "User selected: $selected_file"
    # Process the file
else
    echo "No file selected"
    exit 1
fi
```

### Folder Selection Dialogs

Choose a folder for operations:

```bash
#!/bin/bash

selected_folder=$(osascript <<'EOF'
tell application "Finder"
    set selectedFolder to choose folder with prompt "Select backup destination:"
    return POSIX path of selectedFolder
end tell
EOF
)

echo "Backup destination: $selected_folder"
```

## 13.2 Dialogs, Notifications, and File Pickers

### Progress Dialogs with osascript

Show progress for long-running tasks:

```bash
#!/bin/bash

show_progress() {
    osascript <<'EOF'
tell application "System Events"
    display dialog "Processing files... Please wait." buttons {} giving up after 5
end tell
EOF
}

# Show progress during file operations
show_progress &
# Your file processing logic here
sleep 10
```

### System Notifications

Send notifications:

```bash
#!/bin/bash

send_notification() {
    local title="$1"
    local message="$2"
    
    osascript -e "display notification \"$message\" with title \"$title\""
}

# Usage
send_notification "Security Update" "Your system has been successfully updated"
```

### Alert Dialogs

Critical alerts for administrative actions:

```bash
#!/bin/bash

critical_alert() {
    local message="$1"
    
    osascript <<EOF
tell application "System Events"
    activate
    display alert "Security Alert" message "$message" buttons {"OK"} as critical giving up after 10
end tell
EOF
}

critical_alert "Administrative privileges are required for this operation"
```

### Multi-Step Wizard

Creating step-by-step wizards:

```bash
#!/bin/bash

# Step 1: Introduction
osascript <<'EOF'
tell application "System Events"
    display dialog "Welcome to the macOS Security Configuration Wizard.

This wizard will help you configure your system securely.

Click Continue to begin." buttons {"Cancel", "Continue"} default button "Continue"
end tell
EOF

# Step 2: Collect preferences
response=$(osascript <<'EOF'
tell application "System Events"
    display dialog "Enable automatic security updates?" buttons {"No", "Yes"} default button "Yes"
end tell
EOF
)

if [[ "$response" =~ "button returned:Yes" ]]; then
    echo "Automatic updates enabled"
    # Configure automatic updates
fi
```

## 13.3 swiftDialog Integration with Bash

swiftDialog provides professional-looking dialogs for macOS deployment and user interaction. It's commonly used with MDM and automation tools.

### Installing swiftDialog

```bash
#!/bin/bash

DIALOG_URL="https://github.com/bartreardon/swiftDialog/releases/latest/download/dialog-LATEST.pkg"
DIALOG_PKG="/tmp/dialog.pkg"

# Download swiftDialog
curl -L "$DIALOG_URL" -o "$DIALOG_PKG"

# Install
sudo installer -pkg "$DIALOG_PKG" -target /

# Clean up
rm "$DIALOG_PKG"
```

### Basic swiftDialog Usage

Simple dialog:

```bash
#!/bin/bash

/usr/local/bin/dialog --title "Security Configuration" \
    --message "Configuring security settings on your Mac..." \
    --icon "shield.checkered" \
    --overlayicon "SF=gear" \
    --progress 50
```

### Progress Bars with swiftDialog

Show progress during lengthy operations:

```bash
#!/bin/bash

DIALOG="/usr/local/bin/dialog"

# Start a progress dialog
"$DIALOG" --title "Installing Updates" \
    --message "Please wait while updates are installed..." \
    --progress "Determining updates..." \
    --icon "SF=arrow.down.circle" \
    --overlayicon "hints=update" &

DIALOG_PID=$!

# Simulate installation progress
for i in {1..100}; do
    sleep 0.1
    "$DIALOG" --update "Progress: $i%" --overlayicon "SF=arrow.down.circle.fill,hints=update" &
done

# Close the dialog
"$DIALOG" --quit
wait "$DIALOG_PID"
```

### Input Forms with swiftDialog

Collect structured user input:

```bash
#!/bin/bash

DIALOG="/usr/local/bin/dialog"

# JSON configuration for form
cat > /tmp/dialog.json <<'EOF'
{
    "title": "Security Configuration",
    "message": "Please provide the following information:",
    "icon": "SF=person.crop.circle.badge.plus",
    "textfield": [
        {
            "title": "Employee ID",
            "required": true,
            "prompt": "Enter your employee ID"
        },
        {
            "title": "Department",
            "required": false,
            "prompt": "Enter your department"
        }
    ]
}
EOF

# Show the form
"$DIALOG" --jsonfile /tmp/dialog.json

# Retrieve results
responses=$(cat /var/tmp/dialogArchivedResponseFile.plist 2>/dev/null || echo "")
```

### swiftDialog with Checkboxes

Allow users to select options:

```bash
#!/bin/bash

DIALOG="/usr/local/bin/dialog"

cat > /tmp/dialog.json <<'EOF'
{
    "title": "Installation Options",
    "message": "Select which components to install:",
    "icon": "SF=checkmark.circle",
    "checklist": [
        {"label": "Security Updates", "checked": true},
        {"label": "System Preferences", "checked": true},
        {"label": "Network Configuration", "checked": false}
    ]
}
EOF

"$DIALOG" --jsonfile /tmp/dialog.json

# Read the selected options
plutil -convert xml1 -o /tmp/dialog_response.xml /var/tmp/dialogArchivedResponseFile.plist 2>/dev/null
```

### Non-Blocking Dialogs

Non-interruptive background dialogs:

```bash
#!/bin/bash

DIALOG="/usr/local/bin/dialog"

# Show a notification-style dialog that doesn't block
"$DIALOG" --title "Security Scan Complete" \
    --message "Your system has been scanned successfully.

No threats detected." \
    --icon "SF=checkmark.shield" \
    --button1text "OK" \
    --quitkey "q"
```

## 13.4 Platypus: Creating App-like Bash Scripts

Platypus wraps Bash scripts as native macOS applications with icons and a proper App Bundle structure.

### Basic Platypus Script

Simple automation script:

```bash
#!/bin/bash

# This script can be wrapped with Platypus

show_info() {
    osascript <<'EOF'
tell application "System Events"
    display dialog "System Information

Hostname: $(hostname)
OS Version: $(sw_vers -productVersion)
Uptime: $(uptime)

This dialog was created by Platypus-wrapped Bash script." \
    buttons {"OK"} default button "OK"
end tell
EOF
}

show_info
```

### Platypus Configuration

To convert a script to an app:

```bash
#!/bin/bash
# Use Platypus CLI to create an app

PLATYPUS="/usr/local/bin/platypus"

"$PLATYPUS" -a "My Script App" \
    -o "Text Window" \
    -p "/bin/bash" \
    -u "My Company" \
    -I "SF=terminal" \
    -f myscript.sh \
    MyApp.app
```

### Interactive Platypus Apps

Create apps with GUI dialogs:

```bash
#!/bin/bash
# This script becomes a GUI app with Platypus

MAIN_WINDOW_TEXT=$(cat <<'EOF'
=== Security Configuration Tool ===

This tool will help configure your macOS security settings.

Options:
1. Enable FileVault
2. Configure Firewall
3. Update Security Policies
4. Quit
EOF
)

response=$(osascript <<END
tell application "System Events"
    display dialog "$MAIN_WINDOW_TEXT" buttons {"Quit", "Option 3", "Option 2", "Option 1"} default button "Option 1"
    return button returned of result
end tell
END
)

echo "User selected: $response"

# Process the response
case "$response" in
    "Option 1")
        echo "Configuring FileVault..."
        ;;
    "Option 2")
        echo "Configuring Firewall..."
        ;;
    "Option 3")
        echo "Updating policies..."
        ;;
    *)
        echo "Quitting..."
        ;;
esac
```

## 13.5 Best Practices for Interactive Scripts

### Security Considerations

Never trust GUI input without validation:

```bash
#!/bin/bash
set -euo pipefail

collect_admin_password() {
    local password
    
    password=$(osascript <<'EOF'
tell application "System Events"
    display dialog "Enter your admin password:" default answer "" with hidden answer buttons {"Cancel", "OK"} default button "OK"
    set response to text returned of result
    return response
end tell
EOF
)
    
    if [ -z "$password" ]; then
        echo "Password entry cancelled"
        exit 1
    fi
    
    # Validate password without storing it
    if echo "$password" | sudo -S true 2>/dev/null; then
        echo "Password validated"
    else
        echo "Invalid password"
        exit 1
    fi
}
```

### Error Handling with GUI

Graceful error handling in GUI scripts:

```bash
#!/bin/bash
set -euo pipefail

handle_error() {
    local error_msg="$1"
    
    osascript <<EOF
tell application "System Events"
    display alert "Error" message "$error_msg" buttons {"OK"} as critical
end tell
EOF
    exit 1
}

# Example usage
if [ ! -f "/important/file.txt" ]; then
    handle_error "Critical file not found: /important/file.txt"
fi
```

### Non-Blocking Operations

Avoid blocking the user interface during long operations:

```bash
#!/bin/bash

perform_long_operation() {
    local operation="$1"
    
    # Show background dialog
    osascript <<'EOF' &
tell application "System Events"
    display dialog "Processing, please wait..." buttons {} giving up after 60
end tell
EOF
    
    DIALOG_PID=$!
    
    # Perform the actual work
    execute_operation "$operation"
    
    # Kill the dialog when done
    kill "$DIALOG_PID" 2>/dev/null || true
}

execute_operation() {
    local op="$1"
    echo "Executing: $op"
    sleep 5  # Simulate long operation
}
```

### Accessibility Considerations

Create accessible dialogs:

```bash
#!/bin/bash

accessible_dialog() {
    local title="$1"
    local message="$2"
    
    osascript <<EOF
tell application "System Events"
    display dialog "$message" with title "$title" with icon note buttons {"OK"} default button "OK"
end tell
EOF
}

# Clear, simple language for accessibility
accessible_dialog "System Update" "A software update is available for your Mac. Would you like to install it now?"
```

### Logging User Interactions

Audit trail for GUI interactions:

```bash
#!/bin/bash

log_user_action() {
    local action="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo "[$timestamp] User action: $action" >> ~/Library/Logs/script_audit.log
}

# Example
response=$(osascript <<'EOF'
tell application "System Events"
    display dialog "Install security update?" buttons {"Later", "Now"} default button "Now"
end tell
EOF
)

if [[ "$response" =~ "button returned:Now" ]]; then
    log_user_action "Accepted security update prompt"
else
    log_user_action "Deferred security update"
fi
```

## Chapter 13 Exercise

Goal: Build a complete interactive GUI application that configures security settings.

Requirements:

1. Create a Bash script with a main menu using osascript.
2. Include options to:
   - Check system security status
   - Enable automatic updates
   - Configure firewall settings
3. Use swiftDialog (or osascript) for progress indicators.
4. Implement error handling with user-friendly messages.
5. Log all user actions to `/tmp/security_config.log`.

Solution template:

```bash
#!/bin/bash
set -euo pipefail

LOG_FILE="/tmp/security_config.log"

log_action() {
    echo "[$(date)] $1" >> "$LOG_FILE"
}

show_menu() {
    osascript <<'EOF'
tell application "System Events"
    display dialog "Security Configuration Tool

Choose an option:" buttons {"Check Status", "Enable Updates", "Configure Firewall", "Quit"} default button "Check Status"
end tell
EOF
}

check_security_status() {
    osascript <<'EOF'
tell application "System Events"
    set statusText to "
Security Status:

FileVault: " & (do shell script "fdesetup status")
    display dialog statusText buttons {"OK"} default button "OK"
end tell
EOF
    log_action "Security status checked"
}

enable_auto_updates() {
    osascript <<'EOF'
tell application "System Events"
    display dialog "Enabling automatic security updates..." buttons {} giving up after 3
end tell
EOF
    
    sudo softwareupdate --schedule on
    log_action "Automatic updates enabled"
}

configure_firewall() {
    osascript <<'EOF'
tell application "System Events"
    display dialog "Firewall configuration:" buttons {"Allow", "Block", "Cancel"} default button "Allow"
end tell
EOF
    
    # Configure firewall (example)
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    log_action "Firewall configured"
}

# Main script logic
response=$(show_menu)

case "$response" in
    *"Check Status"*)
        check_security_status
        ;;
    *"Enable Updates"*)
        enable_auto_updates
        ;;
    *"Configure Firewall"*)
        configure_firewall
        ;;
    *)
        echo "Goodbye"
        log_action "User quit"
        ;;
esac
```

## macOS Scripting Tips

- Always validate user input from GUI dialogs; never trust GUI responses blindly.
- Use `osascript` for simple dialogs; use swiftDialog for deployment scenarios.
- Prefer notification-style alerts for non-critical messages; use critical alerts sparingly.
- Test GUI scripts with VoiceOver enabled to ensure accessibility.
- Log all administrative actions taken through GUI interactions.
- Combine GUI prompts with command-line defaults for automation scenarios.
- Use the `giving up after` parameter to prevent dialogs from hanging indefinitely.
- Keep dialog text clear and concise—avoid technical jargon when possible.
- Implement progress indicators for operations longer than 5 seconds.
- Never store sensitive data (passwords, tokens) in dialog responses permanently.
