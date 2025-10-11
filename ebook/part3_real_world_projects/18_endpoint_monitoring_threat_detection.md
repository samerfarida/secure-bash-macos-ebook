# Chapter 18: Endpoint Monitoring & Threat Detection

## Learning Objectives

By the end of this chapter, you will be able to:

- Deploy and run osquery on macOS reliably.
- Enable and tune evented telemetry (process and file events) using Endpoint Security.
- Write practical osquery queries and schedules for threat detection and investigation.
- Forward results to a SIEM (Splunk, Elastic, Chronicle, etc.) using supported logger plugins or forwarders.
- Correlate osquery with macOS unified logging (`log show`/`log stream`) during incident response.
- Operate safely at scale: performance, privacy, and Full Disk Access (FDA) considerations.

## Introduction

Osquery exposes macOS as a relational database you can query with SQL. For endpoint monitoring, its *evented* tables (those ending in `_events`) capture activity between scheduled intervals crucial for short‑lived processes and file changes that snapshots miss. On macOS 10.15+ the most powerful telemetry source is the **Endpoint Security (ES)** framework. When properly configured, osquery consumes ES notifications to populate event tables with low overhead suitable for enterprise fleets.

This chapter walks through **installation**, **hardening**, **configuration**, **high‑signal queries**, and **log forwarding** patterns that map directly to real-world threat detection and DFIR workflows.

## Installing osquery on macOS

Use the official macOS installer package for fleet deployments, which lays down the app bundle, symlinks, example config, and a sample LaunchDaemon.

```bash
# Install the official package, then perform first‑run steps
sudo osqueryctl start                        # helper to stage config + LaunchDaemon
# or, do it manually:
sudo cp /var/osquery/osquery.example.conf /var/osquery/osquery.conf
sudo cp /var/osquery/io.osquery.agent.plist /Library/LaunchDaemons
sudo launchctl load /Library/LaunchDaemons/io.osquery.agent.plist

# Interactive shell for prototyping:
osqueryi
```

### Ensure config/log directories exist with correct ownership/permissions

sudo install -d -m 0755 -o root -g wheel /var/osquery /var/log/osquery

### LaunchDaemon plist example

Save as `/Library/LaunchDaemons/io.osquery.agent.plist` with root:wheel ownership and mode `0644`.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>io.osquery.agent</string>
    <key>ProgramArguments</key>
    <array>
      <string>/opt/osquery/lib/osquery.app/Contents/MacOS/osqueryd</string>
      <string>--flagfile=/var/osquery/osquery.flags</string>
      <string>--config_path=/var/osquery/osquery.conf</string>
      <string>--pidfile=/var/osquery/osqueryd.pid</string>
      <string>--force</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/osquery/osqueryd.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/osquery/osqueryd.stderr.log</string>
    <key>AbandonProcessGroup</key>
    <true/>
  </dict>
</plist>
```

>After saving, load with launchctl bootstrap system /Library/LaunchDaemons/io.osquery.agent.plist and verify with launchctl print system/io.osquery.agent.

**Default paths (osquery 5.x):**

- App bundle: `/opt/osquery/lib/osquery.app`
- Symlinks: `/usr/local/bin/osqueryi` (shell), `/usr/local/bin/osqueryctl`
- Config examples: `/private/var/osquery/*.conf`
- Logs: `/private/var/log/osquery/`

Note: On macOS, `/var` is a symlink to `/private/var`. Osquery may document paths with either prefix; both refer to the same location.

> Apple silicon & Intel: the official macOS package is a **universal** binary; no Rosetta is required.
>
> Note: The installer does **not** auto‑load the daemon; use `osqueryctl start` or install the LaunchDaemon as shown.

### Launching the daemon (modern `launchctl` on macOS 11+)

While `launchctl load` still works, Apple recommends the newer subcommands:

```bash
# Load the LaunchDaemon into the system domain and start it
sudo launchctl bootstrap system /Library/LaunchDaemons/io.osquery.agent.plist
sudo launchctl enable system/io.osquery.agent
sudo launchctl kickstart -k system/io.osquery.agent

# To unload/disable later
sudo launchctl bootout system /Library/LaunchDaemons/io.osquery.agent.plist
```

#### Quick smoke tests

Before proceeding, verify that event publishers and tables are active:

```bash
# Publisher/subscriber health
osqueryi --line "SELECT name,publisher,active,events FROM osquery_events;"

# Check if Endpoint Security process events are flowing
osqueryi --line "SELECT time,pid,parent,path FROM es_process_events ORDER BY time DESC LIMIT 3;"

# Confirm File Integrity Monitoring (FIM) events
osqueryi --line "SELECT * FROM file_events ORDER BY time DESC LIMIT 3;"
```

## Hardening & prerequisites (macOS)

### Full Disk Access (FDA)

Give **Full Disk Access** to the `osqueryd` binary when you need Endpoint Security–backed events or access to protected system areas. For managed fleets, deploy a Privacy Preferences Policy Control (PPPC) profile that grants FDA to the osquery daemon bundle path: `/opt/osquery/lib/osquery.app/Contents/MacOS/osqueryd`.

**Important FDA behavior on macOS:**

- When testing interactively, `osqueryi` inherits Full Disk Access (FDA) from the terminal app (e.g., Terminal or iTerm). Grant FDA to your terminal if you expect `es_*` tables to populate during ad‑hoc testing.
- When running as a service, FDA must be granted directly to the daemon executable at `/opt/osquery/lib/osquery.app/Contents/MacOS/osqueryd` via a PPPC profile (SystemPolicyAllFiles). Granting FDA to `launchctl` or the parent process is not sufficient; restart `osqueryd` after the profile is applied.
- In managed fleets, prefer a PPPC (TCC) payload that targets the bundle identifier **`io.osquery.agent`** (or the executable path above) with the `SystemPolicyAllFiles` authorization set to `Allow`.

### PPPC (Full Disk Access) mobileconfig example

The following **TCC/PPPC** profile grants Full Disk Access (SystemPolicyAllFiles) to the osquery daemon. Replace the `PAYLOAD-UUID-*` placeholders and the `CodeRequirement` with the value from:

```bash
codesign -dr - /opt/osquery/lib/osquery.app
```

Save as `osquery-fda.mobileconfig` and deploy via your MDM.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>PayloadContent</key>
    <array>
      <dict>
        <key>PayloadType</key>
        <string>com.apple.TCC.configuration-profile-policy</string>
        <key>PayloadVersion</key>
        <integer>1</integer>
        <key>PayloadIdentifier</key>
        <string>com.example.pppc.osquery.PAYLOAD-UUID-1</string>
        <key>PayloadUUID</key>
        <string>PAYLOAD-UUID-1</string>
        <key>PayloadDisplayName</key>
        <string>PPPC: osqueryd Full Disk Access</string>
        <key>Services</key>
        <dict>
          <key>SystemPolicyAllFiles</key>
          <array>
            <dict>
              <key>Identifier</key>
              <string>io.osquery.agent</string>
              <key>IdentifierType</key>
              <string>bundleID</string>
              <key>CodeRequirement</key>
              <string>REPLACE-WITH-CODESIGN-REQUIREMENT</string>
              <key>Authorization</key>
              <string>Allow</string>
              <key>Comment</key>
              <string>Grant FDA to osquery daemon</string>
            </dict>
            <dict>
              <key>Identifier</key>
              <string>/opt/osquery/lib/osquery.app/Contents/MacOS/osqueryd</string>
              <key>IdentifierType</key>
              <string>path</string>
              <key>Authorization</key>
              <string>Allow</string>
              <key>Comment</key>
              <string>Path-based FDA as fallback</string>
            </dict>
          </array>
        </dict>
      </dict>
    </array>
    <key>PayloadDisplayName</key>
    <string>PPPC: osqueryd</string>
    <key>PayloadIdentifier</key>
    <string>com.example.profile.osquery.PAYLOAD-UUID-ROOT</string>
    <key>PayloadOrganization</key>
    <string>Your Company</string>
    <key>PayloadRemovalDisallowed</key>
    <false/>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>PAYLOAD-UUID-ROOT</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
  </dict>
</plist>
```

> Tip: Many MDMs (Jamf, Kandji, Mosyle, Intune) render PPPC in their UI. Use the profile above only when you need a raw .mobileconfig.
>
> After granting FDA via PPPC, **restart `osqueryd`** (or use `launchctl kickstart -k system/io.osquery.agent`) or Endpoint Security tables will remain empty until the daemon restarts.

### Entitlements and signing

Official builds of osquery are code‑signed/notarized and include the **Endpoint Security client entitlement** needed to subscribe to ES events. Use official packages for production; custom‑built binaries must be signed, notarized, and provisioned with the proper entitlement to receive ES events.

## Configuration: flags, schedules, and packs

Osquery’s behavior is mostly controlled via a **flagfile** and a **JSON configuration**. On macOS, place the flagfile at `/var/osquery/osquery.flags` and the primary JSON at `/var/osquery/osquery.conf`.

### Minimal flagfile for evented telemetry and file output

```bash
# /var/osquery/osquery.flags
--config_path=/var/osquery/osquery.conf
--disable_events=false
--disable_endpointsecurity=false        # EndpointSecurity-backed events (macOS 10.15+)
--disable_endpointsecurity_fim=false    # ES-backed FIM: enables es_process_file_events
--enable_file_events=true               # FSEvents-backed FIM: enables file_events
--logger_plugin=filesystem              # write JSON to /var/log/osquery/
--logger_path=/var/log/osquery/
--logger_mode=0640
--logger_rotate=true                    # built-in rotation
--logger_rotate_size=26214400           # 25MB per file
--logger_rotate_max_files=25
--host_identifier=hostname
--schedule_splay_percent=10
--events_expiry=3600
--events_max=50000
--utc=true
--verbose=false
```

> Version note: `es_process_file_events` requires a recent 5.x build. If that table is empty while `es_process_events` is populated (and FDA is granted), confirm your osquery version with `osqueryd --version` and upgrade if needed.
>
> On macOS, you can collect FIM two ways: `file_events` (FSEvents) and `es_process_file_events` (Endpoint Security with process context). Both respect the `file_paths`/`exclude_paths` configuration. Enable one or both depending on your needs and storage budget.

#### File Integrity Monitoring (FIM) pattern tips

When defining `file_paths`, remember:

- `%` matches one directory level; `%%` matches recursively.
- You cannot match inside a single path segment (e.g., `/tmp/%%/foo` is invalid).
- Files generally must exist at least once before they can be monitored.

These rules come directly from osquery’s file monitoring engine and will save debugging time.

### Adding a TLS logger/config (optional)

If you run a central osquery manager (e.g., Fleet, your own TLS endpoint), enable TLS plugins:

```bash
# Add to /var/osquery/osquery.flags when using TLS plugins
--tls_hostname=osquery.yourcompany.tld:443
--config_plugin=tls
--logger_plugin=filesystem,tls
--distributed_plugin=tls
--enroll_secret_path=/var/osquery/enroll.secret
--tls_server_certs=/var/osquery/ca.pem
--disable_distributed=false
--distributed_interval=60
```

### Base configuration with schedules and packs

```json
{
  "options": {
    "disable_events": "false"
  },
  "schedule": {
    "process_snapshot": {
      "query": "SELECT pid, parent, name, path, start_time FROM processes;",
      "interval": 600,
      "snapshot": true
    },
    "listening_ports": {
      "query": "SELECT pid, address, port, protocol, state FROM listening_ports;",
      "interval": 300
    },
    "fim_events": {
      "query": "SELECT * FROM file_events;",
      "interval": 300,
      "removed": false
    },
    "es_proc_events": {
      "query": "SELECT time, pid, parent, path, signing_id, team_id FROM es_process_events;",
      "interval": 300,
      "removed": false
    },
    "es_fim_events": {
      "query": "SELECT * FROM es_process_file_events;",
      "interval": 300,
      "removed": false
    }
  },
  "file_paths": {
    "binaries": [ "/Applications/%", "/usr/local/bin/%", "/usr/bin/%", "/Library/PrivilegedHelperTools/%" ],
    "configs":  [ "/Library/LaunchAgents/%", "/Library/LaunchDaemons/%", "/etc/%" ]
  },
  "exclude_paths": {
    "configs": [ "/Library/LaunchAgents/com.apple.%" ]
  }
}
```

> You can also read multiple configuration files from a directory such as `/etc/osquery/osquery.conf.d/` (merged in lexical order) by pointing `--config_path` to that directory. This is useful for modular configuration management.
>
> `file_events` requires that paths be listed under `file_paths`; osquery buffers and emits the events when the scheduled query runs. On macOS, file change notifications come from FSEvents/ES depending on configuration.

## Practical detection queries (macOS)

Below are high‑signal examples designed for production schedules and ad‑hoc investigations. Test on a pilot group before broad rollout.

### 1) New or modified LaunchDaemons/Agents (persistence)

```sql
SELECT
  datetime(time, 'unixepoch') AS ts,
  action,
  path,
  uid,
  gid,
  mode
FROM file_events
WHERE path LIKE '/Library/LaunchDaemons/%'
   OR path LIKE '/Library/LaunchAgents/%';
```

### 2) Unsigned or ad‑hoc‑signed process launches from user‑writable locations

```sql
-- Join Endpoint Security process events with code signing metadata
SELECT
  datetime(e.time, 'unixepoch') AS ts,
  e.pid,
  e.parent,
  e.path,
  s.authority AS signing_authority,
  s.team_identifier AS team_id,
  s.signed
FROM es_process_events AS e
LEFT JOIN signature AS s ON s.path = e.path
WHERE e.path LIKE '/Users/%/Downloads/%'
   OR e.path LIKE '/Users/%/Library/%'
   OR e.path LIKE '/private/tmp/%'
   OR e.path LIKE '/Volumes/%'
ORDER BY e.time DESC
LIMIT 100;
```

### 3) First‑seen binaries (simple prevalence)

```sql
WITH execs AS (
  SELECT path, MIN(time) AS first_seen
  FROM es_process_events
  GROUP BY path
)
SELECT datetime(first_seen, 'unixepoch') AS first_seen_utc, path
FROM execs
ORDER BY first_seen ASC
LIMIT 200;
```

### 4) Unusual parent/child relationships (living‑off‑the‑land)

```sql
SELECT
  datetime(e.time, 'unixepoch') AS ts,
  e.parent,
  p.name AS parent_name,
  e.pid,
  e.path AS child_path
FROM es_process_events e
LEFT JOIN processes p ON p.pid = e.parent
WHERE parent_name IN ('osascript', 'bash', 'zsh', 'python3', 'curl', 'sh')
  AND e.path NOT LIKE '/Applications/%'
ORDER BY e.time DESC
LIMIT 200;
```

### 5) Network listeners that appeared recently

```sql
SELECT
  p.pid,
  p.name,
  p.path,
  l.address,
  l.port,
  l.protocol
FROM listening_ports AS l
JOIN processes AS p USING (pid)
WHERE p.start_time > strftime('%s','now') - 600
ORDER BY p.start_time DESC;
```

### 6) Fileless or transient execution hints

```sql
SELECT
  datetime(time, 'unixepoch') AS ts,
  pid,
  parent,
  path,
  cmdline
FROM es_process_events
WHERE cmdline LIKE '%python -c%'
   OR cmdline LIKE '%osascript -e%'
   OR cmdline LIKE '%/bin/sh -c%'
ORDER BY time DESC
LIMIT 200;
```

## macOS logging for correlation (Unified Logging)

The macOS **unified logging** system (Console app, `log show`, `log stream`) complements osquery during investigations. Example workflows:

```bash
# Live stream limited to osqueryd
sudo log stream --process osqueryd --level info

# Time-bounded pull with a predicate
sudo log show --last "2h" --predicate 'process == "osqueryd" OR subsystem == "com.apple.EndpointSecurity"'
```

Tips:

- Use tight time windows and predicates to reduce noise.
- Capture both osquery **status logs** and **results logs** in your SIEM; status logs are invaluable when debugging event pipelines.
- For near–real‑time triage, tail `/var/log/osquery/osqueryd.results.log` while streaming `log stream` in another terminal.

## Forwarding osquery results to your SIEM

There are two common patterns:

1. **Filesystem + forwarder** (simple, robust). Keep `--logger_plugin=filesystem`, then ship JSON logs from `/var/log/osquery/` with your existing forwarder:
   - **Splunk Universal Forwarder** `inputs.conf`:

     ```bash
     [monitor:///var/log/osquery/osqueryd.results.log]
     index = main
     sourcetype = osquery:results
     ```

     >If your fleet writes to `osqueryd.INFO/.WARNING` files instead, monitor those as well.

   - **Logstash** (Elastic):

     ```bash
     input { file { path => "/var/log/osquery/osqueryd.results.log" codec => "json" } }
     output { elasticsearch { hosts => "https://your-es:9200" } }
     ```

2. **TLS logger/config** (managed osquery). Use `--logger_plugin=filesystem,tls` and point at your TLS endpoint; ensure `--tls_server_certs` (or a trust store) is set. This reduces local file handling and centralizes configuration/labels.

Operational tips:

- Set `--host_identifier=uuid` if DHCP renames laptops frequently.
- Rotate logs on disk with `--logger_rotate=true` and tune `--logger_rotate_size`.
- Use **snapshot** logs for periodic asset baselines (e.g., `processes`, `launchd`), **differential/event** logs for high‑churn tables.
- Results vs. status logs: results are written to `/var/log/osquery/osqueryd.results.log`; status/debug to `/var/log/osquery/osqueryd.INFO/.WARNING` or `osqueryd.status.log` depending on version and flags.
- If storing logs locally, keep rotation enabled via `--logger_rotate*` flags, and size/test in a pilot to avoid filling disks.

## Performance and safety

- Event publishers can generate high volumes. Start with a pilot, then scale intervals and `events_max` with data.
- Use `removed: false` on high‑volume event queries to reduce noise.
- Consider label‑based targeting (by OS version, model, corporate unit) via your manager to scope expensive queries.
- Avoid monitoring every path in `file_paths`; focus on persistence/control points first and iterate.

## Hands‑On Exercise: Build a production‑ready ES pipeline

**Goal:** Enable Endpoint Security–backed process events, capture FIM on key directories, and forward to your SIEM.

1. Install osquery and verify `osqueryi`/`osqueryd` are present.
2. Grant **Full Disk Access** to `/opt/osquery/lib/osquery.app/Contents/MacOS/osqueryd` via PPPC.
3. Create `/var/osquery/osquery.flags` with ES and logging options (see above).
4. Create `/var/osquery/osquery.conf` with schedules for `es_process_events`, `file_events`, and snapshots.
5. Start the daemon and verify events arrive:

   ```bash
    # Start the daemon (modern macOS 11+)
    sudo launchctl bootstrap system /Library/LaunchDaemons/io.osquery.agent.plist
    sudo launchctl enable system/io.osquery.agent
    sudo launchctl kickstart -k system/io.osquery.agent

    # Verify
    launchctl print system/io.osquery.agent
    sudo tail -f /var/log/osquery/osqueryd.results.log
   ```

6. Point your forwarder (Splunk/Logstash/etc.) at `/var/log/osquery/` and confirm ingestion.
7. Run the detection queries above to validate signal, adjust intervals, and roll out to a larger ring of devices.

## macOS Scripting Tips

- When testing interactively, remember `osqueryi` and `osqueryd` **do not share state**. Test flags with the daemon.
- Use `SELECT * FROM osquery_flags;` to verify that event flags are set as expected.
- On Apple silicon, ensure your PPPC/FDA profile targets the correct path inside the osquery app bundle; path typos will silently result in empty ES tables.
- Keep your query names stable; SIEM dashboards and detection rules often key off the `name` field in results logs.
- Prefer **packs** and **labels** in your manager to avoid per-host JSON drift.
- `file_events` will remain empty unless `--enable_file_events=true` is set in your flags **and** matching `file_paths` are configured.
- To confirm event publishers/subscribers are alive, run: `SELECT name, publisher, subscriptions, events, active FROM osquery_events;` and `SELECT name, value FROM osquery_flags WHERE name IN ('disable_events','disable_endpointsecurity','disable_endpointsecurity_fim','enable_file_events');`.
- Prefer Endpoint Security on macOS for process events; avoid `audit_*` flags on macOS unless you intentionally deploy OpenBSM for legacy reasons.

### Quick validation checklist

- `osqueryd --version` returns a recent 5.x.
- `/var/osquery/osquery.flags` includes `--disable_events=false`, `--disable_endpointsecurity=false`, and at least one FIM option (`--enable_file_events=true` or `--disable_endpointsecurity_fim=false`).
- `launchctl print system/io.osquery.agent` shows the service loaded and running.
- FDA PPPC is applied to the bundle ID `io.osquery.agent` or the binary path; daemon was restarted.
- `osqueryi --line "SELECT * FROM es_process_events LIMIT 1;"` returns rows after a test process launch.
- `osqueryi --line "SELECT * FROM file_events LIMIT 1;"` returns rows after touching a monitored path.

## Global Deployment Checklist (A to Z)

1. **Install** the official pkg across the fleet (MDM/munki/Jamf) and verify `/usr/local/bin/osqueryctl` exists.
2. **LaunchDaemon** installed and loaded (`io.osquery.agent.plist`) using modern `launchctl` commands; verify with `launchctl print system/io.osquery.agent`.
3. **FDA (PPPC)** profile deployed to grant SystemPolicyAllFiles to `/opt/osquery/lib/osquery.app/Contents/MacOS/osqueryd` (or bundle `io.osquery.agent`).
4. **Flagfile** at `/var/osquery/osquery.flags` enables events (`--disable_events=false`), Endpoint Security (`--disable_endpointsecurity=false`), FIM (choose `--enable_file_events=true` and/or `--disable_endpointsecurity_fim=false`), and logging/rotation.
5. **Configuration** at `/var/osquery/osquery.conf` defines `file_paths`, `exclude_paths`, and scheduled queries for `es_process_events`, `file_events`, and/or `es_process_file_events`.
6. **Logging** points to filesystem and/or TLS (`--logger_plugin=filesystem[,tls]`), with rotation enabled; ship `/var/log/osquery/` via your forwarder.
7. **Validation**: check `osquery_logs` arriving in your SIEM; on-host, run `SELECT * FROM osquery_events;` and tail `osqueryd.results.log`.
8. **Targeting/labels**: scope expensive queries by OS version/model; roll out in rings.
9. **Performance**: tune `interval`, `removed`, `events_max`, and path scopes; monitor CPU/RAM and RocksDB size at `/var/osquery/osquery.db`.
10. **Security**: pin TLS server certs (`--tls_server_certs`), keep official, signed/notarized builds; audit your PPPC payloads regularly.

## Drop-in detections pack (packs/detections.conf)

Save this file to `/var/osquery/packs/detections.conf` and enable it from your main config under `"packs"`.

```json
{
  "queries": {
    "persistence_launchd_mods": {
      "query": "SELECT datetime(time,'unixepoch') AS ts, action, path, uid, gid, mode FROM file_events WHERE path LIKE '/Library/LaunchDaemons/%' OR path LIKE '/Library/LaunchAgents/%';",
      "interval": 300,
      "removed": false,
      "description": "LaunchDaemons/Agents created or modified"
    },
    "unsigned_exec_from_user_writable": {
      "query": "SELECT datetime(e.time,'unixepoch') AS ts, e.pid, e.parent, e.path, s.signed, s.team_identifier AS team_id FROM es_process_events AS e LEFT JOIN signature AS s ON s.path = e.path WHERE e.path LIKE '/Users/%/Downloads/%' OR e.path LIKE '/Users/%/Library/%' OR e.path LIKE '/private/tmp/%' OR e.path LIKE '/Volumes/%' ORDER BY e.time DESC LIMIT 200;",
      "interval": 300,
      "removed": false,
      "description": "Process executions from user-writable locations, joined with signing metadata"
    },
    "first_seen_binaries": {
      "query": "WITH execs AS (SELECT path, MIN(time) AS first_seen FROM es_process_events GROUP BY path) SELECT datetime(first_seen,'unixepoch') AS first_seen_utc, path FROM execs ORDER BY first_seen ASC LIMIT 200;",
      "interval": 3600,
      "snapshot": true,
      "description": "First-seen binaries prevalence view"
    },
    "lotl_suspicious_parent_child": {
      "query": "SELECT datetime(e.time,'unixepoch') AS ts, e.parent, p.name AS parent_name, e.pid, e.path AS child_path FROM es_process_events e LEFT JOIN processes p ON p.pid = e.parent WHERE parent_name IN ('osascript','bash','zsh','python3','curl','sh') AND e.path NOT LIKE '/Applications/%' ORDER BY e.time DESC LIMIT 200;",
      "interval": 300,
      "removed": false,
      "description": "Living-off-the-land parent/child anomalies"
    },
    "recent_network_listeners": {
      "query": "SELECT p.pid, p.name, p.path, l.address, l.port, l.protocol FROM listening_ports AS l JOIN processes AS p USING (pid) WHERE p.start_time > strftime('%s','now') - 600 ORDER BY p.start_time DESC;",
      "interval": 300,
      "removed": false,
      "description": "Newly appeared network listeners (last 10 minutes)"
    }
  }
}
```

## Chapter 18 Exercise

**Build an ES‑enabled detection pack**:

1. Create `packs/detections.conf` with the queries in this chapter (parent/child anomalies, unsigned execution, new LaunchDaemons).
2. Enable the pack in `/var/osquery/osquery.conf`:

   ```json
   {
     "packs": {
       "detections": "/var/osquery/packs/detections.conf"
     }
   }
   ```

3. Validate in a VM first: trigger harmless events (create a temporary LaunchAgent, run an unsigned script from Downloads) and confirm detections arrive in your SIEM.

**Stretch goal:** Add a TLS logger endpoint and switch your fleet to `filesystem,tls` with certificate pinning.
