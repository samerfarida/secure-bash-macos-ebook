# Chapter 10: macOS Internals for Scripting

## Learning Objectives

By the end of this chapter, you will be able to:

- Understand how `launchctl` and `launchd` manage background processes on macOS.
- Explain how System Integrity Protection (SIP) affects your Bash scripts.
- Work with Privacy Preferences Policy Control (PPPC) to grant necessary permissions.
- Troubleshoot Launch Agents and Daemons.
- Use the macOS unified logging system for script debugging.
- Understand sandboxing basics and how they affect script execution.

---

## Introduction: Scripting with macOS Internals in Mind

macOS combines security features, system tools, and logging mechanisms you must know to write reliable Bash scripts. `launchd` controls background processes, SIP restricts certain operations, and PPPC governs access to user data. You’ll also learn how to use the unified log and how sandboxing can limit script actions.

---

## Using launchctl and launchd

`launchd` is the service manager for macOS. `launchctl` is how you interact with it.

### Common launchctl Commands

```bash
launchctl list
sudo launchctl list
launchctl load ~/Library/LaunchAgents/com.example.job.plist
launchctl unload ~/Library/LaunchAgents/com.example.job.plist
launchctl kickstart -k gui/$(id -u)/com.example.job
```

### Troubleshooting Tips

- Check plist syntax:

```bash
plutil -lint file.plist
```

- Use:

```bash
log show --predicate 'process == "launchd"'
```

- Ensure correct file permissions: daemons need to be root-owned.

### Example: Automate Daily Backups

Schedule a `LaunchDaemon` to run a backup script daily using `rsync`.

1. Create your backup script, for example `/usr/local/bin/backup.sh`:

```bash
#!/bin/bash
rsync -av --delete ~/Documents/ /Volumes/BackupDrive/Documents_Backup/
```

Make sure the script is executable:

```bash
chmod +x /usr/local/bin/backup.sh
```

1. Create the LaunchDaemon plist at `/Library/LaunchDaemons/com.example.backup.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.example.backup</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/backup.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>2</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
```

1. Load the daemon:

```bash
sudo launchctl load /Library/LaunchDaemons/com.example.backup.plist
```

This will run your backup script daily at 2 AM and also run it immediately when loaded.

---

## Understanding System Integrity Protection (SIP)

SIP protects system files and processes from being modified—even by root.

### What SIP Blocks

- Changes to `/System`, `/bin`, `/sbin`, `/usr` (except `/usr/local`)
- Debugging or code injection into system processes

### Best Practices

- Never disable SIP except for specific admin tasks.
- Place custom scripts in `/usr/local/bin` or `$HOME/bin`.
- Test scripts on a SIP-enabled Mac.

Check SIP status:

```bash
csrutil status
```

---

## Privacy Preferences Policy Control (PPPC)

PPPC protects access to things like Mail, Messages, and Full Disk Access.

### Common Issues

Scripts may fail to access protected folders without explicit permission.

### How to Handle PPPC

- Grant Full Disk Access in System Settings > Privacy & Security.
- Use MDM to deploy PPPC profiles for multiple machines.
- Reset permissions for testing: `tccutil reset All`

---

## Using the Unified Logging System

macOS uses unified logging instead of simple text log files.

### Write to the Log

```bash
logger "Backup started at $(date)"
```

### View Logs

```bash
log show --predicate 'eventMessage CONTAINS "Backup started"' --info
```

---

## Understanding Sandboxing

Some macOS apps run in a sandbox which limits what they can do.

- Scripts from sandboxed apps may inherit restrictions.
- For packaged scripts, use hardened runtime and notarization.
- Test scripts in Terminal and via `launchd` to verify behavior.

---

## Extra Tips

- Use `plutil` to check plist files.
- Organize LaunchAgents and LaunchDaemons clearly.
- Use `logger` and `log show` for structured logs.
- Keep logs rotated.

---

## Chapter 10 Exercise

1. Create a Launch Agent that backs up a folder daily.
2. Load it with `launchctl` and verify with `launchctl list`.
3. Use `logger` to write log entries.
4. View entries with `log show`.
5. Check SIP status with `csrutil status`.
6. Test reading a protected folder and grant Full Disk Access if needed.

---

## Tips

- Keep privileges minimal.
- Validate all `.plist` files.
- Document permissions your scripts need.
- Test on a fully updated, SIP-enabled macOS system.
