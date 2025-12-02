# Chapter 9: Environment Variables and Configuration Management

## Learning Objectives

By the end of this chapter, you will be able to:

1. Understand the difference between user and system environment variables on macOS.
2. Configure and manage `.bash_profile` and `.bashrc`, including macOS-specific considerations.
3. Use Launch Agents and Daemons to manage environment variables and scripts.


## Introduction: Why Environment Configuration Matters

Environment variables influence how Bash scripts run and interact with macOS. They define system-wide paths, user preferences, and credentials. Misconfigurations can lead to unexpected behavior, security issues, or broken automation. This chapter shows you how to manage these settings correctly.


## 9.1 User vs System Environment

- **User Environment Variables**: Defined in your user’s shell config files like `.bash_profile` or `.bashrc`. They apply only when you run a shell as your user.
- **System Environment Variables**: Defined in system files like `/etc/profile` or `/etc/paths`. They affect all users and sometimes system daemons.

Check your current environment:

```bash
env
```

Or print a single variable:

```bash
echo "$PATH"
echo "$HOME"
```

### Modifying System Variables Safely

- On macOS, modify `/etc/paths` to add system-wide directories.
- For sensitive scripts, prefer user-level variables unless you need system scope.


## 9.2 .bash\_profile, .bashrc, and macOS Quirks

Traditionally:

- `.bash_profile` runs for login shells.
- `.bashrc` runs for interactive non-login shells.

macOS Terminal launches login shells by default, so your `.bash_profile` is often the right place to export variables.

Example `.bash_profile`:

```bash
export PATH="$HOME/bin:$PATH"
export EDITOR="nano"
```

To ensure `.bashrc` runs, source it in `.bash_profile`:

```bash
if [ -f "$HOME/.bashrc" ]; then
  source "$HOME/.bashrc"
fi
```

**Tip:** Always test changes with a new Terminal window.


## 9.3 Managing Config with Launch Agents and Daemons

macOS uses `launchd` to manage user and system processes. Sometimes you need to ensure environment variables are available to GUI apps or background tasks.

- **Launch Agents** run as a user.
- **Launch Daemons** run as root.

Example: Create a user Launch Agent to set a variable and run a script.

1. Create a `plist` file in `~/Library/LaunchAgents/`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.example.setenv</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>export MY_VAR=hello && echo $MY_VAR > /tmp/my_var.txt</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
```

1. Load the agent:

```bash
launchctl load ~/Library/LaunchAgents/com.example.setenv.plist
```

1. Verify the variable was set:

```bash
cat /tmp/my_var.txt
```

**Tip:** For system-wide daemons, use `/Library/LaunchDaemons/` and ensure permissions are correct.


## Chapter 9 Exercise

**Manage your environment:**

1. Add a custom `PATH` or variable to your `.bash_profile`.
2. Test with `env` and `echo`.
3. Create a Launch Agent that runs a small script and sets a variable.
4. Inspect the logs with `log show` or `Console`.

Example shell snippet:

```bash
export BACKUP_DIR="$HOME/backups"
mkdir -p "$BACKUP_DIR"
echo "Backups will go to: $BACKUP_DIR"
```


## macOS Scripting Tips

- Always back up `.bash_profile` and `.bashrc` before changes.
- Use descriptive variable names.
- Test with a new shell session to confirm behavior.
- Use `launchctl list` to verify active agents and daemons.
