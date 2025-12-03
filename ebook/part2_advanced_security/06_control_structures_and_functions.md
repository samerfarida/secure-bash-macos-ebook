# Chapter 6: Control Structures and Functions

## Learning Objectives

By the end of this chapter, you will be able to:

- Understand and use conditional statements (`if`, `case`)
- Utilize looping constructs (`for`, `while`, `until`) in scripts
- Create and call Bash functions
- Apply control structures and functions to build readable, modular scripts
- Recognize macOS-specific quirks when using these constructs


## Introduction

Control structures and functions are the backbone of any scripting language, enabling dynamic behavior and code reuse. Bash on macOS supports the same powerful constructs as other Unix-based systems, but scripting with security and clarity in mind is key when administering macOS at scale.


## 6.1 Conditional Statements

### if Statements

Conditional execution allows your script to make decisions.

```bash
if [ "$1" = "macOS" ]; then
  echo "Running on macOS"
else
  echo "Not macOS"
fi
```

#### Tip for macOS

Use `sw_vers` or `uname` to programmatically detect the macOS version or platform.

```bash
if [[ "$(uname)" == "Darwin" ]]; then
  echo "Confirmed: macOS system"
fi
```

### elif and else

```bash
if [ -f "/etc/hosts" ]; then
  echo "Hosts file found"
elif [ -f "/private/etc/hosts" ]; then
  echo "Hosts file in legacy location"
else
  echo "Hosts file not found"
fi
```


## 6.2 case Statements

Great for handling multiple possibilities, especially for command-line arguments or user input.

```bash
case "$1" in
  start)
    echo "Starting service..."
    ;;
  stop)
    echo "Stopping service..."
    ;;
  restart)
    echo "Restarting service..."
    ;;
  *)
    echo "Usage: $0 {start|stop|restart}"
    exit 1
    ;;
esac
```


## 6.3 Loops

### for Loops

```bash
for user in $(dscl . list /Users | grep -v '^_'); do
  echo "Checking user: $user"
done
```

This loop iterates over user accounts (excluding system ones) on macOS.

### while Loops

```bash
count=1
while [ "$count" -le 5 ]; do
  echo "Attempt $count"
  ((count++))
done
```

### until Loops

```bash
until [ -f /tmp/signal.done ]; do
  echo "Waiting for signal..."
  sleep 2
done
```


## 6.4 Bash Functions

Functions allow code reuse and better structure.

```bash
greet_user() {
  local user="$1"
  echo "Welcome, $user!"
}

greet_user "Admin"
```

### Function with Return Value

```bash
add_numbers() {
  # Note: In arithmetic context ($(( ))), variables don't need quotes
  local sum=$(( $1 + $2 ))
  echo "$sum"
}

result=$(add_numbers 3 4)
echo "The sum is: $result"
```


## 6.5 Real-World Example: Lock Screen Reminder

This script displays a lock screen reminder if a user forgets to lock their Mac:

```bash
#!/bin/bash

check_idle_time() {
  idle_ms=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF / 1000000; exit}')
  echo "${idle_ms%.*}"
}

alert_user() {
  osascript -e 'display notification "Lock your screen when away!" with title "Security Reminder"'
}

main() {
  idle=$(check_idle_time)
  if [ -n "$idle" ] && [ "$idle" -ge 300 ]; then
    alert_user
  fi
}

main
```


## 6.6 macOS-Specific Notes

- `osascript` allows integration of AppleScript within Bash for user notifications.
- GUI prompts or notifications via scripts require `System Events` permissions under **System Preferences > Privacy & Security > Automation**.
- File paths and user account handling differ from Linux—use `dscl` or `id` carefully.


## Chapter 6 Exercise

1. Write a script that loops through all `.log` files in `/var/log` and prints the filename and number of lines.
2. Create a function called `backup_home` that accepts a username and uses `rsync` to back up their home directory to `/Users/Backups/`.
3. Modify the `Lock Screen Reminder` example to send a message only once every 10 minutes.


## macOS Scripting Tips

- Use `osascript` for GUI integration with Bash scripts, but remember it requires appropriate permissions under System Preferences > Privacy & Security > Automation.
- Functions help organize code; use `local` variables within functions to avoid conflicts with global scope.
- macOS-specific commands like `dscl` can help iterate over user accounts more reliably than parsing `/etc/passwd`.
- Use `sw_vers` or `uname` to programmatically detect macOS version and platform for cross-compatibility checks.
- Consider using `launchctl` to schedule functions and scripts to run automatically on macOS.
