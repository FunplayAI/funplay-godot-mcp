# Changelog

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
