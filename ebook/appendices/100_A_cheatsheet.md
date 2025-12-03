# Appendix A: Bash Scripting Cheat Sheet

A quick-reference guide for writing and debugging Bash scripts on macOS. This cheat sheet focuses on practical patterns used in enterprise macOS management and security automation.


## A.1 Variables

```bash
name="Sammy"
echo "Hello, $name"
readonly PI=3.14       # constant
unset name             # delete variable
```


## A.2 Conditionals

```bash
if [ "$var" -eq 1 ]; then
  echo "Equal"
elif [ "$var" -gt 1 ]; then
  echo "Greater"
else
  echo "Less or unset"
fi
```

### A.2.1 Common Test Operators

| Test         | Description           |
|--------------|------------------------|
| `-e FILE`    | File exists            |
| `-f FILE`    | File is a regular file |
| `-d DIR`     | Directory exists       |
| `-z STR`     | String is empty        |
| `-n STR`     | String is not empty    |
| `"$a" == "$b"` | Strings are equal     |
| `"$a" != "$b"` | Strings not equal     |


## A.3 Loops

```bash
for file in *.txt; do
  echo "$file"
done

while read line; do
  echo "$line"
done < file.txt

until [ "$n" -ge 5 ]; do
  echo "$n"
  ((n++))
done
```


## A.4 Functions

```bash
greet() {
  echo "Hello, $1"
}
greet "macOS"
```


## A.5 Arrays

```bash
fruits=("apple" "banana" "cherry")
echo "${fruits[1]}"     # banana
echo "${#fruits[@]}"    # count
```


## A.6 String Manipulation

```bash
str="macOS"
echo "${str,,}"         # lowercase
echo "${str^^}"         # uppercase
echo "${str:1:3}"       # substring
echo "${str/m/Mac}"     # replace
```


## A.7 File Descriptors and Redirection

```bash
command > out.txt        # stdout
command >> out.txt       # append
command 2> err.txt       # stderr
command &> all.txt       # both stdout + stderr
```


## A.8 Command Substitution

```bash
today=$(date)
echo "Today is $today"
```


## A.9 Useful Shortcuts

| Shortcut     | Meaning                         |
|--------------|----------------------------------|
| `Ctrl + A`   | Beginning of line                |
| `Ctrl + E`   | End of line                      |
| `Ctrl + U`   | Delete to beginning              |
| `Ctrl + K`   | Delete to end                    |
| `Ctrl + R`   | Reverse search in history        |
| `!!`         | Repeat last command              |
| `!n`         | Run command `n` from history     |


## A.10 Script Template

```bash
#!/bin/bash

set -euo pipefail

echo "Script started"

# Your logic here

echo "Done"
```


## A.11 File Permission Basics

```bash
chmod +x script.sh      # make executable
chmod 644 file.txt      # rw-r--r--
chown user:staff file   # change owner
```


## A.12 macOS Specific Tips

```bash
open -a "TextEdit" file.txt        # open file with GUI app
osascript -e 'display dialog "Hello!"'  # show dialog
defaults read com.apple.finder     # read plist settings
system_profiler SPHardwareDataType # hardware info
```


## A.13 Debugging

```bash
bash -x script.sh       # trace execution
set -x                  # enable tracing
trap 'echo "Failed at $LINENO"' ERR
```


## A.14 Safe Scripting Practices

- Use `set -euo pipefail` for strict error handling
- Quote variables: `"$var"` to prevent word splitting
- Validate inputs before use
- Avoid parsing `ls`, use `find` or `stat`
- Check return codes: `if ! command; then echo "Failed"; fi`
- Use absolute paths in scripts: `/usr/local/bin/tool` vs `tool`

## A.15 Error Handling Patterns

```bash
# Exit on error with cleanup
set -e
trap 'cleanup_function' EXIT

# Log errors
log_error() {
    echo "[ERROR] $(date): $*" >&2
}

# Check command success
if ! command; then
    log_error "Command failed"
    exit 1
fi

# Retry with backoff
retry() {
    local max_attempts=3
    local delay=2
    for ((i=1; i<=max_attempts; i++)); do
        if command; then
            return 0
        fi
        sleep $delay
        delay=$((delay * 2))
    done
    return 1
}
```

## A.16 Logging and Output

```bash
# Log to file with timestamp
log_file="/var/log/script.log"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$log_file"
}

# Quiet mode support
if [[ "${QUIET:-false}" != "true" ]]; then
    echo "Verbose output enabled"
fi

# Redirect output conditionally
if [[ -n "${LOG_DIR:-}" ]]; then
    exec > >(tee -a "${LOG_DIR}/script.log")
    exec 2>&1
fi
```

## A.17 Enterprise Script Patterns

### A.17.1 Check Root Privileges

```bash
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" >&2
    exit 1
fi
```

### A.17.2 Check macOS Version

```bash
os_version=$(sw_vers -productVersion | cut -d. -f1,2)
if [[ $(echo "$os_version >= 14.0" | bc -l) -eq 0 ]]; then
    echo "macOS 14.0+ required"
    exit 1
fi
```

### A.17.3 MDM Profile Check

```bash
check_mdm_profile() {
    local profile_identifier="$1"
    if profiles -P | grep -q "$profile_identifier"; then
        return 0
    else
        return 1
    fi
}
```

### A.17.4 Process Check and Kill

```bash
# Check if process is running
if pgrep -x "ApplicationName" > /dev/null; then
    echo "Application is running"
    pkill -x "ApplicationName"
fi
```

### A.17.5 JSON Parsing (with jq)

```bash
# Parse JSON from API
response=$(curl -s "https://api.example.com/data")
value=$(echo "$response" | jq -r '.key.subkey')

# Create JSON
json_data=$(jq -n \
    --arg key "value" \
    '{key: $key}')
```

### A.17.6 Plist Operations

```bash
# Read plist value
defaults read /path/to/file.plist Key

# Write plist value
defaults write /path/to/file.plist Key -string "value"

# Delete plist key
defaults delete /path/to/file.plist Key

# Using PlistBuddy
/usr/libexec/PlistBuddy -c "Print :Key" file.plist
/usr/libexec/PlistBuddy -c "Set :Key value" file.plist
```

## A.18 Resources

- `man bash` — Bash manual
- `help` — Bash built-ins help
- `man -k something` — Search man pages
- `brew install bash` — Install latest Bash (via Homebrew)
- See Appendix C for additional tools and resources
