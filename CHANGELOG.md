# Changelog

## [0.7.0] - 2026-05-21

### Added
- Added release packaging automation that builds a validated `Funplay.GodotMcp.vX.Y.Z.zip`, release manifest, release notes, and SHA256 sums
- Added a tag-driven GitHub Release workflow that uploads the generated release artifacts
- Added a Dock update checker that queries the latest GitHub Release and opens the release page
- Added an npm-ready stdio wrapper plus MCP Registry `server.json` metadata for `io.github.FunplayAI/funplay-godot-mcp`

## [0.6.0] - 2026-05-21

### Added
- Added grouped tool catalog and `funplay_help` workflow guidance tools
- Added capability status, LSP/DAP editor protocol status, workflow coverage, and matching resources
- Added runtime bridge autoload script plus install/remove/status MCP tools for play-mode heartbeat state
- Added editor undo/redo status and command tools backed by Godot `EditorUndoRedoManager` when available

## [0.5.0] - 2026-05-20

### Added
- Added a Dock Tool Exposure panel for enabling or disabling individual tools within the active profile
- Added Project Skills generation, including `Configure + Skills`, generated skill files, an `AGENTS.md` bridge, and MCP tools for skill status/generation
- Added optional MCP debug logging from the Dock
- Added `execute_code` context helpers for logging, object summaries, manual change tracking, and metadata-wrapped results

### Changed
- Tool call responses now mirror JSON text results into MCP `structuredContent`
- Node and resource summaries now include session `instance_id` values, and node lookup accepts `id:<instance_id>` identifiers

## [0.4.2] - 2026-05-11

### Added
- Added low-level `ProjectSettings` tools for listing, reading, and writing project settings directly through MCP
- Added low-level `InputMap` tools for listing actions, reading action bindings, creating/removing actions, and editing input events
- Added low-level `autoload` tools for listing, adding, updating, and removing autoload entries
- Added runtime assertion helpers for node existence, node property equality, and signal connectivity
- Added `wait_msec` for small stabilization steps in low-level editor and runtime automation flows
- Added project-configuration resources for project settings, input actions, and autoloads

### Changed
- Completed the low-level implementations behind the already-exposed project/input/autoload/assertion tool surface

## [0.4.1] - 2026-04-30

### Fixed
- Updated MCP protocol negotiation to advertise the current `2025-11-25` protocol version
- Marked failed tool calls with MCP `isError` and return JSON-RPC errors for unknown or hidden tools
- Prevented one-click JSON client configuration from overwriting invalid existing config files
- Added resource-path context to GDScript validation and made `patch_script` fail when replacement text is absent

### Changed
- Added request size, header size, and timeout limits to the embedded HTTP transport
- Added a reusable repository validation script and wired CI to check versions, protocol defaults, and tool registry consistency

## [0.4.0] - 2026-04-17

### Added
- Added low-level Godot-native tooling for `ProjectSettings`, `InputMap`, and `autoload` management
- Added runtime assertion helpers for node existence, node properties, and signal connectivity
- Added a simple wait tool for low-level stabilization workflows
- Added language-aware script tool export so GDScript and .NET projects only see relevant script tools by default
- Expanded the registered low-level tool surface to 105 tools

### Changed
- Unified script tooling around `create_script`, `list_scripts`, `validate_script`, and `get_script_errors`
- Filtered `.NET` resources and script tools based on detected project language

## [0.3.0] - 2026-04-16

### Added
- Reworked README and README_CN into a public-facing GitHub landing page style aligned with the Unity repository
- Added GitHub contribution files, PR template, release checklist, and CI validation
- Added animation tooling for `AnimationPlayer`, clips, tracks, listing, and playback
- Added camera helpers for `Camera2D` and `Camera3D`
- Added PackedScene export and inspection workflows
- Added node reflection tools for properties, signals, and methods
- Added addon/plugin listing and enable/disable support
- Added GDScript validation, script error scanning, and script reload helpers
- Added language-aware script tooling that automatically detects GDScript, Godot .NET, or mixed projects
- Unified script creation, listing, validation, and error reporting behind fewer AI-facing tools

## [0.2.0] - 2026-04-16

### Added
- Added richer Godot UI and Control authoring tools
- Added one-click MCP client config writing for Codex, Claude Code, Cursor, and VS Code
- Added file-log harvesting plus richer input simulation including drag and input sequences

## [0.1.0] - 2026-04-16

### Added
- Initial public version of Funplay MCP for Godot
- Embedded MCP server with HTTP JSON-RPC style handling
- Core tool profiles, resources, prompts, dock UI, and project scaffolding
