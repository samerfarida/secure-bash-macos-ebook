# Chapter 20: Application Deployment & Update Automation (Installomator + Patchomator)

## Learning Objectives

By the end of this chapter, you will be able to:

* Install and **pin** a stable (release) copy of Installomator on managed Macs.
* Deploy and update applications at scale using **label-driven** recipes.
* Pass Installomator runtime options for user experience, safety, and logging.
* **Pin app versions safely** (e.g., last‑compatible builds) without tracking GitHub feeds by hand.
* Use **Patchomator** to discover installed apps, build a label configuration, and run unattended update cycles.
* Orchestrate everything from your MDM (Jamf, Intune, Addigy, Mosyle, etc.), including repeatable policies/profiles and LaunchDaemons for scheduling.
* Troubleshoot with logs and exit codes and roll out with confidence.

## Introduction

Installomator is a community-maintained installer/update script that downloads Mac software **directly from vendor sources**, using per‑app “labels” that know where to fetch and how to install each title. You execute a single script with a label (for example, `googlechrome`) and Installomator handles download, verification, process blocking, and install/update logic.

This chapter gives you **practical, step‑by‑step recipes** to deploy Installomator **safely (pinned to the release branch)**, run label‑based installs and updates, and layer **Patchomator** on top to discover apps and keep them current—hands‑off—on your entire fleet. Throughout, we provide copy‑pasteable Bash you can drop into your MDM policies or run locally.

> **Paths used in this chapter**
>
> * Installomator: `/usr/local/Installomator/Installomator.sh`
> * Installomator log: `/private/var/log/Installomator.log`
> * Patchomator config (default): `/Library/Application Support/Patchomator/patchomator.plist`

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

* Detects if Chrome is installed and whether it’s current.
* If the app is running, prompts the user to quit/save work before install.
* Shows a success notification after completion.
* Uses a system icon for branding.

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

* `BLOCKING_PROCESS_ACTION=` – user prompts vs. silent fail vs. quit.
* `NOTIFY=` – `silent`, `success`, `all` (show dialogs/notifications).
* `LOGO=` – an `.icns` path shown in dialogs.
* `DEBUG=` – `0` (do work), `1` or `2` (no install; test flow and dialogs).
* `REOPEN=` – reopen app after update when appropriate.
* `IGNORE_APP_STORE_APPS=` – skip MAS‑managed titles if set.
* `SYSTEMOWNER=` – for multi‑user/macOS nuances in some deployments.

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

## 20.6 Patchomator: Scan → Configure → Update Everything

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

## 20.7 Scheduling with LaunchDaemons (MDM-agnostic)

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

## 20.8 Logging, Exit Codes, and Troubleshooting

* **Installomator log:** `/private/var/log/Installomator.log`. Tail it live while testing:

```bash
sudo tail -f /private/var/log/Installomator.log
```

* **Common pitfalls**
  * Running the **beta** (`main`) script accidentally; always fetch from `release` or a tagged Release.
  * `BLOCKING_PROCESS_ACTION` behavior varies by app: verify with titles your org relies on.
  * Network proxies/SSL inspection can break vendor downloads—whitelist vendor CDNs.
  * Some apps distribute multiple flavors (Intel/Apple silicon, enterprise vs. consumer) that map to **different labels**; choose correctly or pin explicit URLs.
  * For vendor updaters (e.g., Microsoft), labels may use `updateTool`; if you set `INSTALL=force`, the updater is bypassed.

## 20.9 End-to-End Examples

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

* Prefer **runtime options** over editing the script’s defaults; updates won’t clobber your settings.
* Treat labels as code: test new or changed labels on a small pilot smart group before production.
* For user‑interactive updates, provide an obvious **LOGO** and clear success/failure messages.
* Schedule installs when apps are least likely to be running; for creative suites, prefer nights/weekends.
* Keep a small **allowlist** of pinned versions (by title) and document why each is pinned and when to unpin.
* If your MDM supports **fact caching** (or device attributes), publish the last Installomator run timestamp/version for reporting.
* Regularly check the Installomator GitHub repo for new labels or updates to existing ones.
