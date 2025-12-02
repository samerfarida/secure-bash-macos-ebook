# Chapter 20: Application Deployment & Update Automation (Installomator + Patchomator)

## Learning Objectives

By the end of this chapter, you will be able to:

- Install and **pin** a stable (release) copy of Installomator on managed Macs.
- Deploy and update applications at scale using **label-driven** recipes.
- Pass Installomator runtime options for user experience, safety, and logging.
- **Pin app versions safely** (e.g., last‑compatible builds) without tracking GitHub feeds by hand.
- Use **Patchomator** to discover installed apps, build a label configuration, and run unattended update cycles.
- Orchestrate everything from your MDM (Jamf, Intune, Addigy, Mosyle, etc.), including repeatable policies/profiles and LaunchDaemons for scheduling.
- Troubleshoot with logs and exit codes and roll out with confidence.

## Introduction

Installomator is a community-maintained installer/update script that downloads Mac software **directly from vendor sources**, using per‑app "labels" that know where to fetch and how to install each title. You execute a single script with a label (for example, `googlechrome`) and Installomator handles download, verification, process blocking, and install/update logic.

This chapter gives you **practical, step‑by‑step recipes** to deploy Installomator **safely (pinned to the release branch)**, run label‑based installs and updates, and layer **Patchomator** on top to discover apps and keep them current—hands‑off—on your entire fleet. Throughout, we provide copy‑pasteable Bash you can drop into your MDM policies or run locally.

### Enterprise Application Management Context

Managing application deployment and updates at enterprise scale presents unique challenges. Organizations must balance security requirements (signed software, version control), operational efficiency (automated updates, minimal user disruption), and user productivity (access to required software, minimal downtime). Traditional approaches—manual installation, vendor-specific updaters, or repackaging every application—don't scale to hundreds or thousands of devices.

**Key Challenges:**

- **Scale**: Deploying and updating software across large fleets manually is time-consuming and error-prone
- **Vendor Diversity**: Different applications use different distribution methods (DMG, PKG, ZIP, direct downloads)
- **Version Management**: Tracking which versions are deployed, managing updates, and handling compatibility issues
- **User Experience**: Minimizing disruption while ensuring software stays current
- **Security**: Ensuring software is legitimate, signed, and from trusted sources

Installomator addresses these challenges by providing a unified interface for deploying applications from vendor sources, handling the complexity of different distribution methods automatically.

## Why Installomator vs. Alternatives

Understanding when Installomator is the right choice versus alternative approaches helps you make informed decisions about your application management strategy.

### Installomator Advantages

**Vendor Source Distribution:**

- Downloads directly from vendor websites/CDNs (official sources)
- No need to host or redistribute vendor software
- Automatically handles vendor authentication and download logic
- Reduces bandwidth and storage requirements on your infrastructure

**Unified Interface:**

- Single script handles all applications consistently
- Predictable behavior across different application types
- Simplified troubleshooting and logging
- Easy to integrate into MDM and automation workflows

**Community Maintained:**

- Active community continuously updates labels for new applications and versions
- Rapid response to vendor distribution method changes
- Large label library covering common enterprise applications
- Open source transparency and auditability

**Automation-Friendly:**

- Command-line interface perfect for scripts and automation
- Exit codes and logging for integration with monitoring systems
- Version detection and update logic built-in
- Minimal user interaction required

### Alternative Approaches and When to Use Them

**MDM Native Package Distribution:**

- **Best For**: Applications that require custom configuration or don't have public download URLs
- **Limitations**: Requires repackaging, hosting infrastructure, manual version updates
- **Use When**: You need to modify applications or bundle additional files/scripts

**Vendor-Specific Updaters:**

- **Best For**: Applications with robust built-in update mechanisms (e.g., Microsoft AutoUpdate)
- **Limitations**: Each vendor tool is different, inconsistent behavior, limited control
- **Use When**: Vendor updaters are reliable and provide required functionality

**Manual Installation:**

- **Best For**: One-off installations or applications installed infrequently
- **Limitations**: Doesn't scale, error-prone, time-consuming
- **Use When**: Specialized software with complex installation requirements

**Commercial Application Management:**

- **Best For**: Organizations requiring commercial support and SLA guarantees
- **Limitations**: Cost, vendor lock-in, may still require some manual work
- **Use When**: Budget allows and support requirements justify cost

**Hybrid Approach:**
Many organizations use a combination:

- **Installomator**: Standard productivity applications (Chrome, Slack, Zoom, etc.)
- **MDM Packages**: Custom or specialized applications requiring configuration
- **Vendor Updaters**: Applications with reliable built-in update mechanisms
- **Manual**: Rare or specialized software

> **Paths used in this chapter**
>
> - Installomator: `/usr/local/Installomator/Installomator.sh`
> - Installomator log: `/private/var/log/Installomator.log`
> - Patchomator config (default): `/Library/Application Support/Patchomator/patchomator.plist`

## 20.1 Install Installomator (Pinned to a Stable Release)

The Installomator repository’s **`main` branch is a beta/pre‑release** stream. For production, use the **`release` branch** or a tagged Release archive. This section installs the **release** branch to a standard path.

### 1.1 Create the destination

```bash
#!/bin/bash
sudo mkdir -p /usr/local/Installomator
sudo chown root:wheel /usr/local/Installomator
sudo chmod 755 /usr/local/Installomator
```

### 1.2 Fetch the **release** branch script

```bash
#!/bin/bash
curl -L https://raw.githubusercontent.com/Installomator/Installomator/release/Installomator.sh   -o /usr/local/Installomator/Installomator.sh

sudo chmod 755 /usr/local/Installomator/Installomator.sh
sudo xattr -dr com.apple.quarantine /usr/local/Installomator/Installomator.sh 2>/dev/null || true
```

> **Alternative:** Download the latest non‑beta **Release** zip from the repository’s Releases page and extract `Installomator.sh` to `/usr/local/Installomator/`.

### 1.3 Verify version and dry‑run behavior

By default, a freshly installed script may run with debugging enabled. Confirm the version and run a non‑installing test:

```bash
/usr/local/Installomator/Installomator.sh version
/usr/local/Installomator/Installomator.sh longversion
```

## 20.2 Running a Label (Install or Update an App)

Labels are the unit of work. Each label defines vendor URLs, install type (pkg/dmg/zip), expected signing Team ID, and any special logic.

### 2.1 List or search labels

```bash
# Show all labels
/usr/local/Installomator/Installomator.sh | less

# Search for a label name (case-insensitive)
/usr/local/Installomator/Installomator.sh | grep -i "bbedit"
```

### 2.2 Install a single app with user‑friendly prompts

```bash
#!/bin/bash
label="googlechrome"
/usr/local/Installomator/Installomator.sh "$label"   BLOCKING_PROCESS_ACTION=prompt_user   NOTIFY=success   LOGO="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarAdvanced.icns"
```

#### What this does

- Detects if Chrome is installed and whether it’s current.
- If the app is running, prompts the user to quit/save work before install.
- Shows a success notification after completion.
- Uses a system icon for branding.

### 2.3 Silent update, fail if app is open

```bash
#!/bin/bash
label="visualstudiocode"
/usr/local/Installomator/Installomator.sh "$label"   BLOCKING_PROCESS_ACTION=silent_fail   NOTIFY=silent
```

> **Tip:** `BLOCKING_PROCESS_ACTION` controls how to handle running apps (e.g., `prompt_user`, `quit`, `silent_fail`). Always test how your titles behave before broad rollout.

### 2.4 Force install (take over vendor update tools)

Some titles ship their own update tools. You can force a complete replace (download/install) instead:

```bash
#!/bin/bash
label="microsoftedge"
/usr/local/Installomator/Installomator.sh "$label" INSTALL=force NOTIFY=silent
```

## 20.3 Pass-Through Options You'll Actually Use

These options are set as **NAME=VALUE** arguments after the label.

- `BLOCKING_PROCESS_ACTION=` – user prompts vs. silent fail vs. quit.
- `NOTIFY=` – `silent`, `success`, `all` (show dialogs/notifications).
- `LOGO=` – an `.icns` path shown in dialogs.
- `DEBUG=` – `0` (do work), `1` or `2` (no install; test flow and dialogs).
- `REOPEN=` – reopen app after update when appropriate.
- `IGNORE_APP_STORE_APPS=` – skip MAS‑managed titles if set.
- `SYSTEMOWNER=` – for multi‑user/macOS nuances in some deployments.

> You can also change defaults inside the script, but **prefer runtime options** so updates to Installomator don’t overwrite your choices.

## 20.4 Pin Versions Safely (Last-Compatible, Staged Rollouts)

Installomator normally fetches “latest.” To **pin** a specific version (for compatibility or staged rollout), override the label at runtime by providing **both** a version and an explicit vendor URL for that version.

### 4.1 Example: pin a specific swiftDialog build

```bash
#!/bin/bash
label="swiftdialog"
/usr/local/Installomator/Installomator.sh "$label"   appNewVersion="2.4.2"   downloadURL="https://github.com/swiftDialog/swiftDialog/releases/download/v2.4.2/dialog-2.4.2.pkg"   BLOCKING_PROCESS_ACTION=prompt_user NOTIFY=success
```

**Why both?** Many labels determine “latest” dynamically. Supplying `appNewVersion` ensures Installomator compares against *your* target; `downloadURL` points to the exact artifact you want deployed.

### 4.2 Pin across architectures

If a title publishes separate Apple silicon/Intel builds, pin the correct artifact URL for each architecture (or use a label that handles `arm64` vs `x86_64` automatically). In MDM, scope separate policies by Smart Groups or device filters.

## 20.5 Calling from Your MDM (Jamf, Intune, Addigy, Mosyle)

Installomator **ignores the first three Jamf script parameters** (mount point, computer name, user) and reads your label as **Parameter 4**. Provide additional options as subsequent parameters *or* inline as shown below.

### 5.1 Jamf Pro policy (per‑app)

```bash
#!/bin/zsh
# Parameter 4: Installomator label (e.g., 'googlechrome')
# Parameter 5+: Optional NAME=VALUE runtime options

LABEL="$4"
shift 4

/usr/local/Installomator/Installomator.sh "$LABEL" "$@"
exit $?
```

Call this script in a Jamf policy with **Parameter 4** set to a known label and **Parameter 5+** to pass options (for example, `BLOCKING_PROCESS_ACTION=prompt_user`).

### 5.2 Microsoft Intune (shell script deployment)

```bash
#!/bin/zsh
LABEL="zoom"
/usr/local/Installomator/Installomator.sh "$LABEL" NOTIFY=success BLOCKING_PROCESS_ACTION=prompt_user
```

Ensure your Intune shell script runs as **root** and is allowed to run repeatedly on a schedule for ongoing updates.

### 5.3 Addigy / Mosyle

Both support recurring, root‑privileged scripts. Reuse the same approach: store Installomator at `/usr/local/Installomator/`, then schedule your per‑app scripts (or Patchomator, below) on a cadence that fits your patch SLOs.

## 20.6 Managing Labels at Scale

As your application catalog grows, managing labels across your fleet becomes critical for consistent deployment and maintenance.

### Label Inventory and Tracking

**Maintain Label Registry:**

- Document all labels in use across your organization
- Track which labels are standard vs. custom/required
- Version control label configurations and customizations
- Maintain changelog of label additions and removals

**Label Categories:**

- **Standard Labels**: Community-maintained labels from Installomator repository
- **Required Labels**: Applications required for all users (security tools, productivity apps)
- **Optional Labels**: Department-specific or user-requested applications
- **Pinned Labels**: Applications locked to specific versions for compatibility

### Centralized Label Management

**Configuration Management:**

- Store label lists in version control (Git repository)
- Use configuration files to define label sets per department/role
- Automate label deployment via MDM scripts
- Maintain master list of approved labels

**Example Label Configuration File:**

```bash
#!/bin/bash
# label_config.sh - Centralized label configuration

# Required applications for all devices
REQUIRED_LABELS=(
    "googlechrome"
    "firefox"
    "zoom"
    "microsoftedge"
)

# Security tools
SECURITY_LABELS=(
    "suspiciouspackage"
    "malwarebytes"
)

# Developer tools (devices only)
DEV_LABELS=(
    "visualstudiocode"
    "github"
)

# Function to install label set
install_labels() {
    local label_set=("$@")
    for label in "${label_set[@]}"; do
        /usr/local/Installomator/Installomator.sh "$label" \
            NOTIFY=silent \
            BLOCKING_PROCESS_ACTION=silent_fail
    done
}
```

### Label Version Pinning Strategy

**When to Pin Versions:**

- Application compatibility issues with newer versions
- Testing requirements before broad deployment
- Vendor breaking changes in recent releases
- Compliance requirements for specific versions

**Pinning Implementation:**

- Document pinned versions and reasoning
- Review pins quarterly for continued necessity
- Test newer versions in pilot before unpinning
- Maintain pin registry in configuration management

**Example Pinned Deployment:**

```bash
# Pin to specific version for compatibility
/usr/local/Installomator/Installomator.sh slack \
    appNewVersion="4.39.90" \
    downloadURL="https://downloads.slack-edge.com/releases/macos/4.39.90/prod/x64/Slack-4.39.90-macOS.dmg" \
    BLOCKING_PROCESS_ACTION=prompt_user \
    NOTIFY=success
```

### Label Testing and Validation

**Pre-Production Testing:**

- Test new labels in isolated test environment
- Verify installation and update behavior
- Test on multiple macOS versions if applicable
- Validate signature and notarization status

**Production Rollout:**

- Deploy to pilot group first (5-10 devices)
- Monitor installation success rates
- Collect user feedback on application behavior
- Expand to broader deployment after validation

### Label Maintenance Workflow

**Regular Review Process:**

- Monthly review of label library updates
- Test new label versions in staging
- Update production labels based on testing
- Document label changes and rationale

**Deprecation Process:**

- Identify unused or obsolete labels
- Notify stakeholders before removal
- Provide migration path if needed
- Remove from configuration files after grace period

## 20.7 Building Your App Catalog

An application catalog defines which applications are available, how they're deployed, and who has access to them.

### Catalog Structure

**Application Categories:**

- **Required**: Applications installed on all devices automatically
- **Available**: Applications available via self-service or on request
- **Restricted**: Applications requiring approval or special licensing
- **Department-Specific**: Applications for specific business units

**Catalog Metadata:**

- Application name and description
- Installomator label (if applicable)
- Deployment method (Installomator, MDM package, vendor updater)
- Version information and update cadence
- License requirements and restrictions
- Support contacts and documentation links

### Self-Service Catalog

**Implementation Options:**

- Jamf Self Service with Installomator integration
- Munki Managed Software Center
- Custom web portal with MDM API integration
- Third-party self-service solutions

**Catalog Management:**

- Maintain application descriptions and screenshots
- Update availability based on licensing and compatibility
- Track installation requests and approvals
- Monitor installation success rates

### Catalog Automation

**Dynamic Catalog Generation:**

- Generate catalog from Installomator label list
- Integrate with license management systems
- Update availability based on device eligibility
- Automate catalog updates on label changes

**Example Catalog Script:**

```bash
#!/bin/bash
# generate_catalog.sh - Generate application catalog from labels

CATALOG_FILE="/usr/local/share/app_catalog.json"

# Read label list and generate catalog entries
labels=($(grep "^[a-z]" /usr/local/Installomator/Installomator.sh | \
    grep -E "^[a-z][a-z0-9]+\)" | cut -d')' -f1))

{
    echo "{"
    echo "  \"applications\": ["
    for label in "${labels[@]}"; do
        echo "    {"
        echo "      \"label\": \"$label\","
        echo "      \"available\": true"
        echo "    },"
    done
    echo "  ]"
    echo "}"
} > "$CATALOG_FILE"
```

## 20.8 Patchomator: Scan → Configure → Update Everything

**What Patchomator does:** It scans a Mac, maps installed apps to Installomator labels, writes a **configuration plist**, and can then **update anything out of date** (or only a required subset) in one run. It can also respect **ignored** labels.

### 6.1 Install Patchomator alongside Installomator

```bash
#!/bin/bash
curl -L https://raw.githubusercontent.com/Mac-Nerd/patchomator/main/patchomator.sh   -o /usr/local/Installomator/patchomator.sh

sudo chmod 755 /usr/local/Installomator/patchomator.sh
sudo xattr -dr com.apple.quarantine /usr/local/Installomator/patchomator.sh 2>/dev/null || true
```

### 6.2 First run: discover and write a config

```bash
#!/bin/bash
/usr/local/Installomator/patchomator.sh --write
# Config path (default):
#   /Library/Application Support/Patchomator/patchomator.plist
```

This scans for installed apps that Patchomator knows how to map to labels and saves the mapping.

### 6.3 Read/inspect the configuration

```bash
defaults read "/Library/Application Support/Patchomator/patchomator.plist"
```

You’ll see keys for each discovered app path and its corresponding label, plus two arrays: `IgnoredLabels` and `RequiredLabels`.

### 6.4 Ignore certain titles, require others

```bash
# Ignore titles that you manage differently (MAS, vendor updater, etc.)
/usr/bin/defaults write "/Library/Application Support/Patchomator/patchomator.plist"   IgnoredLabels -array "googlechromeenterprise" "zoomgov"

# Ensure these are always updated/reinstalled if missing
/usr/bin/defaults write "/Library/Application Support/Patchomator/patchomator.plist"   RequiredLabels -array "bbedit" "suspiciouspackage"
```

You can also pass these at runtime:

```bash
/usr/local/Installomator/patchomator.sh --ignored "googlechromeenterprise zoomgov"   --required "bbedit suspiciouspackage" --write
```

### 6.5 Update cycle (all discovered, minus ignored)

```bash
/usr/local/Installomator/patchomator.sh --install   --options "BLOCKING_PROCESS_ACTION=prompt_user NOTIFY=success"
```

Patchomator will call Installomator for any out‑of‑date titles, respecting your config. To force updates for a curated set only, populate `RequiredLabels` and add `--ignored "ALL"`.

### 6.6 Quiet/interactive modes and swiftDialog

Patchomator will use **Swift Dialog** for progress if present. To suppress dialogs, pass `--quiet`. For fully unattended windows (overnight), combine `--quiet` with `BLOCKING_PROCESS_ACTION=silent_fail` in `--options`.

## 20.9 Scheduling with LaunchDaemons (MDM-agnostic)

If your MDM doesn’t provide a native scheduler, use a LaunchDaemon to run Patchomator (or per‑app Installomator policies) at regular intervals.

```xml
<!-- /Library/LaunchDaemons/com.example.patchomator.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.example.patchomator</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/Installomator/patchomator.sh</string>
    <string>--install</string>
    <string>--options</string>
    <string>BLOCKING_PROCESS_ACTION=prompt_user NOTIFY=success</string>
  </array>
  <key>StartCalendarInterval</key>
  <array>
    <dict><key>Hour</key><integer>3</integer><key>Minute</key><integer>30</integer></dict>
  </array>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>/var/log/patchomator.stdout.log</string>
  <key>StandardErrorPath</key><string>/var/log/patchomator.stderr.log</string>
</dict>
</plist>
```

Install and load:

```bash
sudo chown root:wheel /Library/LaunchDaemons/com.example.patchomator.plist
sudo chmod 644 /Library/LaunchDaemons/com.example.patchomator.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.example.patchomator.plist
sudo launchctl enable system/com.example.patchomator
sudo launchctl kickstart -k system/com.example.patchomator
```

## 20.10 Logging, Exit Codes, and Troubleshooting

This section addresses common issues encountered when deploying Installomator in enterprise environments, with specific attention to label-specific problems and operational challenges.

### Logging and Diagnostics

**Installomator Log Location:**

- Primary log: `/private/var/log/Installomator.log`
- Tail live during execution: `sudo tail -f /private/var/log/Installomator.log`
- View recent entries: `tail -100 /private/var/log/Installomator.log`

**Log Analysis:**

- Search for errors: `grep -i error /private/var/log/Installomator.log`
- Find specific label executions: `grep "googlechrome" /private/var/log/Installomator.log`
- Check exit codes: `grep "Exit code" /private/var/log/Installomator.log`

**Verbose Debugging:**

- Enable debug mode: `DEBUG=1 /usr/local/Installomator/Installomator.sh googlechrome`
- Debug level 2 (most verbose): `DEBUG=2 /usr/local/Installomator/Installomator.sh googlechrome`
- Capture debug output: `DEBUG=2 /usr/local/Installomator/Installomator.sh googlechrome 2>&1 | tee /tmp/installomator_debug.log`

### Exit Codes

Installomator uses exit codes to indicate success or failure:

- **0**: Success (app installed/updated or already current)
- **1**: Generic error
- **2**: Temporary failure (retry may succeed)
- **3**: Permanent failure (label issue, not retryable)
- **4**: App requires newer macOS version
- **5**: Insufficient disk space
- **6**: App currently running (if `BLOCKING_PROCESS_ACTION=silent_fail`)

**Using Exit Codes in Scripts:**

```bash
#!/bin/bash
if /usr/local/Installomator/Installomator.sh googlechrome NOTIFY=silent; then
    echo "Chrome installation successful"
else
    exit_code=$?
    case $exit_code in
        4) echo "macOS version too old" ;;
        5) echo "Insufficient disk space" ;;
        6) echo "Chrome is running, skipping update" ;;
        *) echo "Installation failed with code $exit_code" ;;
    esac
    exit $exit_code
fi
```

### Common Issues and Solutions

#### Issue: Running Beta Branch Instead of Release

**Symptom**: Unexpected behavior, features not working as documented

**Cause**: Accidentally using `main` branch which is beta/pre-release

**Solution**:

```bash
# Verify you're using release branch
/usr/local/Installomator/Installomator.sh version | grep -i "release\|beta"

# Reinstall from release branch
curl -L https://raw.githubusercontent.com/Installomator/Installomator/release/Installomator.sh \
    -o /usr/local/Installomator/Installomator.sh
sudo chmod 755 /usr/local/Installomator/Installomator.sh
```

#### Issue: Label Not Found or Invalid

**Symptom**: Error message indicating label doesn't exist

**Diagnosis**:

```bash
# List all available labels
/usr/local/Installomator/Installomator.sh | grep -E "^[a-z][a-z0-9]+\)"

# Search for similar label names
/usr/local/Installomator/Installomator.sh | grep -i "chrome"
```

**Solutions**:

- Check label spelling (case-sensitive)
- Verify label exists in Installomator version you're using
- Update Installomator script if label is new
- Check GitHub issues for label status if recently added

#### Issue: Download Failures

**Symptom**: Installation fails with download errors

**Common Causes:**

1. **Network Connectivity:**
   - Check internet connectivity: `ping -c 3 8.8.8.8`
   - Test vendor URL access: `curl -I <download_url>`
   - Verify DNS resolution: `nslookup vendor-domain.com`

2. **Proxy/SSL Inspection:**
   - Corporate proxies may block vendor downloads
   - SSL inspection can break HTTPS connections
   - **Solution**: Whitelist vendor CDNs in proxy configuration
   - Common CDNs to whitelist: `*.googleapis.com`, `*.github.com`, `*.microsoft.com`, etc.

3. **Vendor URL Changes:**
   - Vendor may have changed download URLs
   - Label may not be updated yet
   - **Solution**: Check Installomator GitHub for label updates
   - **Workaround**: Pin specific version with explicit URL

**Debugging Download Issues:**

```bash
# Enable debug mode to see download URLs
DEBUG=1 /usr/local/Installomator/Installomator.sh googlechrome 2>&1 | grep -i "url\|download\|curl"

# Test download URL manually
curl -L -o /tmp/test.dmg "<download_url_from_log>"
```

#### Issue: Wrong Architecture (Intel vs Apple Silicon)

**Symptom**: Installation fails or wrong version installed

**Cause**: Label may default to wrong architecture, or multiple labels exist

**Solutions:**

- Check available labels: Some apps have separate labels (e.g., `googlechrome` vs `googlechromepkg`)
- Verify architecture detection: Installomator should auto-detect, but can be overridden
- Pin specific URL for architecture: Use `downloadURL` to specify exact build

**Example:**

```bash
# For Apple Silicon specifically
/usr/local/Installomator/Installomator.sh googlechrome \
    downloadURL="https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg"
```

#### Issue: Blocking Process Handling

**Symptom**: App installation fails because application is running

**Diagnosis**: Check blocking process action setting

**Solutions:**

- `BLOCKING_PROCESS_ACTION=prompt_user`: User can quit app and continue
- `BLOCKING_PROCESS_ACTION=quit`: Automatically quit app (may lose unsaved work)
- `BLOCKING_PROCESS_ACTION=silent_fail`: Skip installation if app is running (exit code 6)

**Best Practices:**

- Use `prompt_user` for interactive deployments
- Use `silent_fail` for automated/scheduled updates
- Test behavior with applications your organization uses

#### Issue: Signature Verification Failures

**Symptom**: Installation fails with code signing errors

**Causes:**

- Vendor changed signing certificate
- Download corrupted or incomplete
- Label checks wrong signature

**Solutions:**

- Verify download integrity: Check log for download completion
- Update Installomator: Newer versions may have updated signature checks
- Check vendor release notes for signing changes
- Temporarily test with signature verification disabled (not recommended for production)

#### Issue: Patchomator Not Discovering Applications

**Symptom**: `patchomator.sh --write` doesn't find installed applications

**Diagnosis:**

```bash
# Check if Patchomator can find apps
/usr/local/Installomator/patchomator.sh --write --verbose

# Verify Spotlight is working
mdfind "kMDItemContentType == 'com.apple.application-bundle'" | head -5
```

**Solutions:**

- Rebuild Spotlight index: `sudo mdutil -E /`
- Check Spotlight indexing status: `mdutil -s /`
- Verify applications are in standard locations (`/Applications`, not user directories)
- Some apps may not be discoverable if installed in non-standard locations

#### Issue: Patchomator Config Not Applying

**Symptom**: Ignored/Required labels not being respected

**Diagnosis:**

```bash
# Check config file location and contents
defaults read "/Library/Application Support/Patchomator/patchomator.plist"

# Verify config file permissions
ls -la "/Library/Application Support/Patchomator/patchomator.plist"
```

**Solutions:**

- Ensure config file is readable: `sudo chmod 644 "/Library/Application Support/Patchomator/patchomator.plist"`
- Verify plist format is valid: `plutil -lint "/Library/Application Support/Patchomator/patchomator.plist"`
- Regenerate config: `patchomator.sh --write` with explicit ignored/required flags

### Vendor-Specific Label Issues

**Microsoft Applications:**

- May use built-in updaters (Microsoft AutoUpdate)
- Labels may check for updater vs. direct installation
- `INSTALL=force` bypasses updater
- **Best Practice**: Let Microsoft updater handle updates, use Installomator for initial install

**Google Applications:**

- Multiple label variants (Chrome, Chrome Enterprise, Chrome Beta)
- Choose correct label for your deployment method
- Enterprise labels may require different configuration

**Adobe Applications:**

- Complex installation processes
- May require Creative Cloud account
- Some applications not supported by Installomator
- **Alternative**: Use Adobe's deployment tools for enterprise

### Troubleshooting Workflow

**Systematic Troubleshooting Steps:**

1. **Check Logs**: Review Installomator.log for error messages
2. **Verify Label**: Confirm label exists and spelling is correct
3. **Test Manually**: Run label manually with debug output
4. **Check Prerequisites**: Verify network, disk space, permissions
5. **Test Download**: Manually download vendor URL to verify accessibility
6. **Check Version**: Ensure Installomator is up to date
7. **Review GitHub**: Check Installomator GitHub for known issues
8. **Test Alternative**: Try different label or version if available

**Getting Help:**

- Installomator GitHub Issues: https://github.com/Installomator/Installomator/issues
- MacAdmins Slack: #installomator channel
- Review label source code in Installomator.sh for label-specific logic

## 20.11 End-to-End Examples

### 9.1 Fleet‑wide Chrome update (prompt users if running)

```bash
#!/bin/zsh
/usr/local/Installomator/Installomator.sh googlechrome   BLOCKING_PROCESS_ACTION=prompt_user   NOTIFY=success   LOGO="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarAdvanced.icns"
```

### 9.2 Pin Slack to a vetted build, quiet rollout at night

```bash
#!/bin/zsh
/usr/local/Installomator/Installomator.sh slack   appNewVersion="4.39.90"   downloadURL="https://downloads.slack-edge.com/releases/macos/4.39.90/prod/x64/Slack-4.39.90-macOS.dmg"   BLOCKING_PROCESS_ACTION=silent_fail NOTIFY=silent
```

### 9.3 Patchomator nightly: update only a required set

```bash
#!/bin/zsh
/usr/local/Installomator/patchomator.sh --install   --ignored "ALL"   --required "bbedit suspiciouspackage"   --options "BLOCKING_PROCESS_ACTION=prompt_user NOTIFY=success"
```

## Chapter 20 Exercise

**Objective:** Build a safe, repeatable patch pipeline that pins your tooling and updates a required app set nightly.

1. Install Installomator from the **release** branch into `/usr/local/Installomator/`.
2. Install Patchomator alongside it.
3. Run `patchomator.sh --write` to generate a config. Edit the plist to add three titles to `RequiredLabels`.
4. Create a LaunchDaemon that runs nightly at 3:30 a.m. calling `patchomator.sh --install` with `--options "BLOCKING_PROCESS_ACTION=prompt_user NOTIFY=success"`.
5. Test on a pilot group, then increase scope. Inspect `/private/var/log/Installomator.log` for confirmation.

**Stretch goal:** For one app that must remain on a last‑compatible build, convert your policy to a **pinned** install by supplying `appNewVersion` and `downloadURL` explicitly.

## macOS Scripting Tips

- Prefer **runtime options** over editing the script’s defaults; updates won’t clobber your settings.
- Treat labels as code: test new or changed labels on a small pilot smart group before production.
- For user‑interactive updates, provide an obvious **LOGO** and clear success/failure messages.
- Schedule installs when apps are least likely to be running; for creative suites, prefer nights/weekends.
- Keep a small **allowlist** of pinned versions (by title) and document why each is pinned and when to unpin.
- If your MDM supports **fact caching** (or device attributes), publish the last Installomator run timestamp/version for reporting.
- Regularly check the Installomator GitHub repo for new labels or updates to existing ones.
