# Chapter 07: File Management and Permissions

## Learning Objectives

By the end of this chapter, you will be able to:

- Use Bash commands to manage files and directories securely on macOS
- Understand Unix file permissions and how they apply to macOS
- Change ownership and permissions using `chmod`, `chown`, and `chflags`
- Use `find`, `xargs`, and `stat` to audit file access and attributes
- Apply macOS-specific practices for protecting sensitive files

---

## Introduction

File and directory permissions are a fundamental security layer in Unix-based systems, including macOS. Whether you’re writing scripts to automate backups, rotate logs, or deploy files, managing access rights properly is critical to system security and user privacy.

In this chapter, we'll explore the key tools and techniques to manage file access securely from a Bash script on macOS.

---

## Creating and Managing Files

### Basic File Commands

```bash
touch report.txt            # Create a new file
mkdir ~/SecureScripts       # Create a new directory
cp report.txt archive/      # Copy file to archive
mv report.txt report.old    # Rename or move file
rm report.old               # Delete file
```

Use `rm -i` or `rm -I` interactively to avoid accidental deletions:

```bash
rm -i ~/Desktop/*.sh
```

---

## Understanding File Permissions

Permissions define who can read, write, or execute a file.

### Symbolic Representation

```bash
-rwxr-xr--  1 samer  staff  4096 Jun 22 12:00 script.sh
```

- `rwx`: Owner can read, write, execute
- `r-x`: Group can read, execute
- `r--`: Others can only read

### Octal Notation

```bash
chmod 755 script.sh   # rwxr-xr-x
chmod 700 secrets.txt # rwx------
```

---

## Changing Ownership and Permissions

### `chmod` – Change Permissions

```bash
chmod u+x backup.sh      # Add execute to user
chmod go-w config.conf   # Remove write from group and others
```

### `chown` – Change Owner

```bash
sudo chown root:wheel /usr/local/bin/tool
```

### `chflags` – macOS Flagging System

macOS supports file flags like `uchg` (user immutable):

```bash
sudo chflags uchg important.doc
sudo chflags nouchg important.doc
```

Use `ls -lO` to view file flags.

---

## File Attributes and Metadata

macOS uses extended attributes and metadata (`com.apple.*` keys).

List attributes:

```bash
xattr file.txt
xattr -l file.txt
```

Remove all attributes:

```bash
xattr -c file.txt
```

---

## Finding and Auditing Files

### Using `find`

```bash
# Find all .sh files in the home directory
find ~ -name "*.sh"

# Find files modified in the last 7 days
find /var/log -type f -mtime -7

# Find files not accessed in 30 days and remove
find ~/Downloads -atime +30 -delete
```

### Combine with `xargs`

```bash
find . -type f -name "*.log" | xargs grep "ERROR"
```

---

## Real-World Example: Secure Log Archiving Script

```bash
#!/bin/bash

# Define variables
src_dir="/var/log"
dest_dir="/Users/admin/LogArchive/$(date +%F)"
mkdir -p "$dest_dir"

# Archive files
find "$src_dir" -type f -name "*.log" -mtime +7 -exec mv {} "$dest_dir" \;

# Restrict permissions
chmod -R 700 "$dest_dir"
chown -R admin:staff "$dest_dir"
```

---

## macOS-Specific Notes

- System files are protected by **System Integrity Protection (SIP)** and may be immutable even for `sudo`.
- Always use `sudo` cautiously in automation scripts—privilege escalation should be justified.
- `/System` and `/usr/bin` are mostly read-only in recent macOS versions.
- User-owned writable directories: `/Users`, `/usr/local`, `/opt`.

---

## Exercises

1. Write a script to find and back up all `.conf` files in `/etc` to a folder in your home directory.
2. Create a script that checks permissions of all `.sh` files in a directory and warns if any are globally writable.
3. Write a function that takes a filename and removes all extended attributes securely.