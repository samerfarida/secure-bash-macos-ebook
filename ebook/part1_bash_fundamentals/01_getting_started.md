# Chapter 1: Getting Started with Bash on macOS

## Learning Objectives

By the end of this chapter, you will be able to:

- Understand what Bash is and how it fits into the macOS terminal environment
- Identify differences between Bash and Zsh on macOS
- Configure your terminal environment to use Bash effectively
- Write and run your first Bash script on macOS
- Understand basic shell concepts: shell sessions, prompts, commands, and scripts
- Recognize security best practices for running scripts
- Troubleshoot common first-time scripting issues


## Introduction: Why Learn Bash on macOS?

While macOS now defaults to Zsh, Bash remains a widely used and essential shell, especially in scripting for automation, enterprise administration, and cross-platform tasks. Learning Bash on macOS helps you:

- **Automate repetitive tasks** - From simple file organization to complex deployment workflows
- **Build secure, portable scripts** - Write code that runs reliably across different systems
- **Work effectively in mixed environments** - Seamlessly transition between Linux servers and macOS workstations
- **Prepare for real-world security use cases** - Script vulnerability scans, compliance checks, and security automation
- **Integrate with enterprise tools** - Connect with MDM systems, security tools, and modern DevOps practices

As a system administrator or security engineer, mastering Bash on macOS empowers you to automate security hardening, manage endpoints at scale, and respond quickly to threats. This book bridges fundamental Bash concepts with advanced macOS-specific security practices, preparing you for enterprise-grade automation.


## 1.1 The Terminal on macOS

The **Terminal** is your command-line interface (CLI). On macOS, you can find it under:

```bash
Applications → Utilities → Terminal
```

You can also use third-party terminals like [iTerm2](https://iterm2.com) for enhanced features such as split panes, profiles, and hotkeys.


## 1.2 Bash vs Zsh on macOS

As of **macOS Catalina (10.15)**, Apple switched the default shell from Bash to **Zsh**. Here's a quick comparison:

| Feature              | Bash (v3.2 on macOS)   | Zsh                                |
|----------------------|------------------------|------------------------------------|
| Default shell?       | No (after Catalina)    | Yes (after Catalina)               |
| Version on macOS     | 3.2 (GPLv2 licensed)   | Latest maintained by Apple         |
| Script compatibility | Widely supported     | Zsh syntax differs in some cases |
| Best for...          | Portability, scripting | Interactive shell usage            |

To switch to Bash temporarily:

```bash
bash
```

To make Bash your default shell:

```bash
chsh -s /bin/bash
```

You’ll be prompted to enter your password. This only applies to your user account.


## 1.3 Your First Bash Script

Let’s create a simple Bash script to print “Hello, Secure Bash!” to the Terminal.

1. Open your terminal.
2. Create a new script file:

```bash
nano hello.sh
```

1. Add the following code:

```bash
#!/bin/bash
echo "Hello, Secure Bash!"
```

1. Save and exit (`Ctrl+O` to write out, then `Ctrl+X` to exit).
2. Make it executable:

```bash
chmod +x hello.sh
```

1. Run the script:

```bash
./hello.sh
```

Output:

```bash
Hello, Secure Bash!
```

Congratulations! You’ve just written and run your first Bash script on macOS.


## 1.4 Security Tip: Trusting Scripts

Never run scripts from the internet blindly. Review their contents first with `cat` or `nano`. If you're unsure where the script came from or what it does, **don’t execute it**.


## 1.5 Key Concepts

| Term                   | Definition                                                         |
|------------------------|---------------------------------------------------------------------|
| **Shell**              | A program that interprets command-line input (e.g., Bash, Zsh)     |
| **Script**             | A file containing a sequence of commands for the shell to run      |
| **Executable**         | A file with permission to be run as a program                      |
| **Shebang (`#!`)**     | The first line in a script that specifies which interpreter to use |


## Chapter 1 Exercise

**Create a startup script:**

Write a script that:

1. Prints your username.
2. Prints today’s date.
3. Prints the number of files in your Desktop folder.

Hint:

```bash
#!/bin/bash
echo "User: $USER"
echo "Date: $(date)"
echo "Files in Desktop: $(ls ~/Desktop | wc -l)"
```

Save it as `startup.sh`, make it executable, and run it!


## macOS Scripting Tips

- macOS Bash is older (`3.2`) — avoid Bash 4+ features unless you're using Homebrew to install a newer version.
- Use `pbcopy` and `pbpaste` to work with the clipboard.
- Use `open` to open files and apps from scripts:

```bash
open -a "Safari" https://apple.com
```
