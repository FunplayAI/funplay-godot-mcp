# Funplay MCP for Godot

An embedded MCP server plugin for the Godot editor, inspired by the structure and workflow of `funplay-unity-mcp`.

It keeps the same overall idea:

- run the MCP server inside the editor
- prefer one high-leverage `execute_code` tool
- expose project context through resources
- provide a compact `core` profile and a broader `full` profile

## Current Scope

This Godot version now ships with:

- embedded HTTP MCP server on `127.0.0.1`
- editor dock for enable/disable, port, profile, and config snippets
- `core` and `full` tool profiles
- built-in tools for:
  - script/code execution
  - scene open/save/create/instantiate
  - PackedScene export and inspection
  - node query/select/find/create/duplicate/reparent/remove
  - node property/signal/method reflection
  - node property and transform editing
  - file read/write/search/copy/move/delete
  - script create/edit/open/patch
  - script reload/error diagnostics
  - play-mode control
  - input simulation for actions / keys / mouse buttons
  - mouse drag and scripted input sequences
  - time-scale control
  - recent file-log harvesting
  - performance snapshots
  - scene complexity analysis
  - editor viewport capture
  - material creation and assignment
  - deeper Godot UI / Control authoring
  - AnimationPlayer clip/track helpers
  - Camera2D/Camera3D helpers
  - addon/plugin inventory and toggling
- MCP resources:
  - `godot://project/context`
  - `godot://scene/current`
  - `godot://selection/current`
  - `godot://interaction/history`
  - `godot://logs/recent`
  - `godot://scripts/errors`
  - `godot://project/features`
  - `godot://play/state`
  - `godot://performance/snapshot`
  - `godot://scenes/list`
  - `godot://file/{path}`
- MCP prompts:
  - `scene_review`
  - `feature_plan`
  - `runtime_debug`
  - `script_patch`
  - `ui_layout_plan`

## Quick Start

### 1. Open the project in Godot 4.2+

This repository already contains a minimal `project.godot`, so it can be opened directly as a Godot project.

### 2. Enable the plugin

Open `Project > Project Settings > Plugins` and enable `Funplay MCP for Godot`.

The dock appears on the right side of the editor.

### 3. Start the MCP server

In the `Funplay MCP` dock:

- enable `Enable MCP Server`
- keep port `8765` or choose another one
- choose `core` or `full`

The plugin binds to `http://127.0.0.1:<port>/`.

If the selected port is occupied, it tries nearby local ports and persists the final value in `user://funplay_mcp_settings.cfg`.

### 4. Configure your AI client

Use the built-in snippet picker in the dock. You can either:

- copy the snippet to the clipboard
- click `Configure` to write the target client config file directly

The dock currently supports one-click config writing for:

- Codex
- Claude Code
- Cursor
- VS Code

**Codex**

```toml
[mcp_servers.funplay]
url = "http://127.0.0.1:8765/"
```

**Claude Code**

```json
{
  "mcpServers": {
    "funplay": {
      "type": "http",
      "url": "http://127.0.0.1:8765/"
    }
  }
}
```

**Cursor**

```json
{
  "mcpServers": {
    "funplay": {
      "url": "http://127.0.0.1:8765/"
    }
  }
}
```

### 5. Verify the connection

Try:

- `get_project_info`
- `get_scene_tree`
- `read_resource godot://project/context`
- `execute_code` with:

```gdscript
return {
	"scene_root": ctx["scene_root"].name if ctx["scene_root"] != null else "",
	"selection_count": ctx["selection"].size()
}
```

## Tool Profiles

### `core`

Smaller but still high-utility tool surface for AI clients:

- `execute_code`
- scene inspection and open/save
- file read/write/search
- script create/edit/open/patch
- play-state, input simulation, mouse drag/sequence simulation, and time-scale control
- recent file-log inspection
- performance/complexity inspection
- viewport capture
- node selection and lookup

### `full`

Everything in `core`, plus direct scene/resource mutation helpers:

- create new scenes and instantiate sub-scenes
- save node subtrees as PackedScene resources and inspect PackedScene files
- create/duplicate/rename/reparent/remove nodes
- inspect node properties, signals, and methods before editing
- create CanvasLayer / Control / Label / Button / Panel / TextureRect / Container UI trees
- set control layout, size flags, text, textures, and theme overrides
- connect signals between UI nodes and script methods
- set node properties and transforms
- attach scripts to nodes
- create/assign materials
- create AnimationPlayer nodes, clips, tracks, and play animations
- configure Camera2D / Camera3D properties
- list and toggle addons/plugins
- delete/move/copy files

## Notes

- This plugin is editor-only.
- The HTTP transport is currently a simple local request/response implementation.
- The repo intentionally mirrors the Unity plugin’s structure and now covers most day-to-day Godot editor workflows, though it still does not match Unity feature parity 1:1.
- Dynamic code execution is powerful and should only be exposed to trusted local MCP clients.

## Repository Layout

- `addons/funplay_mcp/plugin.gd` — editor plugin entry
- `addons/funplay_mcp/core/funplay_mcp_server.gd` — server lifecycle
- `addons/funplay_mcp/core/funplay_mcp_request_handler.gd` — MCP method handling
- `addons/funplay_mcp/core/funplay_tool_registry.gd` — tool profiles and definitions
- `addons/funplay_mcp/core/funplay_core_tools.gd` — built-in Godot editor tools
- `addons/funplay_mcp/ui/funplay_mcp_dock.gd` — editor UI

## Next Gaps

Compared with the Unity version, the biggest remaining gaps are:

- richer Godot-specific UI convenience tools
- deeper editor-console integration beyond file-log harvesting
- one-click config writing for more MCP clients
