# Chapter 8: Error Handling and Debugging

## Learning Objectives

By the end of this chapter, you will be able to:

1. Understand how Bash uses exit codes to communicate success and failure.
2. Use the `trap` command to catch and handle errors and signals in your scripts.
3. Debug Bash scripts using `set -x` and `bash -x`.
4. Implement logging and output redirection for troubleshooting.
5. Apply best practices for debugging on macOS.

---

## Introduction: Why Error Handling and Debugging Matter

Even the best Bash scripts fail at some point. On macOS, where scripts often automate system configurations, backups, or security checks, robust error handling is crucial. Poor error handling can lead to partial changes, corrupted files, or security misconfigurations. This chapter shows you how to detect and handle problems gracefully, log what happened, and troubleshoot effectively.

---

## Understanding Exit Codes

Every command in Bash returns an exit code. By convention:

- `0` means success.
- Any non-zero value indicates an error.

You can access the last command’s exit code with `$?`.

```bash
#!/bin/bash

echo "This will succeed"
ls /tmp

echo "This will fail"
ls /nonexistent

echo "Exit code of last command: $?"
```

### Using Exit Codes in Scripts

You should check exit codes to make decisions.

```bash
#!/bin/bash

ping -c 1 8.8.8.8 >/dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "Network unreachable. Exiting."
  exit 1
else
  echo "Network is reachable."
fi
```

## Using `trap` to Handle Errors and Signals

`trap` allows you to run cleanup code when a script exits, or when it receives a signal like SIGINT (Ctrl+C).

### Example: Clean up a temp file on exit

```bash
#!/bin/bash

TEMP_FILE="/tmp/my_tempfile.txt"

trap "echo 'Cleaning up'; rm -f $TEMP_FILE; exit" EXIT

echo "Doing work..."
touch $TEMP_FILE

sleep 5
echo "Done."
```

When the script exits — normally or via Ctrl+C — `trap` ensures the temp file is removed.

### Common `trap` Use Cases

- Remove sensitive temporary files.
- Stop services you started.
- Unlock files or resources.

---

## Debugging with `set -x` and `bash -x`

Bash’s `-x` option shows each command and its arguments as they run.

### Temporary Debugging

Insert `set -x` to start debugging, and `set +x` to stop:

```bash
#!/bin/bash

echo "Starting script"

set -x

VAR="Hello"
echo "$VAR World"

set +x

echo "Script done"
```

### Debugging the Entire Script

Run the script with `bash -x`:

```bash
bash -x myscript.sh
```

On macOS, this is helpful when working with `launchd` jobs — you can test scripts interactively before deploying them.

---

## Logging and Output Redirection

Capturing output and errors helps you diagnose issues after the fact.

### Redirect stdout and stderr to a log file

```bash
#!/bin/bash

LOGFILE="/tmp/myscript.log"

echo "Starting script" > "$LOGFILE" 2>&1

{
  echo "This is stdout"
  ls /nonexistent  # This will cause an error
} >> "$LOGFILE" 2>&1

echo "Script done" >> "$LOGFILE"
```

### Best Practices

- Always redirect both stdout and stderr for full context.
- Rotate logs on macOS if you run scripts regularly (use `newsyslog` or log rotation tools).
- Include timestamps for each log entry with `date`.

---

## macOS-Specific Tips

- When testing scripts that will run as `launchd` jobs, log output to `/var/log/` or `~/Library/Logs/`.
- For privileged scripts, remember `sudo` can suppress environment variables; test exit codes carefully.
- Use `/usr/bin/logger` to write messages to the macOS unified log:

```bash
logger "My script started"
```

You can view these with `log show` or the Console app.

---

## Chapter 8 Exercise

### Add robust error handling and debugging to an existing script

1. Take a script you wrote in a previous chapter.
2. Add:
   - Exit code checks after each critical command.
   - A `trap` to clean up on `EXIT`.
   - `set -x` or run with `bash -x` to debug.
   - Redirect output to a log file with both stdout and stderr.
   - (Optional) Log key events to the macOS system log using `logger`.

Example snippet:

```bash
#!/bin/bash

trap "echo 'Caught EXIT'; exit" EXIT

set -x

echo "Doing work"
mkdir /restricted  # Should fail without sudo
echo "Exit code: $?"

set +x
```

---

## Tips

- Use clear, descriptive log messages.
- Always test your `trap` handlers to avoid infinite loops.
- Clean up sensitive files or secrets when an error occurs.
- For persistent issues, break the script into small parts and test each with `bash -x`.
