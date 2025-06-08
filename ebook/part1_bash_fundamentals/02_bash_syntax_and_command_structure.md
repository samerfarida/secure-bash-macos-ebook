# Chapter 2: Bash Syntax and Command Structure

### Learning Objectives

By the end of this chapter, you will be able to:

- Understand how Bash parses and executes commands
- Use variables, arguments, and quoting effectively
- Structure your scripts with control flow: `if`, `case`, `for`, `while`
- Use comments, functions, and exit codes properly
- Begin writing scripts that interact with user input

---

### Introduction: The Building Blocks of Bash

Before you can write powerful scripts, you need to understand how Bash interprets your input. This chapter will give you a clear, practical foundation in Bash syntax and structure—knowledge that applies equally whether you're writing a 3-line script or a full automation tool.

---

### 2.1 Commands and Arguments

Bash commands follow a simple structure:

```bash
command [options] [arguments]
```

For example:

```bash
ls -la /Users/sammy/Desktop
```

- `ls` is the command
- `-la` are the options (flags)
- `/Users/sammy/Desktop` is the argument

You can chain commands using `&&`, `||`, and `;`:

```bash
mkdir newfolder && cd newfolder
```

---

### 2.2 Variables

Bash variables are declared without a `let` or `var` keyword:

```bash
name="Sammy"
echo "Hello, $name!"
```

Remember:
- No spaces around `=`
- Use `"$var"` to preserve whitespace
- Enclose in braces for safety: `${name}`

You can also use environment variables:

```bash
echo "$HOME"
```

---

### 2.3 Quoting: Single, Double, and Escaping

- `'single quotes'` prevent expansion.
- `"double quotes"` allow variable and command substitution.
- `\` escapes the next character.

Examples:

```bash
echo 'My name is $USER'      # Prints literally
echo "My name is $USER"      # Expands $USER
```

---

### 2.4 Conditionals: `if`, `elif`, `else`

Basic structure:

```bash
if [ condition ]; then
  commands
elif [ other_condition ]; then
  other_commands
else
  fallback_commands
fi
```

Example:

```bash
if [ -f /etc/hosts ]; then
  echo "Hosts file exists."
else
  echo "Missing hosts file."
fi
```

Use `[[ ... ]]` for advanced conditions (e.g., regex).

---

### 2.5 Loops: `for`, `while`, and `until`

#### `for` loop:

```bash
for file in *.txt; do
  echo "Processing $file"
done
```

#### `while` loop:

```bash
count=1
while [ $count -le 5 ]; do
  echo "Count: $count"
  ((count++))
done
```

#### `until` loop:

```bash
until [ "$ready" = "yes" ]; do
  echo "Waiting..."
  sleep 1
  ready="yes"
done
```

---

### 2.6 Functions and Return Values

Functions allow code reuse and structure:

```bash
say_hello() {
  echo "Hello, $1!"
}

say_hello "Sammy"
```

Use `return` to provide exit codes (0 for success):

```bash
check_dir() {
  [ -d "$1" ] && return 0 || return 1
}

if check_dir "/tmp"; then
  echo "Directory exists."
fi
```

---

### 2.7 Script Exit Codes

Every Bash command returns an exit code (`$?`):
- `0` = success
- `1+` = failure or different exit state

You can use `exit` to set a code:

```bash
exit 0   # success
exit 1   # general error
```

---

### 2.8 Reading User Input

```bash
echo -n "Enter your name: "
read username
echo "Hi, $username."
```

Flags:
- `-p` prints prompt
- `-s` hides input (e.g., passwords)
- `-n 1` reads a single character

Example:

```bash
read -p "Proceed (y/n)? " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  echo "Continuing..."
else
  echo "Aborted."
fi
```

---

### Chapter 2 Exercise

Write a script called `backup.sh` that:

- Asks for a folder to back up
- Checks if it exists
- Creates a timestamped `.tar.gz` archive
- Outputs success or failure

Hint:

```bash
#!/bin/bash
read -p "Folder to back up: " folder
if [ -d "$folder" ]; then
  tar -czf "backup_$(basename $folder)_$(date +%F).tar.gz" "$folder"
  echo "Backup complete."
else
  echo "Folder not found."
  exit 1
fi
```

---

### macOS Scripting Tips

- Use `open .` or `open "$folder"` to open Finder to a directory.
- You can pipe input to GUI dialogs with `osascript`.
- Use `read -s` to securely accept passwords from users.
- Use `touch`, `say`, and `afplay` for playful script output on macOS.

---
