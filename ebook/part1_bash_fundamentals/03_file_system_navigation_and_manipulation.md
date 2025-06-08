# Chapter 3: File System Navigation and Manipulation

## Learning Objectives

By the end of this chapter, you will be able to:

- Navigate the macOS file system using Bash commands
- Understand relative vs absolute paths
- Manage files and directories: create, delete, move, and copy
- Use wildcards and globbing for pattern matching
- Apply file permissions and understand `chmod`, `chown`, and `umask`
- Use macOS-specific tools like `open`, `xattr`, and `mdls`

---

## Introduction: The Shell as Your Filesystem Interface

The command line isn't just a place to run commands — it's a powerful interface to the file system. In this chapter, we'll explore how to traverse, inspect, and modify files and directories using Bash, with a focus on macOS's quirks and features.

---

## 3.1 Paths: Absolute vs Relative

- **Absolute path**: starts from root `/`
  - Example: `/Users/sammy/Documents/report.txt`
- **Relative path**: based on your current directory
  - Example: `../Documents/report.txt`

Check your current directory:
```bash
pwd
```

Move to another directory:
```bash
cd /path/to/folder
```

Return to previous directory:
```bash
cd -
```

---

## 3.2 Listing and Inspecting Files

List directory contents:
```bash
ls -l    # Long format
ls -a    # Include hidden files
ls -lh   # Human-readable sizes
```

Inspect file metadata:
```bash
stat file.txt
```

macOS-specific:
```bash
mdls file.txt      # Show Spotlight metadata
xattr file.txt     # Show extended attributes
```

---

## 3.3 Creating and Removing Files and Directories

Create a file or folder:
```bash
touch notes.txt
mkdir projects
```

Delete files or folders:
```bash
rm file.txt
rm -r projects     # Recursively delete folder
```

Be cautious with `rm -rf`. It will remove without confirmation.

---

## 3.4 Moving, Copying, and Renaming

Move or rename:
```bash
mv old.txt new.txt
mv file.txt ~/Desktop/
```

Copy files and folders:
```bash
cp file.txt backup.txt
cp -r myfolder/ archive/
```

Use `-i` to confirm before overwriting.

---

## 3.5 Wildcards and Globbing

Use wildcards to match file patterns:
- `*` matches any characters
- `?` matches a single character
- `[]` matches a character set

Examples:
```bash
ls *.txt         # All .txt files
ls report?.pdf   # report1.pdf, report2.pdf, etc.
ls data[1-3].csv # data1.csv, data2.csv, data3.csv
```

Combine with commands like `rm`, `cp`, `echo`, etc.

---

## 3.6 Permissions and Ownership

Check permissions:
```bash
ls -l
```

Modify permissions:
```bash
chmod 755 script.sh   # rwxr-xr-x
chmod +x script.sh    # Add execute bit
```

Change ownership (admin required):
```bash
sudo chown sammy file.txt
```

Default permission mask:
```bash
umask
```

---

## 3.7 macOS-Specific File Tips

- Use `open .` to launch Finder
- `open file.pdf` opens with default app
- Use `mdls`, `xattr`, `GetFileInfo` for metadata
- Spotlight indexing can interfere with scripting; exclude folders via:

```bash
sudo mdutil -i off /path/to/dir
```

---

## Chapter 3 Exercise

Write a script named `organize_downloads.sh` that:
- Scans your `~/Downloads` directory
- Moves `.zip` files to `~/Downloads/zips`
- Moves `.dmg` files to `~/Downloads/installers`
- Creates folders if they don’t exist

Hint:
```bash
#!/bin/bash
mkdir -p ~/Downloads/zips ~/Downloads/installers
for file in ~/Downloads/*; do
  case "$file" in
    *.zip) mv "$file" ~/Downloads/zips/ ;;
    *.dmg) mv "$file" ~/Downloads/installers/ ;;
  esac
done
echo "Downloads organized."
```

---

## macOS Scripting Tips

- `open -R filename` reveals a file in Finder
- Use `tmutil` to interact with Time Machine in scripts
- Use `diskutil list` to inspect drives and volumes
- Use `find` or `mdfind` for search with greater flexibility

---
