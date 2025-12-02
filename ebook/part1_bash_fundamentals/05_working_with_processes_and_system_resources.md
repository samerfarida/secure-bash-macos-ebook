# Chapter 5: Working with Processes and System Resources

## Learning Objectives

By the end of this chapter, you will be able to:

- Monitor running processes and system usage
- Manage background and foreground jobs in Bash
- Use `ps`, `top`, `htop`, `kill`, `nice`, and `renice`
- Automate long-running tasks
- Understand process IDs (PIDs) and signals
- Use macOS-specific tools like `Activity Monitor`, `launchctl`, and `pmset`


## Introduction: Why Processes Matter

When you run a Bash script, launch an app, or execute a command, you're starting a process. Understanding how to inspect, manage, and influence those processes is essential for automation, performance tuning, and security auditing on macOS.

Process management is critical for security engineers who need to monitor suspicious activity, stop malware, or audit system usage. For administrators, process knowledge enables you to troubleshoot performance issues, manage system resources, and schedule automated tasks effectively. This chapter covers the fundamental tools for process management on macOS, setting you up for advanced topics like launchd (covered in Chapter 10) and system monitoring (discussed in Chapter 18).


## 5.1 Viewing Running Processes

### View system-wide processes

```bash
ps aux
```

### View your own processes

```bash
ps -u "$USER"
```

### Real-time monitoring

```bash
top
```

Or install and use `htop` (more user-friendly):

```bash
brew install htop
htop
```


## 5.2 Process IDs and Signals

Each running process has a **PID**. Use it to send signals:

```bash
kill 12345           # default SIGTERM
kill -9 12345        # force with SIGKILL
```

List signals:

```bash
kill -l
```

Send a signal by name:

```bash
kill -SIGUSR1 12345
```


## 5.3 Managing Foreground and Background Jobs

### Run in background

```bash
long_script.sh &
```

### View background jobs

```bash
jobs
```

### Bring job to foreground

```bash
fg %1
```

### Stop a job

```bash
Ctrl + Z
```

### Kill a background job

```bash
kill %1
```


## 5.4 Prioritizing with nice and renice

Run a process with lower priority:

```bash
nice -n 10 script.sh
```

Change priority of a running process:

```bash
renice 15 -p 12345
```

Lower values = higher priority (0 is default).


## 5.5 Automating Long-Running Tasks

Use `nohup` to detach from terminal:

```bash
nohup script.sh &
```

Use `cron` to schedule jobs:

```bash
crontab -e
```

Example:

```
0 3 * * * /Users/sammy/scripts/backup.sh
```

> **Note:** Replace `/Users/sammy/scripts/backup.sh` with your actual script path. Consider using `$HOME/scripts/backup.sh` or an absolute path like `/usr/local/bin/backup.sh` for system-wide scripts.

Use `launchd` for macOS-native task scheduling (discussed in later chapters).


## 5.6 Monitoring System Usage

Check CPU usage:

```bash
top -l 1 | grep "CPU usage"
```

Check memory:

```bash
vm_stat
```

Disk usage:

```bash
df -h
```

Free disk space:

```bash
du -sh ~/
```

Battery and power status:

```bash
pmset -g batt
```


## 5.7 macOS-Specific Process Tools

- `Activity Monitor`: GUI process viewer
- `launchctl`: manage background daemons
- `pmset`: control power settings
- `spindump`, `sample`, `fs_usage`: diagnostic tools

Example: List user agents loaded by `launchd`:

```bash
launchctl list | grep com.apple
```


## Chapter 5 Exercise

Write a script `watch_process.sh` that:

- Accepts a process name
- Checks if it's running
- If not, logs a warning to a file

Hint:

```bash
#!/bin/bash
process="$1"
if ! pgrep -x "$process" > /dev/null; then
  echo "[$(date)] $process is not running" >> "$HOME/process_warnings.log"
fi
```


## macOS Scripting Tips

- Use `pgrep` and `pkill` for process name filtering
- Use `nohup` and `disown` to prevent processes from dying with the terminal
- Use `launchctl bootout` and `launchctl bootin` to disable/enable services
- Monitor app hangs with `sample`: `sample [pid] -file output.txt`
- Use `spindump` to identify resource-intensive processes
- Check battery status before running intensive scripts with `pmset -g batt`
