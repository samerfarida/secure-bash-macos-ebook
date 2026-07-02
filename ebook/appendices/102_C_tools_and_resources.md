# Appendix C: Tools and Resources

## C.1 Learning and Development Tools

| Tool | Description | Link |
|------|-------------|------|
| **man pages** | Built-in manual pages for commands | `man bash` |
| **tldr** | Simplified and community-driven man pages | [https://tldr.sh/](https://tldr.sh/) |
| **explainshell.com** | Visual breakdown of shell commands | [https://explainshell.com/](https://explainshell.com/) |
| **cheat.sh** | Unified community cheatsheets | [https://cheat.sh/](https://cheat.sh/) |
| **Bash Hackers Wiki** | Community wiki for Bash scripting | [https://wiki.bash-hackers.org/](https://wiki.bash-hackers.org/) |

## C.2 macOS-Specific Tools

| Tool | Description | Link |
|------|-------------|------|
| **Homebrew** | Popular package manager for macOS | [https://brew.sh/](https://brew.sh/) |
| **MacPorts** | Alternative package manager for macOS | [https://www.macports.org/](https://www.macports.org/) |
| **PlistBuddy** | Command-line tool for plist files | `man PlistBuddy` |
| **BBEdit** | Advanced text editor for macOS | [https://www.barebones.com/products/bbedit/](https://www.barebones.com/products/bbedit/) |
| **iTerm2** | Powerful Terminal replacement | [https://iterm2.com/](https://iterm2.com/) |

## C.3 Security and Hardening Tools

| Tool | Description | Link |
|------|-------------|------|
| **Osquery** | SQL-powered endpoint visibility tool | [https://osquery.io/](https://osquery.io/) |
| **KnockKnock** | Shows persistently installed software | [https://objective-see.org/products/knockknock.html](https://objective-see.org/products/knockknock.html) |
| **BlockBlock** | Monitors persistence events | [https://objective-see.org/products/blockblock.html](https://objective-see.org/products/blockblock.html) |
| **Little Snitch** | Outbound firewall for macOS | [https://www.obdev.at/products/littlesnitch/index.html](https://www.obdev.at/products/littlesnitch/index.html) |
| **LuLu** | Free, open-source firewall | [https://objective-see.org/products/lulu.html](https://objective-see.org/products/lulu.html) |
| **macOS Security Compliance Project (mSCP)** | Community-driven framework for creating security baselines and compliance mappings for macOS | [https://github.com/usnistgov/macos_security](https://github.com/usnistgov/macos_security) |
| **Santa** | Binary authorization and application control system for macOS (maintained by North Pole Security) | [https://github.com/northpolesec/santa](https://github.com/northpolesec/santa) |
| **Workshop** | Commercial sync server for enterprise Santa rule management | [https://northpole.dev](https://northpole.dev) |
| **SAP Privileges** | Time-limited admin elevation tool for macOS | [https://github.com/SAP/macOS-enterprise-privileges](https://github.com/SAP/macOS-enterprise-privileges) |
| **Installomator** | Label-driven installer and updater for macOS applications | [https://github.com/Installomator/Installomator](https://github.com/Installomator/Installomator) |
| **Patchomator** | Automated patch management for discovered macOS applications | [https://github.com/Mac-Nerd/patchomator](https://github.com/Mac-Nerd/patchomator) |
| **Nudge** | User deferral framework for mandatory macOS updates | [https://github.com/macadmins/nudge](https://github.com/macadmins/nudge) |
| **erase-install** | Community tool for safe macOS reinstallation and OS refresh workflows | [https://github.com/grahampugh/erase-install](https://github.com/grahampugh/erase-install) |
| **swiftDialog** | Professional dialog presentation tool for macOS | [https://github.com/bartreardon/swiftDialog](https://github.com/bartreardon/swiftDialog) |
| **munkipkg** | Tool for building macOS installer packages | [https://github.com/munki/munki-pkg](https://github.com/munki/munki-pkg) |
| **Platypus** | Create macOS applications from command-line scripts | [https://sveinbjorn.org/platypus](https://sveinbjorn.org/platypus) |
| **sbx (Docker Sandboxes)** | MicroVM isolation for AI coding agents on Apple Silicon | [https://docs.docker.com/ai/sandboxes/](https://docs.docker.com/ai/sandboxes/) |
| **Claude Code** | Anthropic agentic coding CLI with Seatbelt sandbox and hooks | [https://code.claude.com/](https://code.claude.com/) |
| **Cursor** | AI IDE/CLI with `sandbox.json` and agent hooks | [https://cursor.com/](https://cursor.com/) |
| **Codex CLI** | OpenAI agentic coding CLI with Seatbelt and `[otel]` telemetry | [https://developers.openai.com/codex/](https://developers.openai.com/codex/) |
| **Agent Safehouse** | Seatbelt wrapper for agent CLIs | [https://agent-safehouse.dev/](https://agent-safehouse.dev/) |
| **OpenTelemetry Collector** | Vendor-neutral OTLP pipeline for logs, metrics, traces | [https://opentelemetry.io/docs/collector/](https://opentelemetry.io/docs/collector/) |
| **o11y-dev/opentelemetry-hooks** | Multi-agent hook-based OTel exporter | [https://github.com/o11y-dev/opentelemetry-hooks](https://github.com/o11y-dev/opentelemetry-hooks) |
| **cursorscope** | Cursor hook events to OTLP forwarder | [https://github.com/last9/cursorscope](https://github.com/last9/cursorscope) |
| **Chapter 23 lab assets** | `test-validator.sh`, Cursor hook guards, osquery pack, MCP allowlist | `ebook/assets/scripts/` and `ebook/assets/sample_configs/` |
| **MCP SSH Orchestrator** | Declarative MCP SSH access control example | [https://me.itsecurity.network/projects/mcp-ssh-orchestrator/](https://me.itsecurity.network/projects/mcp-ssh-orchestrator/) |

## C.4 Recommended Shells and Extensions

| Tool | Description | Link |
|------|-------------|------|
| **Bash** | Default shell; verify version with `bash --version` | `bash` |
| **zsh** | Default interactive shell in newer macOS versions | `zsh` |
| **Oh My Zsh** | Framework for managing zsh configs | [https://ohmyz.sh/](https://ohmyz.sh/) |
| **Starship** | Fast, customizable shell prompt | [https://starship.rs/](https://starship.rs/) |
| **Bash-it** | Framework for managing Bash configs | [https://github.com/Bash-it/bash-it](https://github.com/Bash-it/bash-it) |

## C.5 Helpful Online Tools

| Tool | Description | Link |
|------|-------------|------|
| **ShellCheck** | Static analysis tool for shell scripts | [https://www.shellcheck.net/](https://www.shellcheck.net/) |
| **Regex101** | Regex tester and debugger | [https://regex101.com/](https://regex101.com/) |
| **CyberChef** | Swiss Army knife for data format transformations | [https://gchq.github.io/CyberChef/](https://gchq.github.io/CyberChef/) |


## C.6 Author's Note

These tools can help you write, test, and secure your Bash scripts on macOS. I encourage you to explore, experiment, and contribute back to open-source projects that make your scripting journey smoother.
