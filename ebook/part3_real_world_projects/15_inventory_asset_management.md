# Chapter 15: Inventory & Asset Management

## Learning Objectives

By the end of this chapter, you will be able to:

- Gather detailed macOS hardware, software, and configuration inventory data using Bash.
- Generate structured outputs (CSV, JSON, plist, SQLite) suitable for audits and automation.
- Use system utilities efficiently without overloading devices.
- Integrate inventory into patching and rollout workflows.
- Automate periodic scans via launchd for continuous visibility.

## Introduction

Fleet administrators depend on accurate and up-to-date inventory data to make decisions about patching, deployment, and compliance. This chapter goes beyond basic collection, showing how to build **production-grade, efficient, and verifiable inventory pipelines** using Bash and built-in macOS utilities. We focus on scripts that scale—from a single MacBook to an enterprise fleet managed through MDM.

In enterprise environments, comprehensive inventory management serves multiple critical functions: asset tracking for financial accountability, software license compliance, security posture assessment, capacity planning, and incident response. Without accurate inventory data, organizations cannot effectively manage costs, ensure compliance, or respond to security threats. Manual inventory processes don't scale, and incomplete data leads to poor decision-making and increased risk.

macOS offers rich sources of truth: `system_profiler`, `ioreg`, `pkgutil`, Spotlight (`mdfind`, `mdls`), and system receipts. By wrapping these tools in modular functions, you can build consistent reports with minimal overhead that integrate seamlessly with enterprise asset management systems, MDM platforms, and SIEM solutions.

## Business Drivers for Inventory

Understanding why inventory matters in enterprise contexts helps prioritize what data to collect and how frequently to collect it.

### Financial Accountability and Asset Tracking

**Use Cases:**

- Track hardware assets for depreciation and lifecycle management
- Identify unused or underutilized devices for reallocation
- Support hardware refresh planning and budgeting
- Provide audit trails for asset purchases and disposal

**Data Requirements:**

- Device serial numbers, model identifiers, purchase dates
- Warranty status and service coverage information
- Physical location and user assignment
- Hardware specifications (RAM, storage, CPU) for capacity planning

### Software License Compliance

**Use Cases:**

- Ensure compliance with software licensing agreements
- Identify unlicensed software installations
- Track license usage across the organization
- Support vendor audits and license renewal negotiations

**Data Requirements:**

- Installed applications with versions and installation paths
- Package receipts for managed software
- Application signatures and bundle identifiers
- Installation dates and sources (App Store, MDM, manual install)

### Security Posture and Risk Management

**Use Cases:**

- Identify vulnerable software versions requiring patching
- Detect unauthorized software installations
- Track security software deployment status
- Support incident response with device and software baselines

**Data Requirements:**

- OS version and patch level
- Installed security tools (EDR, encryption status)
- Software versions for vulnerability assessment
- Network configuration and security settings

### Operational Decision-Making

**Use Cases:**

- Determine device eligibility for OS upgrades
- Make deployment decisions based on hardware capabilities
- Identify devices requiring remediation or replacement
- Plan for capacity and resource allocation

**Data Requirements:**

- Hardware specifications and capabilities
- Current OS version and upgrade eligibility
- Available disk space and memory
- Device enrollment and management status

### Compliance and Audit Requirements

**Use Cases:**

- Demonstrate compliance with security frameworks
- Provide evidence for regulatory audits
- Track changes to device configuration over time
- Support forensic investigations

**Data Requirements:**

- Comprehensive device configuration snapshots
- Historical inventory data for trend analysis
- Change tracking and audit logs
- Compliance status indicators

## Prerequisites and Setup Requirements

Before building your inventory pipeline, ensure you have the necessary tools, permissions, and infrastructure in place.

### Required Tools and Utilities

**Built-in macOS Tools:**

- `system_profiler`: Hardware and software information
- `ioreg`: I/O Registry access for low-level hardware details
- `pkgutil`: Package receipt database queries
- `mdfind`/`mdls`: Spotlight metadata queries for applications
- `sqlite3`: Database operations for historical tracking
- `jq`: JSON parsing (install via Homebrew: `brew install jq`)

**Verification:**

```bash
# Verify core tools are available
command -v system_profiler && echo "system_profiler: OK"
command -v ioreg && echo "ioreg: OK"
command -v pkgutil && echo "pkgutil: OK"
command -v mdfind && echo "mdfind: OK"
command -v sqlite3 && echo "sqlite3: OK"
command -v jq && echo "jq: OK" || echo "jq: Not installed (brew install jq)"
```

### Permissions and Access Requirements

**File System Access:**

- Read access to `/Applications` and `/System/Applications` for application inventory
- Read access to `/Library/LaunchAgents` and `/Library/LaunchDaemons` for service enumeration
- Read access to user home directories (if collecting user-specific inventory)

**Privacy and TCC:**

- Full Disk Access may be required for comprehensive application discovery via Spotlight
- Terminal/system tool permissions for executing inventory scripts
- For managed devices, deploy PPPC profiles granting necessary permissions

**Network Access:**

- Connectivity to asset management system or upload endpoint
- DNS resolution for remote endpoints
- Firewall rules allowing HTTPS outbound connections

### Storage and Infrastructure

**Local Storage:**

- Temporary storage for inventory collection (typically <100 MB per device)
- Persistent storage for SQLite databases if maintaining local history
- Consider disk space when collecting large inventories or maintaining extensive history

**Network Infrastructure:**

- Centralized storage endpoint (web server, object storage, or asset management system)
- API endpoint for inventory submission
- Authentication and authorization mechanisms (API keys, certificates, OAuth)

**Monitoring and Alerting:**

- Infrastructure to monitor inventory collection success rates
- Alerts for devices that haven't reported inventory within expected timeframes
- Dashboard for inventory completeness and coverage

### MDM Integration Prerequisites

**MDM Platform:**

- MDM system with script deployment capabilities
- Extension attribute or custom field support for inventory data
- API access for programmatic inventory submission (optional but recommended)

**Deployment Considerations:**

- Script distribution method (MDM script, package installer, or LaunchDaemon)
- Update mechanism for inventory scripts
- Error reporting and logging infrastructure

## Designing Your Inventory Strategy

Before writing any code, design your inventory strategy to align with business requirements and operational constraints.

### Define Your Inventory Scope

**Hardware Inventory:**

- What hardware attributes are required? (serial, model, specs, warranty)
- How frequently does hardware change? (rarely, so daily collection may be overkill)
- What hardware information is needed for asset management integration?

**Software Inventory:**

- What applications must be tracked? (all applications, managed only, or security-relevant)
- How do you handle user-installed vs. managed software?
- What version detail is required? (major.minor or full version strings)

**Configuration Inventory:**

- What system settings are critical to track?
- Which configuration changes trigger alerts or remediation?
- How do you differentiate between user changes and managed configuration?

### Determine Collection Frequency

**Factors Influencing Frequency:**

- **Hardware**: Changes rarely, so weekly or monthly collection may suffice
- **Software**: Changes frequently, so daily collection recommended
- **Configuration**: Depends on change rate and security requirements
- **Performance Impact**: More frequent collection = more system resource usage

**Recommended Cadence:**

- **Hardware**: Weekly or monthly (hardware doesn't change often)
- **Software**: Daily (applications are installed/updated frequently)
- **Configuration**: Daily or on-demand (for security-critical settings)
- **Full Inventory**: Weekly or bi-weekly (comprehensive snapshot)

### Plan for Scale

**Fleet Size Considerations:**

- Small fleets (<100 devices): Simple scripts, direct database writes acceptable
- Medium fleets (100-1000 devices): Batch processing, queued uploads recommended
- Large fleets (1000+ devices): Distributed collection, centralized aggregation, rate limiting required

**Performance Optimization:**

- Minimize `system_profiler` usage (it's slow; use specific datatypes only)
- Cache results where possible to avoid redundant collection
- Stagger collection times across devices to avoid network spikes
- Use incremental updates where supported (only collect changed data)

### Data Retention and Lifecycle

**Retention Requirements:**

- How long must inventory history be retained? (compliance requirements)
- What's the retention policy for deleted devices?
- When should historical data be archived or purged?

**Storage Strategy:**

- Centralized storage vs. distributed (local SQLite + periodic upload)
- Database design for efficient querying and trend analysis
- Backup and recovery procedures for inventory data

## 15.1 Collecting Hardware Inventory

### 15.1.1 Efficient Hardware Collection

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

### 15.1.2 Battery and Power Metrics

```bash
pmset -g batt
system_profiler SPPowerDataType | grep -E 'Cycle Count|Condition'
```

### 15.1.3 Network and Storage Enumeration

```bash
networksetup -listallhardwareports
system_profiler SPStorageDataType -json | jq '.[0].SPStorageDataType[] | {name: ._name, capacity: .size}'
```

## 15.2 Collecting Software Inventory

### 15.2.1 Application Inventory via Spotlight

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

### 15.2.2 Package Receipts and Install History

```bash
pkgutil --pkgs > /tmp/pkg_list.txt
pkgutil --pkg-info-plist com.apple.pkg.BaseSystemBinaries
```

To see user-facing install history:

```bash
system_profiler SPInstallHistoryDataType | grep -E "Install Date|Display Name"
```

### 15.2.3 Frameworks and Launch Items

Quickly check for login items and LaunchAgents:

```bash
ls /Library/LaunchAgents /Library/LaunchDaemons ~/Library/LaunchAgents 2>/dev/null
```

## 15.3 Exporting and Normalizing Inventory Data

### 15.3.1 Multiple Output Formats

| Format | Command | Best For |
|--------|----------|-----------|
| JSON | `system_profiler -json` | Structured automation |
| CSV | Custom script | Human review |
| plist | Native macOS compatibility | Config archives |
| SQLite | `sqlite3` | Historical snapshots |

### 15.3.2 Convert JSON to CSV

Note: `jq` is not included with macOS by default. Install it with `brew install jq` before running this command.

```bash
jq -r '.SPHardwareDataType[] | [.machine_name, .cpu_type, .physical_memory] | @csv' hardware_inventory.json > hardware_inventory.csv
```

### 15.3.3 Build a Persistent Database

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

## 15.4 Integrating Inventory into App Rollouts

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

## 15.5 MDM Integration Examples

Enterprise inventory management requires integration with MDM platforms for centralized visibility and automation. This section provides practical examples for common MDM systems.

### Jamf Pro Extension Attributes

Jamf Pro extension attributes allow you to collect custom inventory data that appears in the device record. Extension attributes execute on the device and return data that Jamf stores and makes searchable.

**Example: Hardware Inventory Extension Attribute**

```bash
#!/bin/bash
# Extension Attribute: Hardware Summary

# Collect key hardware attributes
serial=$(system_profiler SPHardwareDataType | awk '/Serial Number/{print $NF}')
model=$(system_profiler SPHardwareDataType | awk '/Model Identifier/{print $NF}')
memory=$(system_profiler SPHardwareDataType | awk '/Memory/{print $2" "$3}')
cpu=$(system_profiler SPHardwareDataType | awk '/Chip/{print $2" "$3" "$4" "$5}')

# Output as XML for Jamf
echo "<result>"
echo "Serial: $serial | Model: $model | Memory: $memory | CPU: $cpu"
echo "</result>"
```

**Example: Software Inventory Extension Attribute**

```bash
#!/bin/bash
# Extension Attribute: Installed Applications Count

app_count=$(mdfind "kMDItemContentType == 'com.apple.application-bundle'" 2>/dev/null | wc -l | tr -d ' ')

echo "<result>$app_count</result>"
```

**Example: Storage Usage Extension Attribute**

```bash
#!/bin/bash
# Extension Attribute: Storage Usage

# Get disk usage as percentage
disk_usage=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')

# Determine status
if [[ $disk_usage -lt 80 ]]; then
    status="OK"
elif [[ $disk_usage -lt 90 ]]; then
    status="WARNING"
else
    status="CRITICAL"
fi

echo "<result>$disk_usage% - $status</result>"
```

**Deploying Extension Attributes:**

1. Create extension attribute in Jamf Pro (Computer Management → Extension Attributes → New)
2. Set input type to "Script"
3. Paste script content
4. Set display name and data type
5. Scope to device groups as needed
6. Jamf will collect on inventory update (configurable frequency)

### Microsoft Intune Custom Attributes

Intune uses device properties and custom attributes for inventory data. Use shell scripts or native tools to populate these attributes.

**Example: Intune Device Property Script**

```bash
#!/bin/bash
# Intune Device Property Collection Script

# Collect inventory data
hostname=$(scutil --get ComputerName)
serial=$(system_profiler SPHardwareDataType | awk '/Serial Number/{print $NF}')
os_version=$(sw_vers -productVersion)
arch=$(uname -m)

# Create JSON output for Intune
cat <<EOF
{
  "hostname": "$hostname",
  "serial_number": "$serial",
  "os_version": "$os_version",
  "architecture": "$arch",
  "inventory_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
```

**Deploying via Intune:**

1. Create shell script policy in Intune
2. Set script to run as system (root)
3. Configure script output capture
4. Map output fields to Intune device properties via Graph API or Intune portal

### Integration with Asset Management Systems

Many organizations use dedicated asset management systems (ServiceNow, Snipe-IT, Lansweeper) that require structured inventory uploads.

**Example: ServiceNow API Integration**

```bash
#!/bin/bash
# ServiceNow Inventory Upload Script

# Collect comprehensive inventory
inventory_json=$(cat <<EOF
{
  "serial_number": "$(system_profiler SPHardwareDataType | awk '/Serial Number/{print $NF}')",
  "hostname": "$(scutil --get ComputerName)",
  "model": "$(system_profiler SPHardwareDataType | awk '/Model Name/{print substr($0, index($0,$3))}')",
  "os_version": "$(sw_vers -productVersion)",
  "memory_gb": "$(system_profiler SPHardwareDataType | awk '/Memory/{print $2}')",
  "disk_space_gb": "$(df -g / | awk 'NR==2{print $2}')",
  "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
)

# Upload to ServiceNow (example endpoint)
SERVICENOW_INSTANCE="yourinstance.service-now.com"
API_USER="inventory_service_account"
API_PASS="$(security find-generic-password -w -s 'ServiceNow' -a 'inventory')"

curl -X POST \
  "https://${SERVICENOW_INSTANCE}/api/now/table/u_computer" \
  -u "${API_USER}:${API_PASS}" \
  -H "Content-Type: application/json" \
  -d "$inventory_json"
```

**Security Best Practices:**

- Store API credentials in macOS Keychain (not in scripts)
- Use service accounts with least-privilege access
- Implement retry logic with exponential backoff
- Log upload attempts for troubleshooting

### Webhook Integration for Real-Time Inventory

For real-time inventory updates, use webhook endpoints that trigger downstream processes.

**Example: Generic Webhook Integration**

```bash
#!/bin/bash
# Webhook Inventory Submission

WEBHOOK_URL="${INVENTORY_WEBHOOK_URL:-https://inventory.example.com/webhook}"
INVENTORY_FILE="/tmp/inventory_$(date +%s).json"

# Collect inventory (simplified example)
cat > "$INVENTORY_FILE" <<EOF
{
  "device_id": "$(scutil --get ComputerName)",
  "serial": "$(system_profiler SPHardwareDataType | awk '/Serial Number/{print $NF}')",
  "os_version": "$(sw_vers -productVersion)",
  "inventory_timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

# Submit with retry logic
for attempt in {1..3}; do
    if curl -f -s -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "@$INVENTORY_FILE" \
        --max-time 30; then
        echo "Inventory submitted successfully"
        rm -f "$INVENTORY_FILE"
        exit 0
    else
        echo "Attempt $attempt failed, retrying..."
        sleep $((attempt * 2))
    fi
done

echo "Failed to submit inventory after 3 attempts" >&2
exit 1
```

## 15.6 Scale and Performance Considerations

As fleet size grows, inventory collection performance becomes critical. This section addresses optimization strategies for large-scale deployments.

### Performance Optimization Strategies

**Minimize system_profiler Usage:**

- `system_profiler` is slow (can take 30+ seconds for full hardware profile)
- Only query specific datatypes needed: `system_profiler SPHardwareDataType -json`
- Use `-detailLevel mini` when full detail isn't required
- Cache results when hardware rarely changes

**Optimize Spotlight Queries:**

- Limit search scope to relevant directories
- Use specific metadata queries instead of broad searches
- Cache application lists between full scans
- Consider incremental updates (only scan for new/changed apps)

**Efficient Data Collection:**

- Collect hardware weekly (changes rarely)
- Collect software daily (changes frequently)
- Separate collection scripts for different inventory types
- Stagger collection times across devices to avoid network spikes

**Resource Management:**

- Use `nice` to reduce script priority: `nice -n 10 /path/to/inventory.sh`
- Limit script execution time with timeouts
- Monitor CPU and memory usage during collection
- Schedule collections during off-hours when possible

### Network and Storage Optimization

**Batch Uploads:**

- Collect inventory locally, upload in batches
- Compress inventory data before upload (gzip JSON files)
- Use incremental uploads (only send changed data)
- Queue uploads for retry if network is unavailable

**Storage Considerations:**

- Limit local inventory file retention (purge old files)
- Use SQLite for efficient local storage
- Implement data rotation policies
- Monitor disk usage on devices with persistent local storage

### Scalability Patterns

**Small Fleets (<100 devices):**

- Direct database writes acceptable
- Simple scripts with basic error handling
- Real-time or near-real-time collection feasible

**Medium Fleets (100-1000 devices):**

- Implement queued uploads
- Batch processing recommended
- Stagger collection times across devices
- Monitor collection success rates

**Large Fleets (1000+ devices):**

- Distributed collection architecture
- Centralized aggregation and processing
- Rate limiting on upload endpoints
- Monitoring and alerting for collection failures
- Consider dedicated inventory collection infrastructure

## 15.7 Error Handling and Retry Logic

Robust inventory collection requires error handling for network failures, permission issues, and transient errors.

### Comprehensive Error Handling Example

```bash
#!/bin/bash
# inventory_collection.sh - Production-grade inventory collection with error handling

set -euo pipefail

# Configuration
INVENTORY_DIR="/usr/local/share/inventory"
LOG_FILE="/var/log/inventory.log"
MAX_RETRIES=3
RETRY_DELAY=5

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Error handling
trap 'log "ERROR: Script failed at line $LINENO"' ERR

# Create inventory directory
mkdir -p "$INVENTORY_DIR" || {
    log "ERROR: Failed to create inventory directory"
    exit 1
}

# Function: Collect hardware inventory with error handling
collect_hardware() {
    local output_file="$INVENTORY_DIR/hardware_$(date +%Y%m%d_%H%M%S).json"
    
    if system_profiler SPHardwareDataType SPStorageDataType -json > "$output_file" 2>/dev/null; then
        log "Hardware inventory collected: $output_file"
        echo "$output_file"
    else
        log "ERROR: Hardware inventory collection failed"
        return 1
    fi
}

# Function: Collect software inventory with error handling
collect_software() {
    local output_file="$INVENTORY_DIR/software_$(date +%Y%m%d_%H%M%S).json"
    local temp_file="/tmp/software_list.txt"
    
    # Check if Spotlight is available
    if ! command -v mdfind &>/dev/null; then
        log "WARNING: mdfind not available, skipping software inventory"
        return 1
    fi
    
    # Collect application list
    if mdfind "kMDItemContentType == 'com.apple.application-bundle'" > "$temp_file" 2>/dev/null; then
        # Process and format as JSON (simplified)
        {
            echo "{"
            echo "  \"applications\": ["
            local first=true
            while IFS= read -r app; do
                [[ "$first" == true ]] && first=false || echo ","
                echo "    {"
                echo "      \"path\": \"$app\","
                echo "      \"name\": \"$(basename "$app" .app)\""
                echo -n "    }"
            done < "$temp_file"
            echo ""
            echo "  ]"
            echo "}"
        } > "$output_file"
        
        rm -f "$temp_file"
        log "Software inventory collected: $output_file"
        echo "$output_file"
    else
        log "ERROR: Software inventory collection failed"
        rm -f "$temp_file"
        return 1
    fi
}

# Function: Upload with retry logic
upload_inventory() {
    local file="$1"
    local url="${INVENTORY_UPLOAD_URL:-https://inventory.example.com/upload}"
    
    for attempt in $(seq 1 $MAX_RETRIES); do
        log "Upload attempt $attempt/$MAX_RETRIES: $(basename "$file")"
        
        if curl -f -s -X POST "$url" \
            -H "Content-Type: application/json" \
            -H "X-Device-ID: $(scutil --get ComputerName)" \
            -d "@$file" \
            --max-time 30 \
            --retry 2 \
            --retry-delay 1; then
            log "Upload successful: $(basename "$file")"
            return 0
        else
            log "Upload attempt $attempt failed"
            if [[ $attempt -lt $MAX_RETRIES ]]; then
                sleep $RETRY_DELAY
            fi
        fi
    done
    
    log "ERROR: Failed to upload $(basename "$file") after $MAX_RETRIES attempts"
    return 1
}

# Main execution
main() {
    log "Starting inventory collection"
    
    # Collect hardware
    hardware_file=$(collect_hardware) || true
    
    # Collect software
    software_file=$(collect_software) || true
    
    # Upload collected inventory
    [[ -n "${hardware_file:-}" ]] && upload_inventory "$hardware_file" || true
    [[ -n "${software_file:-}" ]] && upload_inventory "$software_file" || true
    
    # Cleanup old inventory files (keep last 7 days)
    find "$INVENTORY_DIR" -type f -mtime +7 -delete 2>/dev/null || true
    
    log "Inventory collection completed"
}

main "$@"
```

### Common Error Scenarios and Handling

**Network Failures:**

- Implement retry logic with exponential backoff
- Queue failed uploads for later retry
- Log network errors for troubleshooting
- Continue collection even if upload fails (store locally)

**Permission Errors:**

- Check for required permissions before collection
- Gracefully handle missing permissions (log warning, skip affected data)
- Provide clear error messages for permission issues
- Document required permissions in deployment guide

**Resource Constraints:**

- Check disk space before creating inventory files
- Monitor script execution time
- Implement timeouts for long-running operations
- Handle memory constraints gracefully

## 15.8 Data Lifecycle and Retention

Effective inventory management includes policies for data retention, archival, and disposal.

### Retention Policies

**Operational Data (Current State):**

- Retain current inventory snapshot indefinitely
- Update on each collection cycle
- Use for real-time queries and dashboards

**Historical Data (Trends):**

- Retain daily snapshots for 90 days
- Retain weekly snapshots for 1 year
- Retain monthly snapshots for 7 years (compliance requirement)
- Archive older data to cold storage

**Deleted Devices:**

- Retain device records for 90 days after deletion
- Archive deleted device data for compliance (if required)
- Maintain audit trail of device lifecycle events

### Data Archival Strategy

**Archival Process:**

- Identify data eligible for archival (based on retention policy)
- Export to compressed archive format (tar.gz, zip)
- Move to cold storage (object storage, tape backup)
- Update database to mark data as archived
- Delete from primary storage after archival confirmation

**Retrieval Process:**

- Maintain index of archived data
- Document retrieval procedure
- Test archival/retrieval process regularly

### Compliance Considerations

**Regulatory Requirements:**

- HIPAA: May require inventory data retention for audit trails
- SOX: Financial asset tracking may require extended retention
- GDPR: Personal device data subject to privacy regulations
- Industry-specific: Check requirements for your sector

**Data Disposal:**

- Securely delete inventory data when retention period expires
- Document disposal procedures
- Maintain audit log of data disposal events
- Consider data anonymization for long-term retention

## 15.9 Automating Inventory Collection with launchd

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

## 15.10 Uploading Results Securely

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

## 15.11 Troubleshooting

This section addresses common issues encountered when deploying inventory collection in enterprise environments.

### Collection Failures

**Symptom: Inventory script runs but produces empty or incomplete output**

**Diagnosis:**

```bash
# Check script execution logs
tail -50 /var/log/inventory.log

# Verify required tools are available
command -v system_profiler
command -v mdfind
command -v sqlite3

# Check file permissions
ls -la /usr/local/share/inventory/
```

**Common Causes and Solutions:**

1. **Missing Permissions:**
   - **Symptom**: Permission denied errors in logs
   - **Solution**: Verify script has execute permissions and runs with appropriate privileges
   - **Fix**: `sudo chmod 755 /usr/local/bin/inventory.sh`

2. **Spotlight Index Not Available:**
   - **Symptom**: `mdfind` returns no results or errors
   - **Solution**: Rebuild Spotlight index or use alternative collection method
   - **Fix**: `sudo mdutil -E /` (rebuild index)

3. **Insufficient Disk Space:**
   - **Symptom**: Script fails when writing inventory files
   - **Solution**: Check available disk space and clean up old files
   - **Fix**: `df -h /` to check space, implement file rotation

### Upload Failures

**Symptom: Inventory collects successfully but upload fails**

**Diagnosis:**

```bash
# Check network connectivity
ping -c 3 inventory.example.com

# Test HTTPS connection
curl -v https://inventory.example.com/upload

# Check DNS resolution
nslookup inventory.example.com

# Review upload logs
grep -i "upload\|error\|failed" /var/log/inventory.log
```

**Common Causes and Solutions:**

1. **Network Connectivity Issues:**
   - **Symptom**: Connection timeout or DNS resolution failures
   - **Solution**: Verify network connectivity and DNS configuration
   - **Workaround**: Queue uploads for retry when network is available

2. **Authentication Failures:**
   - **Symptom**: 401 Unauthorized or 403 Forbidden errors
   - **Solution**: Verify API credentials and token expiration
   - **Fix**: Check Keychain for stored credentials: `security find-generic-password -s 'InventoryAPI'`

3. **SSL/TLS Certificate Issues:**
   - **Symptom**: Certificate verification failures
   - **Solution**: Verify certificate chain and trust settings
   - **Fix**: Update CA certificates or configure certificate pinning

4. **Rate Limiting:**
   - **Symptom**: 429 Too Many Requests errors
   - **Solution**: Implement request throttling and backoff
   - **Fix**: Add delays between uploads or batch requests

### Performance Issues

**Symptom: Inventory collection takes too long or impacts device performance**

**Diagnosis:**

```bash
# Measure collection time
time /usr/local/bin/inventory.sh

# Monitor resource usage
top -l 1 | grep -E "CPU|system_profiler|mdfind"

# Check system load
uptime
```

**Common Causes and Solutions:**

1. **system_profiler Running Too Long:**
   - **Cause**: Querying too many datatypes or full detail level
   - **Solution**: Limit to specific datatypes and use mini detail level
   - **Fix**: `system_profiler SPHardwareDataType -detailLevel mini -json`

2. **Spotlight Query Performance:**
   - **Cause**: Broad queries across entire filesystem
   - **Solution**: Limit search scope to specific directories
   - **Fix**: Use specific paths: `mdfind -onlyin /Applications "kMDItemContentType == 'com.apple.application-bundle'"`

3. **Concurrent Execution:**
   - **Cause**: Multiple inventory scripts running simultaneously
   - **Solution**: Implement file locking or prevent concurrent execution
   - **Fix**: Use `flock` to prevent concurrent runs:

     ```bash
     (
         flock -n 200 || { echo "Inventory already running"; exit 1; }
         # inventory collection code
     ) 200>/var/run/inventory.lock
     ```

### Data Quality Issues

**Symptom: Inventory data is incomplete or inaccurate**

**Diagnosis:**

```bash
# Verify collected data
cat /usr/local/share/inventory/hardware_*.json | jq .

# Check for missing fields
jq 'keys' /usr/local/share/inventory/hardware_*.json

# Compare against manual collection
system_profiler SPHardwareDataType -json | jq .
```

**Common Causes and Solutions:**

1. **Missing Application Data:**
   - **Cause**: Spotlight index incomplete or applications in non-standard locations
   - **Solution**: Supplement Spotlight queries with directory traversal
   - **Fix**: Combine `mdfind` with `find /Applications -name "*.app"`

2. **Incorrect Version Information:**
   - **Cause**: Info.plist parsing errors or missing version strings
   - **Solution**: Implement robust parsing with error handling
   - **Fix**: Add fallback methods for version detection

3. **Stale Data:**
   - **Cause**: Collection script not running on schedule
   - **Solution**: Verify LaunchDaemon is loaded and running
   - **Fix**: `launchctl list | grep inventory` to check status

### MDM Integration Issues

**Symptom: Extension attributes or custom attributes not populating in MDM**

**Diagnosis:**

```bash
# Test extension attribute script manually
/usr/local/bin/jamf_extension_attribute.sh

# Check Jamf logs (if applicable)
tail -50 /Library/Logs/jamf.log | grep -i "extension"

# Verify script output format
/usr/local/bin/jamf_extension_attribute.sh | head -5
```

**Common Causes and Solutions:**

1. **Incorrect Output Format:**
   - **Cause**: Extension attribute doesn't match expected format
   - **Solution**: Verify output format matches MDM requirements
   - **Fix**: For Jamf, ensure `<result>value</result>` format

2. **Script Execution Errors:**
   - **Cause**: Script errors prevent attribute collection
   - **Solution**: Add error handling and logging
   - **Fix**: Redirect stderr to log file for debugging

3. **Scope Issues:**
   - **Cause**: Extension attribute not scoped to device
   - **Solution**: Verify MDM scope and device group membership
   - **Fix**: Check MDM console for scope configuration

### Debugging Strategies

**Enable Verbose Logging:**

```bash
# Add verbose logging to inventory script
set -x  # Enable command tracing
exec 2>> /var/log/inventory.debug.log  # Redirect stderr to debug log
```

**Test Components Individually:**

```bash
# Test hardware collection
system_profiler SPHardwareDataType -json > /tmp/hardware_test.json
jq . /tmp/hardware_test.json

# Test software collection
mdfind "kMDItemContentType == 'com.apple.application-bundle'" | head -10

# Test upload
curl -v -X POST https://inventory.example.com/test -d '{"test": "data"}'
```

**Monitor Collection Process:**

```bash
# Watch inventory log in real-time
tail -f /var/log/inventory.log

# Monitor file creation
watch -n 1 'ls -lht /usr/local/share/inventory/ | head -5'

# Check LaunchDaemon status
launchctl print system/com.example.inventory 2>/dev/null || launchctl list | grep inventory
```

## Chapter 15 Exercise

**Objective:** Build an automated inventory pipeline.

1. Create a combined script that collects hardware, software, and package data.
2. Save JSON + CSV outputs under `/usr/local/share/inventory/`.
3. Schedule the job via `launchd`.
4. Upload the file securely to a central endpoint.
5. Add validation that checks CPU arch and OS version before upload.

**Bonus:** Extend to append data to an SQLite database for long-term history.

## macOS Scripting Tips

- Limit `system_profiler` usage to essential datatypes to reduce runtime.
- Prefer `mdfind` over directory traversal for app discovery.
- Combine logs with `osquery` for richer telemetry.
- Test scripts with throttled network to simulate low-connectivity conditions.
- Ensure all output files have `chmod 640` to prevent information leaks.
