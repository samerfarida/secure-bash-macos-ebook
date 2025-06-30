# Appendix A: Bash Scripting Cheat Sheet

A quick-reference guide for writing and debugging Bash scripts on macOS.

---

## Variables

```bash
name="Sammy"
echo "Hello, $name"
readonly PI=3.14       # constant
unset name             # delete variable
```

---

## Conditionals

```bash
if [ "$var" -eq 1 ]; then
  echo "Equal"
elif [ "$var" -gt 1 ]; then
  echo "Greater"
else
  echo "Less or unset"
fi
```

### Common Test Operators

| Test         | Description           |
|--------------|------------------------|
| `-e FILE`    | File exists            |
| `-f FILE`    | File is a regular file |
| `-d DIR`     | Directory exists       |
| `-z STR`     | String is empty        |
| `-n STR`     | String is not empty    |
| `"$a" == "$b"` | Strings are equal     |
| `"$a" != "$b"` | Strings not equal     |

---

## Loops

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

---

## Functions

```bash
greet() {
  echo "Hello, $1"
}
greet "macOS"
```

---

## Arrays

```bash
fruits=("apple" "banana" "cherry")
echo "${fruits[1]}"     # banana
echo "${#fruits[@]}"    # count
```

---

## String Manipulation

```bash
str="macOS"
echo "${str,,}"         # lowercase
echo "${str^^}"         # uppercase
echo "${str:1:3}"       # substring
echo "${str/m/Mac}"     # replace
```

---

## File Descriptors and Redirection

```bash
command > out.txt        # stdout
command >> out.txt       # append
command 2> err.txt       # stderr
command &> all.txt       # both stdout + stderr
```

---

## Command Substitution

```bash
today=$(date)
echo "Today is $today"
```

---

## Useful Shortcuts

| Shortcut     | Meaning                         |
|--------------|----------------------------------|
| `Ctrl + A`   | Beginning of line                |
| `Ctrl + E`   | End of line                      |
| `Ctrl + U`   | Delete to beginning              |
| `Ctrl + K`   | Delete to end                    |
| `Ctrl + R`   | Reverse search in history        |
| `!!`         | Repeat last command              |
| `!n`         | Run command `n` from history     |

---

## Script Template

```bash
#!/bin/bash

set -euo pipefail
IFS=$''

echo "Script started"

# Your logic here

echo "Done"
```

---

## File Permission Basics

```bash
chmod +x script.sh      # make executable
chmod 644 file.txt      # rw-r--r--
chown user:staff file   # change owner
```

---

## macOS Specific Tips

```bash
open -a "TextEdit" file.txt        # open file with GUI app
osascript -e 'display dialog "Hello!"'  # show dialog
defaults read com.apple.finder     # read plist settings
system_profiler SPHardwareDataType # hardware info
```

---

## Debugging

```bash
bash -x script.sh       # trace execution
set -x                  # enable tracing
trap 'echo "Failed at $LINENO"' ERR
```

---

## Safe Scripting Practices

* Use `set -euo pipefail`
* Quote variables: `"$var"`
* Validate inputs before use
* Avoid parsing `ls`, use `find` or `stat`

---

## Resources

* `man bash` — Bash manual
* `help` — Bash built-ins help
* `man -k something` — Search man pages
* `brew install bash` — Install latest Bash (via Homebrew)

---
