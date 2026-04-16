<p align="center">
  <h1 align="center">Funplay MCP for Godot</h1>
  <p align="center">
    <strong>The Most Advanced MCP Server for Godot Editor</strong>
  </p>
  <p align="center">
    <a href="#"><img src="https://img.shields.io/badge/Godot-4.2%2B-blue?logo=godotengine" alt="Godot 4.2+"></a>
    <a href="#"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
    <a href="#"><img src="https://img.shields.io/badge/MCP-Compatible-green" alt="MCP Compatible"></a>
    <a href="#"><img src="https://img.shields.io/badge/Platform-Editor%20Only-orange" alt="Editor Only"></a>
  </p>
  <p align="center">
    <a href="./README_CN.md">中文</a> | English
  </p>
  <p align="center">
    <img src="./icon.svg" alt="Funplay MCP for Godot" width="128">
  </p>
</p>

> 💖 If you find this project useful, please consider giving it a Star. It helps more Godot developers discover it and supports ongoing development.

---

Funplay MCP for Godot is an MIT-licensed Godot Editor MCP server that lets AI assistants like Claude Code, Cursor, Windsurf, Codex, and VS Code Copilot operate directly inside your running Godot project.

Describe your game or tool in one sentence — your AI assistant builds it in Godot through Funplay MCP for Godot’s built-in tools for scene creation, script generation, UI authoring, play-mode validation, input simulation, animation setup, camera control, performance inspection, and editor automation.

> *"Build a top-down shooter HUD with health, ammo, pause menu, and hit flash feedback"*
>
> Your AI assistant handles it through Funplay MCP for Godot: creates the scene structure, generates scripts, builds the Control tree, wires signals, configures animations, and validates the workflow — all from a single prompt.

## Quick Start

If you just want to get connected fast, do these three things:

- Open the project or copy `addons/funplay_mcp` into your own Godot project
- Enable the plugin and start the MCP server
- Use the built-in one-click client configuration

### 1. Install the addon

You can either:

- clone this repository and open it directly as a Godot project, or
- copy `addons/funplay_mcp` into your own Godot `res://addons/` directory

> 💡 Before you clone or install, a quick ⭐ on GitHub would be greatly appreciated.

### 2. Enable and start the MCP Server

In Godot:

- open **Project → Project Settings → Plugins**
- enable **Funplay MCP for Godot**
- use the **Funplay MCP** dock on the right side

The server starts on `http://127.0.0.1:8765/` by default.
If that port is already occupied, it automatically picks another free local port and saves it to `user://funplay_mcp_settings.cfg`.

### 3. Configure Your AI Client

Use the built-in **One-Click MCP Configuration** in the `Funplay MCP` dock first.

Select your target client, click **Configure**, and the addon writes the recommended MCP config entry for you.

If Godot had to pick a different port, use the endpoint shown in the dock.
If you prefer to edit config files manually, use the examples below as fallback references:

<details>
<summary>Claude Code / Claude Desktop</summary>

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

</details>

<details>
<summary>Cursor</summary>

```json
{
  "mcpServers": {
    "funplay": {
      "url": "http://127.0.0.1:8765/"
    }
  }
}
```

</details>

<details>
<summary>VS Code</summary>

```json
{
  "servers": {
    "funplay": {
      "type": "http",
      "url": "http://127.0.0.1:8765/"
    }
  }
}
```

</details>

<details>
<summary>Codex</summary>

```toml
[mcp_servers.funplay]
url = "http://127.0.0.1:8765/"
```

</details>

### 4. Verify the Connection

Open your AI client and try a few safe requests first:

- "Call `get_scene_info` and tell me what scene is open."
- "Read `godot://project/context` and summarize the current editor state."
- "Use `execute_code` to return the active scene name."

If those work, the MCP server, resources, and primary execution tool are connected correctly.

### 5. Start Building

Open your AI client and try: *"Create a 2D HUD with health bar, score label, and pause button"*

## Before You Start

- This addon is **Editor-only**. It does not add runtime components to your exported game.
- The MCP server starts on `http://127.0.0.1:8765/` by default, but automatically falls back to another free local port if needed.
- Local MCP server settings are stored in `user://funplay_mcp_settings.cfg`.
- The addon defaults to the `core` MCP tool profile to reduce tool-list noise for AI clients. Switch to `full` in the dock if you want the complete tool surface.
- All exposed MCP tools run directly. There is no extra approval toggle inside the addon.
- The built-in dock can copy or write recommended MCP config entries for Codex, Claude Code, Cursor, and VS Code.

## Why This Project

- **`execute_code` First** — The addon is optimized around one high-flexibility GDScript execution tool for rich editor/runtime orchestration when many small tools would be noisy
- **Play Mode Automation** — Enter play mode, simulate input, inspect logs, capture editor views, and validate behavior from the same MCP session
- **Project Context Built In** — Exposes live resources for project state, active scene, selection, play state, script errors, logs, and MCP interaction history
- **Focused by Default, Full When Needed** — `core` exposes a compact high-signal toolset; `full` exposes a broader editor automation surface
- **Single Godot Addon** — No extra approval UI, no external Python daemon required for the Godot-side plugin itself
- **Extensible** — Add more Godot-specific tools, resources, prompts, and workflow helpers as the repo evolves

## Highlights

- **87 Built-in Tools** — Scene editing, PackedScene workflows, scripts, files, play mode control, inputs, UI controls, animation, camera, performance, resources, prompts, and editor automation
- **Resources & Prompts** — Live project context, scene/selection/error resources, resource templates, and reusable workflow prompts
- **Input Simulation + View Capture** — Drive play mode with action/key/mouse simulation and verify results with captured editor views
- **One-Click Client Configuration** — Generate MCP config entries for Codex, Claude Code, Cursor, and VS Code directly from the Godot dock
- **UI/Control Tooling** — Build CanvasLayer and Control hierarchies, set layouts, apply theme overrides, wire signals, and create HUDs through MCP
- **Vendor Agnostic** — Works with any AI client that supports MCP: Claude Code, Cursor, Windsurf, Codex, VS Code Copilot, etc.

## Comparison With Unity MCP

The table below compares this repository with the public behavior and positioning of `FunplayAI/funplay-unity-mcp`.

| Area | Funplay MCP for Godot | Funplay MCP for Unity |
|------|------------------------|-----------------------|
| Engine-side architecture | Embedded Godot Editor addon with built-in HTTP MCP server | Embedded Unity Editor package with built-in HTTP MCP server |
| Extra local prerequisites | Godot addon only for core workflows | Unity package only for core workflows |
| Primary workflow style | `execute_code` first, then focused helper tools | `execute_code` first, then focused helper tools |
| Default tool exposure | Compact `core` profile with optional `full` expansion | Compact `core` profile with optional `full` expansion |
| Built-in context model | Project resources, script error summary, play state, logs, prompts, interaction history | Project resources, compile errors, play state, logs, prompts, interaction history |
| UI automation | Deep Godot `Control` / `CanvasLayer` workflows | Unity Canvas / UI helpers |
| Positioning | Lightweight, direct, MIT-licensed Godot MCP server for AI-driven editor control | Lightweight, direct, MIT-licensed Unity MCP server for AI-driven editor control |

## MCP Capabilities

The current open-source package exposes four high-value capability layers:

- **Tools** — 87 total tools across scene editing, files, scripts, UI, animation, camera, diagnostics, and automation
- **Primary execution** — `execute_code` for rich editor/runtime orchestration
- **Prompts** — workflow prompts like `scene_review`, `feature_plan`, `runtime_debug`, `script_patch`, and `ui_layout_plan`
- **Resources** — project context, scene summaries, selection state, logs, script errors, play state, project features, MCP interaction history, and file templates

## Built-in Tools

Funplay MCP for Godot currently ships with **87 tool functions** across major workflow groups:

| Category | Tools |
|----------|-------|
| **Scene** | `get_scene_info`, `get_scene_tree`, `list_scenes`, `open_scene`, `save_scene`, `save_scene_as`, `create_new_scene`, `instantiate_scene`, `create_packed_scene_from_node`, `get_packed_scene_info` |
| **Nodes** | `get_node_info`, `find_nodes`, `select_node`, `create_node`, `duplicate_node`, `rename_node`, `reparent_node`, `remove_node`, `set_node_property`, `set_node_properties`, `set_transform_2d`, `set_transform_3d`, `set_node_script` |
| **Node Reflection** | `list_node_properties`, `list_node_signals`, `list_node_methods` |
| **Scripts** | `create_script`, `edit_script`, `patch_script`, `open_script`, `validate_gdscript_file`, `get_script_errors`, `request_script_reload` |
| **Files** | `read_file`, `write_file`, `search_files`, `list_files`, `file_exists`, `delete_file`, `move_file`, `copy_file` |
| **Play / Input** | `get_play_state`, `enter_play_mode`, `play_main_scene`, `exit_play_mode`, `simulate_action`, `simulate_key_event`, `simulate_mouse_button`, `simulate_mouse_drag`, `simulate_input_sequence`, `get_time_scale`, `set_time_scale` |
| **Performance / Logs** | `get_performance_snapshot`, `analyze_scene_complexity`, `get_console_logs`, `log_message` |
| **Animation** | `create_animation_player`, `create_animation_clip`, `add_animation_track`, `list_animations`, `play_animation` |
| **Camera** | `get_camera_info`, `set_camera_2d`, `set_camera_3d` |
| **Materials** | `create_material`, `assign_material` |
| **UI / Control** | `create_ui_root`, `create_control`, `create_label`, `create_button`, `create_panel`, `create_texture_rect`, `create_container`, `set_control_layout`, `set_control_size_flags`, `set_control_text`, `set_control_theme_override`, `set_control_texture`, `connect_node_signal` |
| **Project / Addons** | `get_project_info`, `list_project_features`, `select_file`, `list_addons`, `set_addon_enabled` |
| **Capture / Execution** | `capture_editor_view`, `execute_code` |

## Repository Layout

- `addons/funplay_mcp/plugin.gd` — Godot editor plugin entry
- `addons/funplay_mcp/core/` — MCP server, tools, resources, prompts, settings, and config writers
- `addons/funplay_mcp/ui/` — Godot dock UI
- `CHANGELOG.md` — user-facing changes
- `CONTRIBUTING.md` — contributor workflow
- `RELEASE_CHECKLIST.md` — release process

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

This repository is licensed under [MIT](./LICENSE).
