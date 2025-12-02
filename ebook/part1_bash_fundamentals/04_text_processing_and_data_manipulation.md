# Chapter 4: Text Processing and Data Manipulation

## Learning Objectives

By the end of this chapter, you will be able to:

- Understand standard input/output (stdin/stdout/stderr)
- Redirect input and output to files
- Use pipes to chain commands together
- Filter and transform text using `grep`, `awk`, `sed`, `cut`, and `tr`
- Work with structured data (CSV, JSON, plist) in Bash
- Leverage macOS tools like `plutil` and `jq`


## Introduction: Bash as a Data Processing Tool

While many think of Bash as a command runner, its real power lies in data manipulation—especially text. Logs, configuration files, CSVs, and JSON responses can all be processed with Bash's built-in capabilities and powerful command-line utilities.

As a macOS administrator or security engineer, you'll frequently need to parse system logs, extract data from configuration files, transform CSV exports from inventory tools, and process JSON responses from APIs. This chapter teaches you the essential text processing tools—grep, awk, sed, cut, and tr—along with macOS-specific utilities like plutil, jq, and pbcopy/pbpaste that make data manipulation faster and more reliable.


## 4.1 Standard Input, Output, and Error

Every Bash command uses file descriptors:

- `0`: standard input (stdin)
- `1`: standard output (stdout)
- `2`: standard error (stderr)

Examples:

```bash
command > file.txt       # stdout to file
command >> file.txt      # append stdout to file
command 2> error.log     # stderr to file
command &> all.log       # stdout and stderr to file
```

Read from a file as input:

```bash
command < input.txt
```


## 4.2 Pipes and Command Chaining

Pipes allow the output of one command to feed into the next:

```bash
# macOS: Use log show instead of dmesg (Linux command)
log show --predicate 'eventMessage contains "USB"' --last 1h | head -20
ps aux | sort -k 3 -nr | head -5
```

Chain commands:

```bash
mkdir logs && cd logs || echo "Failed to create directory"
```


## 4.3 Using grep to Search Text

```bash
grep 'pattern' file.txt
```

Flags:

- `-i`: ignore case
- `-r`: recursive
- `-n`: show line numbers
- `-v`: invert match

Example:

```bash
grep -i 'error' /var/log/system.log
```


## 4.4 Using cut, awk, and tr

### cut: extract columns

```bash
# Note: /etc/passwd exists on macOS but uses OpenDirectory; for user accounts, use dscl
cut -d ':' -f1 /etc/passwd
# macOS alternative: dscl . list /Users | grep -v '^_'
```

### awk: pattern scanning and reporting

```bash
# Note: /etc/passwd on macOS contains system accounts; user accounts are in OpenDirectory
awk -F ':' '{ print $1 " -> " $3 }' /etc/passwd
```

### tr: character translation

```bash
echo "hello" | tr 'a-z' 'A-Z'
```


## 4.5 Using sed to Edit Streams

Sed performs find and replace on streams:

```bash
sed 's/old/new/g' file.txt
```

To delete lines or use regex:

```bash
sed '/DEBUG/d' logfile.txt
```

In-place editing:

```bash
sed -i '' 's/localhost/127.0.0.1/' hosts.txt   # macOS version
```


## 4.6 Reading and Writing CSV Files

While Bash doesn't have built-in CSV support, you can:

```bash
cut -d ',' -f1,2 users.csv
awk -F ',' '{ print $2 }' users.csv
```

Beware of quoted fields and commas in text. For more complex CSVs, use `csvkit` or `python -c` one-liners.


## 4.7 Working with JSON and jq

Use `jq` for parsing JSON:

```bash
cat config.json | jq '.settings.theme'
```

To format and filter:

```bash
curl -s https://api.github.com/repos/pandoc/pandoc | jq '.name, .stargazers_count'
```

Install with:

```bash
brew install jq
```


## 4.8 Working with Property Lists (plist)

macOS stores many settings in `.plist` files.
Use `plutil` to inspect or convert:

```bash
plutil -p settings.plist
plutil -convert xml1 settings.plist
```

Use `defaults` to read/write user preferences:

```bash
defaults read com.apple.finder
```


## Chapter 4 Exercise

Write a script `logfilter.sh` that:

- Accepts a filename as an argument
- Filters lines containing "ERROR"
- Outputs results to a new file with `.error.log` suffix

Hint:

```bash
#!/bin/bash
input="$1"
output="${input%.log}.error.log"
grep 'ERROR' "$input" > "$output"
echo "Filtered log written to $output"
```


## macOS Scripting Tips

- Use `pbpaste | grep` to search clipboard content
- Use `syslog` or `log show` to parse macOS logs
- Combine `osascript` with `grep` for smart notifications
- Use `mdfind` to search file metadata
