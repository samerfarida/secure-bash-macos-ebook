# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Chapter 23: Secure Agentic AI Development on macOS** — `sbx` microVM sandboxes, native Seatbelt agents (Cursor, Claude Code, Codex, Devin Local), policy guardrails (`AGENTS.md`, hooks, LLM-as-judge), OpenTelemetry/SIEM integration, skills/MCP supply chain, and fleet integration with Santa, osquery, mSCP, and SAP Privileges
- Sample scripts: `agent-sandbox-wrapper.sh`, `agent-isolation-policy-check.sh`, `claude-pretooluse-validator.sh`
- Sample config: `otel-collector-agents.yaml`
- Forward-reference backlinks in Chapters 14, 18, 21, and 22

## [1.0.0] - 2024-12-19

### Changed

- Prepare for v1.0.0 release: removed prerelease flag from release workflow
- Updated default version baseline from v0.1.0 to v1.0.0

### Fixed

- Fixed workflow: removed duplicate push trigger from release workflow

### Enhanced

- Enhanced EPUB CSS: removed TOC numbering, improved styling, fixed dark mode

## [0.16.1] - Previous Release

Previous releases were marked as pre-releases. Starting with v1.0.0, all releases are full production releases.

[Unreleased]: https://github.com/samerfarida/secure-bash-macos-ebook/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/samerfarida/secure-bash-macos-ebook/releases/tag/v1.0.0
[0.16.1]: https://github.com/samerfarida/secure-bash-macos-ebook/releases/tag/v0.16.1
