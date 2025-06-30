# Chapter 11: Security Practices in Bash

## Learning Objectives

By the end of this chapter, you will be able to:

- Implement safe input handling to minimize security risks
- Avoid common pitfalls like code injection and command substitution attacks
- Use sandboxing techniques and the principle of least privilege
- Protect sensitive data like credentials and API keys
- Securely manage file permissions, temporary files, and logs
- Apply macOS-specific security recommendations for Bash scripts

## Introduction: Why Security Matters in Bash

Bash is powerful — but with great power comes great responsibility. Scripts often run with elevated privileges, handle sensitive data, or automate system-level tasks. A small oversight can lead to significant vulnerabilities. This chapter teaches practical strategies to write safer Bash scripts on macOS.

## Safe Script Settings

Start your secure scripts with `set -euo pipefail`:

- `-e`: Exit immediately if any command fails
- `-u`: Treat unset variables as an error
- `-o pipefail`: Prevents errors in pipelines from being masked

This ensures your script stops on unexpected issues.

## Safe Input Handling

User input is one of the most common attack vectors. Malicious input can lead to command injection, file overwrite, or privilege escalation.

**Best Practices:**

- **Always quote variables** to prevent word splitting and glob expansion.

```bash
# Unsafe
rm -rf $DIR

# Safe
rm -rf "$DIR"
```

- Use `read -r` to prevent backslash escapes.

```bash
read -r USER_INPUT
```

- Validate and sanitize input. Use regex or `case` statements.

```bash
# Example: Validate a username
if [[ "$USERNAME" =~ ^[a-zA-Z0-9_-]{3,16}$ ]]; then
  echo "Valid username"
else
  echo "Invalid username"
  exit 1
fi
```

Note: You can adjust your validation regex to be stricter if needed — for example, requiring usernames to start and end with an alphanumeric character.

- Avoid using `eval` whenever possible. It’s dangerous!

## Avoiding Code Injection

Command injection happens when untrusted data is executed as part of a command.

**Guidelines:**

- Don’t `eval` or `exec` user-supplied input.
- Use `--` to mark the end of options:

```bash
rm -- "$FILENAME"
```

- Prefer built-in tools that can handle edge cases safely (e.g., `xargs -0` with `find -print0`).

## Secure Storage: Avoid Plaintext Credentials

Never store passwords or API keys directly in your scripts. Instead:

- Use the macOS **Keychain**:

```bash
security find-generic-password -a "myaccount" -s "myservice" -w
```

- Use environment variables and `.env` files with secure permissions (`chmod 600`).
- For deployment, use secure vaults or configuration management tools.

## Secure File Permissions and Ownership

Ensure your scripts are not world-writable or executable by unauthorized users.

```bash
# Recommended permissions for sensitive scripts
chmod 700 myscript.sh

# Recommended permissions for sensitive data files
chmod 600 secrets.env
```

## Script Sandboxing and Least Privilege

Minimize the impact if your script is exploited:

- Run scripts as a dedicated user with limited privileges.
- Use `sudo` only for commands that absolutely require it — and never run an entire script with `sudo` by default.
- Use macOS sandboxing where appropriate, like `sandbox-exec`.

## Managing Temporary Files Securely

Temporary files are often a target for attackers.

- Use `mktemp` to create unique temp files:

```bash
TEMP_FILE=$(mktemp) || exit 1
echo "Sensitive data" > "$TEMP_FILE"
# Do work
rm -f "$TEMP_FILE"
```

- Store temp files in directories with restricted permissions.

## Secure Logging Practices

Logging is essential — but don’t leak secrets:

- Avoid logging passwords, tokens, or API keys.
- Mask or truncate sensitive output if necessary.
- Set appropriate permissions on log files.

Consider using a helper function for logging with timestamps to improve traceability:

```bash
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}
```

```bash
# Example: Secure log file
exec > >(tee -a secure_script.log)
chmod 600 secure_script.log
```

## Handling Signals and Cleanup

Use `trap` to clean up securely on exit or interruption:

```bash
TEMP_FILE=$(mktemp) || exit 1

cleanup() {
  rm -f "$TEMP_FILE"
}

trap cleanup EXIT INT TERM
```

This ensures sensitive temp files don’t persist if your script is killed unexpectedly.

## Example: A Secure Wrapper Script

Below is a simple example that ties all these practices together.

```bash
#!/bin/bash
set -euo pipefail

#
# Helper function to log messages with timestamp
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

# Create secure log file
LOG_FILE="secure_script.log"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

log "Starting secure script..."

#
# Safe input: Username must start/end with alphanumeric, can contain dot, underscore, hyphen in between
read -rp "Enter your username: " USERNAME
if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9._-]{1,14}[a-zA-Z0-9])?$ ]]; then
  log "Invalid username!"
  exit 1
fi
log "Username '$USERNAME' validated successfully."

#
# Retrieve password securely from Keychain
log "Attempting to retrieve password from Keychain for service 'MyService'."
PASSWORD=$(security find-generic-password -a "$USERNAME" -s "MyService" -w 2>/dev/null) || {
  log "Failed to get password from Keychain."
  exit 1
}
log "Password retrieved successfully."

#
# Secure temp file creation
TEMP_FILE=$(mktemp) || exit 1
log "Created secure temp file at $TEMP_FILE."

#
# Trap to clean up temp file on exit, interrupt, or termination
cleanup() {
  if [[ -n "${TEMP_FILE:-}" && -f "$TEMP_FILE" ]]; then
    log "Cleaning up temp file: $TEMP_FILE"
    rm -f "$TEMP_FILE"
    log "Temp file removed."
  fi
}
trap cleanup EXIT INT TERM

#
# Do some secure work
log "Working securely... writing sensitive temp data."
echo "Sensitive temp data" > "$TEMP_FILE"

#
# Simulate more secure actions
log "Hello, $USERNAME! Your secure work is complete."

#
# Done
log "Script completed successfully."
```

## macOS-Specific Tips

- Leverage **Keychain**, **System Integrity Protection (SIP)**, and **Gatekeeper** when distributing scripts.
- Consider using **launchd** to run privileged tasks securely.
- Always test scripts in a non-production environment with SIP enabled.

## Chapter 11 Exercise

### Secure Script Challenge

Write a Bash script that:

1. Takes a filename as input and safely deletes it if it exists and the user confirms.
2. Uses `mktemp` to create a secure temp file for logging actions.
3. Traps signals and ensures all temp files are cleaned up.
4. Retrieves an API key securely (simulate with an environment variable).
5. Sets file permissions correctly on all outputs.

## Tips

- Always review your scripts for injection risks.
- Keep sensitive data out of your version control system.
- Apply the principle of least privilege — every time.
