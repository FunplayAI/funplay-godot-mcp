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

The addon works in standard Godot `4.2+` projects and is also usable in **Godot .NET** projects. The current implementation is GDScript-based, and the exported script tools are language-aware: GDScript projects see GDScript workflows, .NET projects see C#/.NET workflows, and mixed projects expose both where useful.

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

- download `Funplay.GodotMcp.vX.Y.Z.zip` from the latest GitHub Release and extract it into your project root,
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
Local MCP POST requests require the per-project auth token stored in `user://funplay_mcp_settings.cfg`; the dock writes it into generated stdio client configs automatically.
The dock also shows the installed addon version and includes a **Check Updates** action that opens the latest GitHub Release when a newer version is available.

### 3. Configure Your AI Client

Use the built-in **One-Click MCP Configuration** in the `Funplay MCP` dock first.

Select your target client, click **Configure**, and the addon writes the recommended MCP config entry for you.
Use **Configure + Skills** when you also want the addon to generate project-local skill files under `res://.funplay/skills/` and an `AGENTS.md` bridge for AI clients that read repository instructions.

If Godot had to pick a different port, use the endpoint shown in the dock.
If you prefer to edit config files manually, use the examples below as fallback references:

<details>
<summary>Claude Code / Claude Desktop</summary>

```json
{
  "mcpServers": {
    "funplay": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "funplay-godot-mcp@0.9.2"],
      "env": {
        "FUNPLAY_GODOT_MCP_URL": "http://127.0.0.1:8765/",
        "FUNPLAY_GODOT_MCP_TOKEN": "<token from Funplay MCP dock>"
      }
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
      "command": "npx",
      "args": ["-y", "funplay-godot-mcp@0.9.2"],
      "env": {
        "FUNPLAY_GODOT_MCP_URL": "http://127.0.0.1:8765/",
        "FUNPLAY_GODOT_MCP_TOKEN": "<token from Funplay MCP dock>"
      }
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
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "funplay-godot-mcp@0.9.2"],
      "env": {
        "FUNPLAY_GODOT_MCP_URL": "http://127.0.0.1:8765/",
        "FUNPLAY_GODOT_MCP_TOKEN": "<token from Funplay MCP dock>"
      }
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

### Optional stdio wrapper

Most clients can connect directly to the addon over HTTP. For clients or registries that prefer stdio packages, this repository also includes an npm-ready wrapper under `stdio-wrapper/`.

```bash
cd stdio-wrapper
npm link
FUNPLAY_GODOT_MCP_URL=http://127.0.0.1:8765/ funplay-godot-mcp
```

After the wrapper is published to npm, replace `npm link` with `npm install -g funplay-godot-mcp`.

Example MCP client entry:

```json
{
  "mcpServers": {
    "funplay": {
      "command": "funplay-godot-mcp",
      "env": {
        "FUNPLAY_GODOT_MCP_URL": "http://127.0.0.1:8765/"
      }
    }
  }
}
```

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
- The MCP server starts on `http://127.0.0.1:8765/` by default. If the same project already owns that port, the dock attaches to it; otherwise it falls back to another free local port.
- Local MCP server settings are stored in `user://funplay_mcp_settings.cfg`.
- The addon defaults to the `core` MCP tool profile to reduce tool-list noise for AI clients. Switch to `full` in the dock if you want the complete tool surface.
- The dock includes a Tool Exposure panel for disabling individual tools within the active profile, plus optional debug logging and `execute_code` safety toggles.
- `execute_code` safety checks are on by default for common process, filesystem, and project-setting mutations. A reviewed call can pass `safety_checks=false`.
- The dock can check GitHub Releases for newer addon versions.
- Focused MCP tools run directly. There is no extra approval toggle inside the addon.
- The built-in dock can copy or write recommended MCP config entries for Codex, Claude Code, Cursor, and VS Code.

## Why This Project

- **`execute_code` First** — The addon is optimized around one high-flexibility GDScript execution tool for rich editor/runtime orchestration, now with default-on safety checks for risky snippets
- **Tool Exposure Control** — Toggle individual tools from the Godot dock without editing addon code or restarting the project
- **Project Skills** — Generate project-local AI guidance files that capture the current endpoint, tool profile, project context, and recommended Funplay workflow
- **Tool Catalog & Help** — Query grouped tool catalogs, capability gates, workflow coverage, and task-specific guidance from MCP
- **Project Map & Templates** — Inspect scenes, scripts, functions, signals, usage links, a searchable browser graph, and dry-run script refactor plans
- **Runtime Bridge** — Optionally install a lightweight autoload that writes play-mode heartbeat and scene-tree snapshots for AI-driven runtime validation
- **Play Mode Automation** — Enter play mode, simulate input, inspect logs, capture editor views, and validate behavior from the same MCP session
- **Project Context Built In** — Exposes live resources for project state, active scene, selection, play state, script errors, logs, and MCP interaction history
- **Focused by Default, Full When Needed** — `core` exposes a compact high-signal toolset; `full` exposes a broader editor automation surface
- **Single Godot Addon** — No extra approval UI, no external Python daemon required for the Godot-side plugin itself
- **Extensible** — Add more Godot-specific tools, resources, prompts, and workflow helpers as the repo evolves

## Highlights

- **124 Built-in Tools** — Scene editing, PackedScene workflows, language-aware script tools, project maps, script refactor planning, project settings, asset import plans, input map, autoloads, runtime bridge, undo/redo, workflow guidance, files, project skills, play mode control, UI controls, animation, camera, performance, resources, prompts, and editor automation
- **Resources & Prompts** — Live project context, JSON and HTML project maps, release readiness, runtime scene-tree snapshots, scene/selection/error resources, language-aware script diagnostics, `.NET` project resources when applicable, template resources, and reusable workflow prompts
- **Structured Results** — JSON tool outputs and tool errors are mirrored into MCP `structuredContent`, and node/resource summaries include session `instance_id` values for follow-up calls
- **Input Simulation + View Capture** — Drive play mode with action/key/mouse simulation and verify results with captured editor views
- **One-Click Client Configuration** — Generate MCP config entries for Codex, Claude Code, Cursor, and VS Code directly from the Godot dock
- **Release + Registry Ready** — GitHub Release artifacts are generated with manifests and SHA256 sums, Godot Asset Library packaging notes are included, the npm stdio wrapper is described by `server.json`, and release readiness is exposed through MCP
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
| Built-in context model | Project resources, script error summary, play state, runtime scene tree, logs, prompts, interaction history | Project resources, compile errors, play state, logs, prompts, interaction history |
| UI automation | Deep Godot `Control` / `CanvasLayer` workflows | Unity Canvas / UI helpers |
| Positioning | Lightweight, direct, MIT-licensed Godot MCP server for AI-driven editor control | Lightweight, direct, MIT-licensed Unity MCP server for AI-driven editor control |

## MCP Capabilities

The current open-source package exposes four high-value capability layers:

- **Tools** — 124 total registered tools across scene editing, scripts, project maps, project configuration, asset import planning, input map, autoloads, runtime bridge, undo/redo, workflow guidance, files, project skills, UI, animation, camera, diagnostics, and automation. Script-related tools are filtered by detected project language and the dock's Tool Exposure settings.
- **Primary execution** — `execute_code` for rich editor/runtime orchestration, with default-on safety checks, optional object-style context helpers, logs, and change tracking metadata
- **Prompts** — workflow prompts like `scene_review`, `feature_plan`, `runtime_debug`, `script_patch`, `ui_layout_plan`, `architecture_advice`, `performance_advice`, `network_template`, and `template_generate`
- **Resources** — project context, project map JSON/HTML, scene summaries, selection state, logs, script errors, play state, runtime scene tree, release readiness, project features, MCP interaction history, template catalog, and file templates

## Built-in Tools

Funplay MCP for Godot currently ships with **124 registered tool functions** across major workflow groups. The effective exported script tools are filtered by detected project language and per-tool exposure settings:

| Category | Tools |
|----------|-------|
| **Scene** | `get_scene_info`, `get_scene_tree`, `list_scenes`, `open_scene`, `save_scene`, `save_scene_as`, `create_new_scene`, `instantiate_scene`, `create_packed_scene_from_node`, `get_packed_scene_info` |
| **Nodes** | `get_node_info`, `find_nodes`, `select_node`, `create_node`, `duplicate_node`, `rename_node`, `reparent_node`, `remove_node`, `set_node_property`, `set_node_properties`, `set_transform_2d`, `set_transform_3d`, `set_node_script` |
| **Node Reflection** | `list_node_properties`, `list_node_signals`, `list_node_methods` |
| **Scripts** | `create_script`, `list_scripts`, `edit_script`, `patch_script`, `open_script`, `validate_script`, `get_script_errors`, `request_script_reload`; `.NET` projects also expose `get_dotnet_project_info` |
| **Project Map** | `map_project`, `find_usages`, `plan_script_refactor`, `apply_script_refactor` |
| **Project Settings / Input / Autoload** | `list_project_settings`, `get_project_setting`, `set_project_setting`, `list_input_actions`, `get_input_action`, `add_input_action`, `remove_input_action`, `add_input_event_to_action`, `clear_input_events`, `list_autoloads`, `set_autoload`, `remove_autoload` |
| **Guidance / Capability** | `funplay_help`, `list_tool_catalog`, `get_capability_status`, `get_editor_protocol_status`, `get_release_readiness`, `list_workflow_coverage` |
| **Runtime Bridge / Undo** | `install_runtime_bridge`, `remove_runtime_bridge`, `get_runtime_bridge_status`, `get_undo_redo_status`, `editor_undo`, `editor_redo` |
| **Files** | `read_file`, `write_file`, `search_files`, `list_files`, `file_exists`, `delete_file`, `move_file`, `copy_file` |
| **Play / Input** | `get_play_state`, `enter_play_mode`, `play_main_scene`, `exit_play_mode`, `simulate_action`, `simulate_key_event`, `simulate_mouse_button`, `simulate_mouse_drag`, `simulate_input_sequence`, `get_time_scale`, `set_time_scale` |
| **Assertions / Diagnostics** | `assert_node_exists`, `assert_node_property`, `assert_signal_connected`, `wait_msec`, `get_performance_snapshot`, `analyze_scene_complexity`, `get_console_logs`, `log_message` |
| **Animation** | `create_animation_player`, `create_animation_clip`, `add_animation_track`, `list_animations`, `play_animation` |
| **Camera** | `get_camera_info`, `set_camera_2d`, `set_camera_3d` |
| **Materials** | `create_material`, `assign_material` |
| **UI / Control** | `create_ui_root`, `create_control`, `create_label`, `create_button`, `create_panel`, `create_texture_rect`, `create_container`, `set_control_layout`, `set_control_size_flags`, `set_control_text`, `set_control_theme_override`, `set_control_texture`, `connect_node_signal` |
| **Project / Addons** | `get_project_info`, `list_project_features`, `plan_asset_import`, `get_project_skills_status`, `generate_project_skills`, `select_file`, `list_addons`, `set_addon_enabled` |
| **Capture / Execution** | `capture_editor_view`, `execute_code` |

## Repository Layout

- `addons/funplay_mcp/plugin.gd` — Godot editor plugin entry
- `addons/funplay_mcp/core/` — MCP server, tools, resources, prompts, settings, and config writers
- `addons/funplay_mcp/ui/` — Godot dock UI
- `stdio-wrapper/` — npm stdio bridge for clients that cannot connect to HTTP MCP directly
- `server.json` — MCP Registry metadata for the stdio wrapper
- `scripts/package_release.py` — release artifact builder and package validator
- `ASSET_LIBRARY.md` — Godot Asset Library packaging, submission, and update-safety notes
- `CHANGELOG.md` — user-facing changes
- `CONTRIBUTING.md` — contributor workflow
- `RELEASE_CHECKLIST.md` — release process

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

This repository is licensed under [MIT](./LICENSE).
