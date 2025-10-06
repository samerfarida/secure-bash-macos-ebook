# Chapter 16: Signed & Notarized Installer Packages with GUI Elements

## Learning Objectives

By the end of this chapter, you will be able to:

* Build macOS installer packages using `pkgbuild` (component packages) and `productbuild` (distribution packages).
* Sign installer packages correctly with Developer ID certificates and verify signatures.
* Notarize packages using `xcrun notarytool` (API key or keychain profile) and staple tickets with `xcrun stapler`.
* Prepare app payloads for notarization by signing nested binaries and frameworks.
* Add user-friendly preflight prompts and progress UI using **swiftDialog** in a Bash wrapper.
* Design robust preinstall/postinstall scripts and validate prerequisites (disk space, macOS version, running processes).
* Integrate the build → sign → notarize → staple flow into CI (e.g., GitHub Actions) and your MDM rollout.

## Introduction

On macOS, a professional delivery pipeline for software typically culminates in a signed, notarized installer package that end users (and Gatekeeper) can trust. This chapter walks through:

1. Preparing and signing the application payload (codesign all nested content).
2. Building a **component package** (`pkgbuild`) with optional preinstall/postinstall scripts.
3. Combining one or more component packages into a **distribution package** (`productbuild`).
4. Signing the package with your **Developer ID Installer** certificate.
5. Submitting for **notarization** with `xcrun notarytool` and **stapling** the ticket.
6. Providing **GUI prompts** and progress UI with **swiftDialog** in a Bash wrapper for a safe, user-centric experience.

We will focus on **Developer ID** distribution for direct downloads (outside the Mac App Store).

## Prerequisites and Certificates

You need:

* An Apple Developer account with access to **Certificates, Identifiers & Profiles**.
* **Developer ID Application** certificate — used to sign apps and binaries inside your payload (e.g., `.app`, helper tools).  
* **Developer ID Installer** certificate — used to sign `.pkg` installers.  
* Xcode command line tools installed (provides `xcrun`, `codesign`, `notarytool`, `stapler`).

Verify tools:

```bash
xcode-select -p
xcrun --version
codesign --version
```

List available signing identities:

```bash
security find-identity -p codesigning -v
```

Tip: Keep your Developer ID private keys in a **locked keychain** and use a CI-safe keychain if automating.

## Step 1 — Prepare and Sign the App Payload

Before packaging, ensure the app and all nested content are properly signed with **Developer ID Application** and hardened runtime if appropriate.

Directory layout example:

```bash
payload/
└── Applications/
    └── MyApp.app
        ├── Contents/MacOS/MyApp
        ├── Contents/Frameworks/SomeFramework.framework/Versions/A/SomeFramework
        └── Contents/PlugIns/MyAppExtension.appex
```

Sign in dependency order (deep signing can hide problems; prefer explicit signing of each nested binary/framework first):

```bash
# Example variables
APP="/path/to/payload/Applications/MyApp.app"
IDENTITY_APP="Developer ID Application: Your Org, Inc. (TEAMID)"
ENTITLEMENTS="/path/to/entitlements.plist"

# Sign frameworks, helpers, extensions first (examples)
/usr/bin/codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" --sign "$IDENTITY_APP" \
  "$APP/Contents/Frameworks/SomeFramework.framework/Versions/A/SomeFramework"

/usr/bin/codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" --sign "$IDENTITY_APP" \
  "$APP/Contents/PlugIns/MyAppExtension.appex"

# Finally sign the main app bundle
/usr/bin/codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" --sign "$IDENTITY_APP" \
  "$APP"
```

Verify signatures and requirements:

```bash
/usr/bin/codesign --verify --deep --strict --verbose=4 "$APP"
/usr/bin/codesign -dv --verbose=4 "$APP"
```

If you package command-line tools (e.g., `/usr/local/bin/mytool`), sign them as well with the Application identity before packaging.

## Step 2 — Create Preinstall/Postinstall Scripts (Optional)

Installer scripts let you validate or adjust the system before and after files are placed. Create a `scripts/` directory with executable scripts:

```bash
scripts/
├── preinstall
└── postinstall
```

Example `preinstall` (root, non-interactive, fail-fast):

```bash
#!/bin/bash
set -euo pipefail

log() { echo "[preinstall] $*"; }

# $1 generally points to the target volume (e.g., /)
TARGET="${1:-/}"

# Example: require macOS 13.0 or newer
required_major=13
current_major=$(sw_vers -productVersion | awk -F. '{print $1}')

if (( current_major < required_major )); then
  log "Requires macOS 13 or newer; found $(sw_vers -productVersion)"
  exit 1
fi

# Example: ensure 1 GB free space on target
min_kb=$((1024*1024))
free_kb=$(df -k "${TARGET}" | awk 'NR==2{print $4}')
if (( free_kb < min_kb )); then
  log "Insufficient disk space on ${TARGET}"
  exit 1
fi

log "Preinstall checks passed."
exit 0
```

Example `postinstall`:

```bash
#!/bin/bash
set -euo pipefail

log() { echo "[postinstall] $*"; }

# Refresh LaunchServices cache, then open app once (optional)
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/MyApp.app || true

# Example: write a receipt or local config
/usr/bin/defaults write /Library/Preferences/com.example.myapp FirstRunComplete -bool true || true

log "Postinstall complete."
exit 0
```

Make them executable:

```bash
chmod 755 scripts/preinstall scripts/postinstall
```

Guidelines:

* Scripts run as **root** and must be **non-interactive**. Use a **wrapper UI** (see swiftDialog) when you need user consent.  
* Always log to stdout/stderr; output is captured in `/var/log/install.log`.  
* Exit non-zero to abort installation gracefully.

## Step 2.5 — Real‑World Packaging with **munkipkg** (wrap scripts & security tools)

For many enterprise deployments you aren’t shipping a developer app — you’re wrapping a **script** (e.g., `xyz.sh`) or a **security tool** plus configuration files so it can be deployed by Munki/Jamf/MDM and managed like any other package. The fastest, reproducible way to do this is with **munkipkg** (project name: “munki‑pkg”; command: `munkipkg`). munkipkg builds standard Apple installer packages using a simple, Git‑friendly project layout. citeturn0search2turn0search0

### Install munkipkg

Install via Homebrew or from source:

```bash
brew install munki-pkg  # command is `munkipkg`
# or clone https://github.com/munki/munki-pkg and place `munkipkg` on PATH
```

### Create a template project

```bash
munkipkg create SecurityWrapper
cd SecurityWrapper
```

This creates a project with three key directories:

```bash
SecurityWrapper/
├── build-info.plist        # identifier, version, name, etc.
├── payload/                # files that will be installed
└── scripts/                # optional preinstall/postinstall (run as root)
```

> Note: Packages created by `munkipkg` are **normal .pkg files** that work anywhere Apple installer packages work; Munki is not required to install them. citeturn0search2turn0search4

### Example A — Wrap a shell tool `xyz.sh` with a LaunchDaemon

We’ll install the tool to `/usr/local/bin/xyz.sh`, a config to `/Library/Application Support/ExampleInc/xyz/config.json`, and a LaunchDaemon to keep it running.

Create the payload layout:

```bash
mkdir -p payload/usr/local/bin
mkdir -p "payload/Library/Application Support/ExampleInc/xyz"
mkdir -p payload/Library/LaunchDaemons

# Place your files
cp /path/to/xyz.sh payload/usr/local/bin/
cp configs/config.json "payload/Library/Application Support/ExampleInc/xyz/"

# Create a minimal LaunchDaemon
cat > payload/Library/LaunchDaemons/com.example.xyz.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.example.xyz</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/xyz.sh</string>
    <string>--config</string>
    <string>/Library/Application Support/ExampleInc/xyz/config.json</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict>
</plist>
PLIST
```

Add a `postinstall` script to set permissions and load the daemon:

```bash
cat > scripts/postinstall <<'SCRIPT'
#!/bin/bash
set -euo pipefail

chmod 755 "/usr/local/bin/xyz.sh"
chown root:wheel "/usr/local/bin/xyz.sh"
chmod 644 "/Library/LaunchDaemons/com.example.xyz.plist"
chown root:wheel "/Library/LaunchDaemons/com.example.xyz.plist"

# Load (or bootstrap) the daemon
if launchctl version | grep -q '\\bSystem\\b'; then
  /bin/launchctl bootout system /Library/LaunchDaemons/com.example.xyz.plist 2>/dev/null || true
  /bin/launchctl bootstrap system /Library/LaunchDaemons/com.example.xyz.plist
  /bin/launchctl enable system/com.example.xyz
else
  /bin/launchctl unload /Library/LaunchDaemons/com.example.xyz.plist 2>/dev/null || true
  /bin/launchctl load -w /Library/LaunchDaemons/com.example.xyz.plist
fi

exit 0
SCRIPT
chmod 755 scripts/postinstall
```

Set metadata in `build-info.plist` (identifier should be globally unique and stable; version should follow semver):

```xml
<!-- edit SecurityWrapper/build-info.plist -->
<key>identifier</key><string>com.example.pkg.xyz</string>
<key>name</key><string>XYZ Tool</string>
<key>version</key><string>1.0.0</string>
```

Build the package:

```bash
munkipkg .
# output: build/XYZ Tool-1.0.0.pkg
```

### Example B — Wrap a third‑party **security app** with extra configs

If a vendor ships a signed `.app` or CLI tool, place it under `payload/Applications/VendorApp.app` (or under `/Library/Application Support/Vendor/App/…` if CLI‑only) **without modifying its signature**, and add your org’s configuration files beside it. Use `postinstall` to apply permissions, write out defaults, seed license keys, or register launch assets. `munkipkg` will set `scripts/*` executable on build, simplifying project setup.

Example project layout:

```bash
payload/
└── Applications/
    └── Sentinel.app               # vendor-signed, unmodified
payload/Library/Application Support/ExampleInc/Sentinel/config.json
scripts/postinstall                 # writes org config, kicks service
```

Sample `scripts/postinstall` to apply configuration safely:

```bash
#!/bin/bash
set -euo pipefail

APP="/Applications/Sentinel.app"
CFG_DIR="/Library/Application Support/ExampleInc/Sentinel"
mkdir -p "$CFG_DIR"
chmod 755 "$CFG_DIR"; chown root:wheel "$CFG_DIR"

# Copy a default config only if the admin hasn't customized it
if [[ ! -f "$CFG_DIR/config.json" && -f "$CFG_DIR/config.json.default" ]]; then
  cp -p "$CFG_DIR/config.json.default" "$CFG_DIR/config.json"
fi

# Trigger the app's built‑in registration/activation if available
if [[ -x "$APP/Contents/MacOS/Sentinel" ]]; then
  "$APP/Contents/MacOS/Sentinel" --register || true
fi

# Refresh LaunchServices cache (optional)
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" || true
exit 0
```

### Signing, notarizing, and deploying munkipkg builds

`munkipkg` uses Apple’s `pkgbuild` under the hood. You can sign and notarize the output exactly as shown earlier in this chapter:

```bash
# Sign at build time (recommended):
PRODUCTSIGN_ID="Developer ID Installer: Your Org, Inc. (TEAMID)"
productsign --sign "$PRODUCTSIGN_ID" "build/XYZ Tool-1.0.0.pkg" "dist/XYZ-1.0.0-signed.pkg"

# Notarize and staple
xcrun notarytool submit "dist/XYZ-1.0.0-signed.pkg" --key "$API_KEY_PATH" --key-id "$KEY_ID" --issuer "$ISSUER_ID" --wait
xcrun stapler staple "dist/XYZ-1.0.0-signed.pkg"
```

Deployment notes:

* These packages are ideal for Munki/Jamf/MDM. They install a receipt and can be versioned by bumping `build-info.plist` → `version`.
* For **script‑only** jobs, consider a **payload‑free** package built with `pkgbuild --nopayload` and scripts only; Munki sees/versions these by their receipt just like other pkgs. citeturn0search8
* Keep configs out of the app bundle when possible so you can update configs without touching the vendor signature.

Troubleshooting:

* Make sure your `identifier` stays constant across releases; only bump `version` to trigger updates in Munki/Jamf.
* `munkipkg` will mark `scripts/preinstall` and `scripts/postinstall` executable at build time; you don’t need to `chmod` them in‑repo.

* Use `pkgutil --expand` and `lsbom` to inspect package contents and verify scripts are included as expected.

Build a component package by pointing `--root` at the payload root and (optionally) `--scripts` to your scripts directory.

```bash
IDENTITY_INSTALLER="Developer ID Installer: Your Org, Inc. (TEAMID)"

pkgbuild \
  --root "payload" \
  --identifier "com.example.myapp" \
  --version "1.2.3" \
  --install-location "/" \
  --scripts "scripts" \
  --sign "$IDENTITY_INSTALLER" \
  "build/MyApp-1.2.3-component.pkg"
```

Notes:

* `--identifier` must be globally unique and stable across versions.  
* Use a **semantic version** for `--version`.  
* `--install-location "/"` means paths in `payload/` are absolute (e.g., `payload/Applications/...`).  
* You can build **unsigned** first, then sign later with `productsign` (not required if you pass `--sign`).

Verify component package:

```bash
pkgutil --check-signature "build/MyApp-1.2.3-component.pkg"
```

## Step 4 — Create a Distribution Package with `productbuild`

For multi-component installers or GUI customizations, create a distribution package using an XML distribution file. Minimal example (`distribution.xml`):

```xml
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>MyApp Installer</title>
  <options customize="never" require-scripts="false" />
  <domains enable_localSystem="true" />
  <pkg-ref id="com.example.myapp">#myapp</pkg-ref>
  <choices-outline>
    <line choice="default">
      <line choice="myapp"/>
    </line>
  </choices-outline>
  <choice id="default"/>
  <choice id="myapp" visible="true" title="MyApp">
    <pkg-ref id="com.example.myapp"/>
  </choice>
  <pkg-ref id="com.example.myapp" version="1.2.3" onConclusion="None">MyApp-1.2.3-component.pkg</pkg-ref>
</installer-gui-script>
```

Build the distribution and sign it:

```bash
productbuild \
  --distribution "distribution.xml" \
  --resources "resources" \
  --package-path "build" \
  --sign "$IDENTITY_INSTALLER" \
  "dist/MyApp-1.2.3-Installer.pkg"
```

Quick inspection helpers:

```bash
pkgutil --expand "dist/MyApp-1.2.3-Installer.pkg" /tmp/expanded_pkg
plutil -p /tmp/expanded_pkg/Distribution | head -40 || cat /tmp/expanded_pkg/Distribution
pkgutil --packages | grep com.example.myapp || true
```

If you only have a single component package and no need for a distribution GUI, you can distribute the signed component `.pkg` directly.

## Step 5 — Notarize with `xcrun notarytool` and Staple

Apple’s notarization service scans the installer for malware and verifies signatures. Use an **App Store Connect API key** or a **keychain profile**.

### Option A: API Key (recommended for CI)

```bash
# Files from Apple Developer portal
KEY_ID="ABCD123456"
ISSUER_ID="01234567-89ab-cdef-0123-456789abcdef"
API_KEY_PATH="$HOME/AuthKey_ABCD123456.p8"

xcrun notarytool submit "dist/MyApp-1.2.3-Installer.pkg" \
  --key "$API_KEY_PATH" \
  --key-id "$KEY_ID" \
  --issuer "$ISSUER_ID" \
  --wait
```

### Option B: Keychain Profile (interactive setup once)

```bash
# Store credentials for reuse (one-time)
xcrun notarytool store-credentials "AC_PROFILE" \
  --apple-id "dev@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"

# Submit later using the saved profile
xcrun notarytool submit "dist/MyApp-1.2.3-Installer.pkg" \
  --keychain-profile "AC_PROFILE" \
  --wait
```

Retrieve logs if needed:

```bash
xcrun notarytool history --keychain-profile "AC_PROFILE"
xcrun notarytool log <REQUEST-UUID> --keychain-profile "AC_PROFILE"
```

When notarization succeeds, **staple** the ticket to the package:

```bash
xcrun stapler staple "dist/MyApp-1.2.3-Installer.pkg"
```

Validate:

```bash
spctl -a -vvv -t install "dist/MyApp-1.2.3-Installer.pkg"
pkgutil --check-signature "dist/MyApp-1.2.3-Installer.pkg"
```

## Step 6 — A User-Friendly Wrapper with swiftDialog

Installer scripts must be non-interactive, so surface UX with a **wrapper** that runs before the `installer` command. The wrapper checks prerequisites, captures consent, then proceeds.

Install swiftDialog (via your MDM or Homebrew) and reference its binary (often `/usr/local/bin/dialog` or `/usr/bin/dialog` on newer Homebrew).

Example **preflight + progress** wrapper (`install_myapp.sh`):

```bash
#!/bin/bash
set -euo pipefail

DIALOG="/usr/local/bin/dialog" # adjust path as needed
PKG="dist/MyApp-1.2.3-Installer.pkg"
ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarInstallerIcon.icns"

need_space_gb=1
available_gb=$(df -g / | awk 'NR==2{print $4}')
os_major=$(sw_vers -productVersion | awk -F. '{print $1}')

# Preflight checks
if (( available_gb < need_space_gb )); then
  "$DIALOG" --title "MyApp Installer" \
            --message "At least ${need_space_gb} GB free is required. You have ${available_gb} GB. Please free space and try again." \
            --icon "$ICON" \
            --button1text "OK"
  exit 1
fi

if (( os_major < 13 )); then
  "$DIALOG" --title "MyApp Installer" \
            --message "MyApp requires macOS 13 or newer." \
            --icon "$ICON" \
            --button1text "OK"
  exit 1
fi

# Consent prompt
"$DIALOG" --title "Install MyApp" \
          --message "This will install MyApp and may request admin authorization. Continue?" \
          --icon "$ICON" \
          --button1text "Install" \
          --button2text "Cancel" || exit 1

# Progress UI
PIDFILE=$(mktemp)
"$DIALOG" --title "Installing MyApp" \
          --message "Please wait while MyApp is installed..." \
          --icon "$ICON" \
          --progress \
          --progresstext "Starting..." \
          --commandfile "$PIDFILE" &
DIALOG_PID=$!

# Start install
{
  echo "progress: 10"
  echo "progresstext: Validating package..."
  sleep 0.5
  echo "progress: 30"
  echo "progresstext: Requesting authorization..."
  sleep 0.5
  sudo /usr/sbin/installer -pkg "$PKG" -target /
  echo "progress: 90"
  echo "progresstext: Finalizing..."
  sleep 0.5
  echo "progress: 100"
  echo "message: Installation complete."
} > "$PIDFILE"

wait $DIALOG_PID || true
rm -f "$PIDFILE"

"$DIALOG" --title "MyApp Installer" \
          --message "Installation complete." \
          --icon "$ICON" \
          --button1text "OK"
```

Notes:

* `--commandfile` allows dynamic progress updates.  
* Gatekeeper and Authorization UI are still enforced by macOS as needed (admin prompts, etc.).  
* Run the wrapper from a management tool (MDM policy, Jamf Script, Munki preflight, Self Service, etc.).

## Verification and Troubleshooting

Common checks:

```bash
# Verify installer signature and cert chain
pkgutil --check-signature "dist/MyApp-1.2.3-Installer.pkg"

# Gatekeeper assessment (install context)
spctl -a -vvv -t install "dist/MyApp-1.2.3-Installer.pkg"

# Expand to inspect distribution and component pkgs
pkgutil --expand "dist/MyApp-1.2.3-Installer.pkg" /tmp/expanded
ls /tmp/expanded

# Inspect payload file map and scripts
ls bomutil || true # consider lsbom if installed
lsbom /tmp/expanded/*.bom | head -50 || true

# Installation log
tail -n 200 /var/log/install.log
```

If notarization fails:

* Retrieve the **notary log** to pinpoint unsigned or invalid binaries.  
* Ensure all nested executables are signed with **Developer ID Application** and **hardened runtime**.  
* Avoid `--deep` as a crutch; explicitly sign nested items.  
* Rebuild, re-sign, and re-submit.

## CI: Automating Build → Sign → Notarize → Staple

A minimal CI flow (pseudo-Bash) suitable for GitHub Actions (macOS runner):

```bash
set -euo pipefail

VERSION="1.2.3"
IDENTITY_APP="Developer ID Application: Your Org, Inc. (TEAMID)"
IDENTITY_INSTALLER="Developer ID Installer: Your Org, Inc. (TEAMID)"
KEY_ID="${KEY_ID:?}"
ISSUER_ID="${ISSUER_ID:?}"
API_KEY_PATH="${API_KEY_PATH:?}"

# 1) Sign the app payload (scripts omitted for brevity)

# 2) Build component
pkgbuild --root payload \
  --identifier com.example.myapp \
  --version "$VERSION" \
  --install-location "/" \
  --scripts scripts \
  --sign "$IDENTITY_INSTALLER" \
  "build/MyApp-$VERSION-component.pkg"

# 3) Build distribution
productbuild \
  --distribution distribution.xml \
  --resources resources \
  --package-path build \
  --sign "$IDENTITY_INSTALLER" \
  "dist/MyApp-$VERSION-Installer.pkg"

# 4) Notarize + wait
xcrun notarytool submit "dist/MyApp-$VERSION-Installer.pkg" \
  --key "$API_KEY_PATH" \
  --key-id "$KEY_ID" \
  --issuer "$ISSUER_ID" \
  --wait

# 5) Staple
xcrun stapler staple "dist/MyApp-$VERSION-Installer.pkg"

# 6) Verify
spctl -a -vvv -t install "dist/MyApp-$VERSION-Installer.pkg"
pkgutil --check-signature "dist/MyApp-$VERSION-Installer.pkg"
```

Security recommendations:

* Use a **temporary login keychain** in CI and import certificates with `security import` and `-T /usr/bin/codesign`.  
* Restrict API key scope in App Store Connect; rotate keys regularly.  
* Never echo secrets; use CI secret stores.

## Chapter 16 Exercise

**Goal:** Build a signed, notarized installer with a preflight GUI wrapper.

1. Create a simple payload: an app in `payload/Applications/DemoApp.app` containing a signed shell tool in `Contents/MacOS/demo`.  
2. Write `preinstall` and `postinstall` scripts to validate macOS version ≥ 13 and write a completion flag.  
3. Build a signed component `.pkg` with `pkgbuild`.  
4. Create a distribution `.pkg` with `productbuild`, sign it, and notarize it with `notarytool --wait`.  
5. Staple the package, verify with `spctl` and `pkgutil`.  
6. Write a swiftDialog wrapper that:
   * Checks for ≥ 1 GB free space and macOS ≥ 13
   * Asks for user consent
   * Runs `installer` and shows progress
7. Bonus: Integrate the flow into your CI and publish the artifact.

8. **Alt path (munkipkg):** Create a `SecurityWrapper` project with `munkipkg` that deploys a script (`xyz.sh`) plus a LaunchDaemon and a JSON config. Build, then sign + notarize the resulting pkg. Verify that the LaunchDaemon runs your script on boot and that Munki/Jamf detects version bumps when you change `build-info.plist`.

## macOS Scripting Tips

* Prefer **API key** authentication with `notarytool` for automation.  
* For “wrap and ship” deployments, prefer a **munkipkg** project: clean Git history, reproducible outputs, and standard receipts recognized by Munki/Jamf. citeturn0search2
* Sign nested content explicitly before signing the app bundle.  
* Keep **identifiers stable** across versions; version numbers should be semver-like.  
* For CLI-only tools, consider installing into `/usr/local/bin` or `/opt/<vendor>/bin` and update PATH via a profile.  
* Use **`pkgutil --expand`** and **`lsbom`** to audit package contents; keep BOMs deterministic for reproducible builds.  
* Don’t prompt users inside installer scripts; surface UX in a **wrapper** like swiftDialog.  
* Verify final artifacts on a clean test machine (or VM) that has never seen your certs before.
