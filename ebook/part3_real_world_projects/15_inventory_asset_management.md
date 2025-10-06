# Chapter 15: Inventory & Asset Management

## Learning Objectives

By the end of this chapter, you will be able to:

* Gather detailed macOS hardware, software, and configuration inventory data using Bash.
* Generate structured outputs (CSV, JSON, plist, SQLite) suitable for audits and automation.
* Use system utilities efficiently without overloading devices.
* Integrate inventory into patching and rollout workflows.
* Automate periodic scans via launchd for continuous visibility.

## Introduction

Fleet administrators depend on accurate and up-to-date inventory data to make decisions about patching, deployment, and compliance. This chapter goes beyond basic collection, showing how to build **production-grade, efficient, and verifiable inventory pipelines** using Bash and built-in macOS utilities. We focus on scripts that scale—from a single MacBook to an enterprise fleet managed through MDM.

macOS offers rich sources of truth: `system_profiler`, `ioreg`, `pkgutil`, Spotlight (`mdfind`, `mdls`), and system receipts. By wrapping these tools in modular functions, you can build consistent reports with minimal overhead.

## Section 1 – Collecting Hardware Inventory

### 1.1 Efficient Hardware Collection

Use `system_profiler` for high-level summaries. Always specify the minimal set of datatypes for faster execution:

```bash
#!/bin/bash
# hardware_inventory.sh

output="/tmp/hardware_inventory.json"
system_profiler SPHardwareDataType SPStorageDataType SPNetworkDataType -json > "$output"
echo "Hardware inventory saved to: $output"
```

To reduce runtime further, use the mini detail level:

```bash
system_profiler SPHardwareDataType -detailLevel mini
```

Combine with `ioreg` for low-level information:

```bash
ioreg -l | grep "Model"  # Model ID
ioreg -rd1 -c IOPlatformExpertDevice | awk -F\" '/IOPlatformSerialNumber/{print $4}'
```

### 1.2 Battery and Power Metrics

```bash
pmset -g batt
system_profiler SPPowerDataType | grep -E 'Cycle Count|Condition'
```

### 1.3 Network and Storage Enumeration

```bash
networksetup -listallhardwareports
system_profiler SPStorageDataType -json | jq '.[0].SPStorageDataType[] | {name: ._name, capacity: .size}'
```

## Section 2 – Collecting Software Inventory

### 2.1 Application Inventory via Spotlight

```bash
#!/bin/bash
# software_inventory.sh
output="/tmp/software_inventory.csv"
echo "App Name,Version,Path" > "$output"

while IFS= read -r app; do
  version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist" 2>/dev/null)
  echo "$(basename "$app"),${version:-N/A},$app" >> "$output"
done < <(mdfind "kMDItemContentType == 'com.apple.application-bundle'")

echo "Software inventory exported to $output"
```

### 2.2 Package Receipts and Install History

```bash
pkgutil --pkgs > /tmp/pkg_list.txt
pkgutil --pkg-info-plist com.apple.pkg.BaseSystemBinaries
```

To see user-facing install history:

```bash
system_profiler SPInstallHistoryDataType | grep -E "Install Date|Display Name"
```

### 2.3 Frameworks and Launch Items

Quickly check for login items and LaunchAgents:

```bash
ls /Library/LaunchAgents /Library/LaunchDaemons ~/Library/LaunchAgents 2>/dev/null
```

## Section 3 – Exporting and Normalizing Inventory Data

### 3.1 Multiple Output Formats

| Format | Command | Best For |
|--------|----------|-----------|
| JSON | `system_profiler -json` | Structured automation |
| CSV | Custom script | Human review |
| plist | Native macOS compatibility | Config archives |
| SQLite | `sqlite3` | Historical snapshots |

### 3.2 Convert JSON to CSV

Note: `jq` is not included with macOS by default. Install it with `brew install jq` before running this command.

```bash
jq -r '.SPHardwareDataType[] | [.machine_name, .cpu_type, .physical_memory] | @csv' hardware_inventory.json > hardware_inventory.csv
```

### 3.3 Build a Persistent Database

```bash
sqlite3 /usr/local/share/inventory.db <<'SQL'
CREATE TABLE IF NOT EXISTS systems (
  hostname TEXT,
  model TEXT,
  memory TEXT,
  last_seen TEXT
);
SQL

echo "Inserting current data..."
sqlite3 /usr/local/share/inventory.db \
  "INSERT INTO systems VALUES ('$(hostname)', '$(system_profiler SPHardwareDataType | awk -F: '/Identifier/{print $2}' | xargs)', '$(sysctl -n hw.memsize)', '$(date)');"
```

Query later with:

```bash
sqlite3 /usr/local/share/inventory.db "SELECT * FROM systems ORDER BY last_seen DESC LIMIT 5;"
```

You now have multiple formats for structured inventory storage, ready for analysis or automation pipelines.

## Section 4 – Integrating Inventory into App Rollouts

Use inventory metrics to make rollout decisions dynamically.

```bash
#!/bin/bash
os_version=$(sw_vers -productVersion | cut -d '.' -f1,2)
required_version="14.0"
arch=$(uname -m)

if (( $(echo "$os_version < $required_version" | bc -l) )); then
  echo "Skipping rollout: macOS $os_version below required $required_version"
elif [[ "$arch" != "arm64" ]]; then
  echo "Intel device detected; deferring deployment."
else
  echo "Device eligible for rollout"
fi
```

Integrate this logic into MDM scripts or CI/CD pipelines. Combine with application version checks to ensure prerequisites are met before pushing updates.

## Section 5 – Automating Inventory Collection with launchd

LaunchDaemons run with root privileges and must be placed in `/Library/LaunchDaemons` for system-wide jobs. User-level tasks should instead use `~/Library/LaunchAgents`.

Create a LaunchDaemon to run daily inventory updates:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.example.inventory</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/hardware_inventory.sh</string>
  </array>
  <key>StartInterval</key><integer>86400</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>/var/log/inventory.log</string>
  <key>StandardErrorPath</key><string>/var/log/inventory.err</string>
</dict>
</plist>
```

Deploy this file to `/Library/LaunchDaemons/com.example.inventory.plist` and load with:

```bash
sudo launchctl load -w /Library/LaunchDaemons/com.example.inventory.plist
```

With launchd automation, your inventory collection becomes hands-free and consistent across devices.

## Section 6 – Uploading Results Securely

Push results to a remote server for central analysis:

```bash
#!/bin/bash
file="/usr/local/share/inventory.json"
url="https://inventory.example.com/upload"

curl --proto https --fail --retry 3 --cacert /etc/ssl/certs/ca-certificates.crt \
  -F "file=@$file" $url && echo "Upload complete"
```

Security Note: Avoid hardcoding credentials or tokens directly in scripts. Use macOS Keychain or environment variables to manage secrets securely.

By combining automation with secure uploads, you achieve full visibility while maintaining strong data protection standards.

## Chapter 15 Exercise

**Objective:** Build an automated inventory pipeline.

1. Create a combined script that collects hardware, software, and package data.
2. Save JSON + CSV outputs under `/usr/local/share/inventory/`.
3. Schedule the job via `launchd`.
4. Upload the file securely to a central endpoint.
5. Add validation that checks CPU arch and OS version before upload.

**Bonus:** Extend to append data to an SQLite database for long-term history.

## macOS Scripting Tips

* Limit `system_profiler` usage to essential datatypes to reduce runtime.
* Prefer `mdfind` over directory traversal for app discovery.
* Combine logs with `osquery` for richer telemetry.
* Test scripts with throttled network to simulate low-connectivity conditions.
* Ensure all output files have `chmod 640` to prevent information leaks.
