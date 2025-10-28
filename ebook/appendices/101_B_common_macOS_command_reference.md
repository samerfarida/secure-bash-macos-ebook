# Appendix B: Common macOS Command Reference

This appendix provides a practical reference for commonly used macOS command-line tools.
These commands are essential for Bash scripting, system administration, and security tasks
on macOS systems.



## Learning Objectives

- Quickly look up essential macOS commands for daily scripting and admin tasks.
- Understand syntax and practical examples.
- Apply commands securely and efficiently in real-world scripts.



## System Information

| Command | Description | Example |
|---------|-------------|---------|
| `uname -a` | Show system information | `uname -a` |
| `sw_vers` | Display macOS version | `sw_vers` |
| `system_profiler` | Detailed hardware and software info | `system_profiler SPHardwareDataType` |
| `sysctl` | Read kernel parameters | `sysctl -a \| grep machdep.cpu` |



## File and Directory Operations

| Command | Description | Example |
|---------|-------------|---------|
| `ls` | List files and directories | `ls -alh` |
| `cd` | Change directory | `cd /usr/local/bin` |
| `pwd` | Print working directory | `pwd` |
| `mkdir` | Create directory | `mkdir ~/Projects` |
| `rm` | Remove files or directories | `rm file.txt`, `rm -rf ~/tempdir` |
| `mv` | Move or rename files | `mv old.txt new.txt` |
| `cp` | Copy files and directories | `cp file.txt ~/backup/` |
| `find` | Find files | `find / -name "*.log"` |
| `du` | Disk usage | `du -sh ~/Downloads` |
| `df` | Filesystem disk space usage | `df -h` |



## Permissions and Ownership

| Command | Description | Example |
|---------|-------------|---------|
| `chmod` | Change permissions | `chmod 755 script.sh` |
| `chown` | Change ownership | `sudo chown user:staff file.txt` |
| `sudo` | Run as superuser | `sudo nano /etc/hosts` |



## Process and Resource Management

| Command | Description | Example |
|---------|-------------|---------|
| `ps` | Show running processes | `ps aux` |
| `top` | Interactive process viewer | `top` |
| `htop` | Enhanced top (install via Homebrew) | `htop` |
| `kill` | Terminate process | `kill -9 <PID>` |
| `pkill` | Kill processes by name | `pkill -f "processname"` |



## Networking

| Command | Description | Example |
|---------|-------------|---------|
| `ifconfig` | Display network interfaces | `ifconfig` |
| `networksetup` | Configure network services | `networksetup -listallnetworkservices` |
| `ping` | Test network connectivity | `ping google.com` |
| `traceroute` | Trace network path | `traceroute google.com` |
| `netstat` | Network statistics | `netstat -nr` |
| `lsof` | List open files and sockets | `sudo lsof -i -n -P` |
| `nc` | Netcat: open TCP/UDP connections | `nc -vz host 80` |



## System Maintenance and Updates

| Command | Description | Example |
|---------|-------------|---------|
| `softwareupdate` | Manage software updates | `sudo softwareupdate -l` |
| `brew` | Homebrew package manager | `brew install wget` |
| `tmutil` | Time Machine utility | `tmutil listbackups` |
| `diskutil` | Disk management | `diskutil list` |
| `csrutil` | SIP (System Integrity Protection) status/config | `csrutil status` (must run from Recovery OS) |



## Logging and Monitoring

| Command | Description | Example |
|---------|-------------|---------|
| `log` | Unified logging system | `log show --predicate 'eventMessage contains "error"'` |
| `tail` | View end of file | `tail -f /var/log/system.log` |
| `grep` | Search text | `grep "error" /var/log/system.log` |
| `awk` | Text processing | `awk '{print $1}' file.txt` |
| `sed` | Stream editor | `sed 's/old/new/g' file.txt` |



## System Controls and Services

| Command | Description | Example |
|---------|-------------|---------|
| `launchctl` | Manage launch agents and daemons | `launchctl list` |
| `pmset` | Power management settings | `pmset -g` |
| `shutdown` | Shut down system | `sudo shutdown -h now` |
| `reboot` | Reboot system | `sudo reboot` |



## Security and Privacy

| Command | Description | Example |
|---------|-------------|---------|
| `spctl` | Gatekeeper status | `spctl --status` |
| `codesign` | Code signing operations | `codesign -dv --verbose=4 /Applications/Safari.app` |
| `csrutil` | SIP configuration | `csrutil status` |



## Handy macOS-Specific Shortcuts

| Task | Command |
|------|---------|
| Show hidden files in Finder | `defaults write com.apple.finder AppleShowAllFiles TRUE; killall Finder` |
| Flush DNS cache | `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` |
| Take screenshot from terminal | `screencapture ~/Desktop/screen.jpg` |



## Final Tips

Keep this reference nearby as you build your own scripts and automations.  
Combine these commands with robust Bash syntax to streamline your macOS workflows  
and keep your systems secure and efficient.
