@tool
extends RefCounted

const FunplayCoreTools = preload("res://addons/funplay_mcp/core/funplay_core_tools.gd")

var _plugin
var _settings
var _core_tools
var _tools: Dictionary = {}
var _profiles: Dictionary = {
	"core": [],
	"full": [],
}


func _init(plugin, settings) -> void:
	_plugin = plugin
	_settings = settings
	_core_tools = FunplayCoreTools.new(plugin, settings)
	if _core_tools.has_method("set_tool_registry"):
		_core_tools.set_tool_registry(self)
	_register_tools()


func list_tools(profile: String) -> Array:
	var selected_profile: String = profile if profile in _profiles else "core"
	var tools: Array = []
	for tool_name in _profiles[selected_profile]:
		if is_tool_allowed(tool_name, selected_profile):
			tools.append(_tools[tool_name]["definition"])
	return tools


func call_tool(name: String, arguments: Dictionary) -> String:
	if not _tools.has(name):
		return "Error: Unknown tool '%s'." % name
	if not is_tool_allowed(name, _settings.tool_profile):
		return "Error: Tool '%s' is not exposed by the current profile '%s'." % [name, _settings.tool_profile]
	return _tools[name]["handler"].call(arguments)


func has_tool(name: String) -> bool:
	return _tools.has(name)


func is_tool_allowed(name: String, profile: String) -> bool:
	var selected_profile: String = profile if profile in _profiles else "core"
	if not (name in _profiles[selected_profile]):
		return false
	if not _tools.has(name):
		return false
	if _settings != null and _settings.has_method("is_tool_disabled") and _settings.is_tool_disabled(name):
		return false
	var language_modes: Array = _tools[name].get("language_modes", ["universal"])
	if "universal" in language_modes:
		return true
	var current_mode: String = _core_tools.detect_script_language_mode()
	return current_mode in language_modes


func get_tool_names(profile: String) -> Array:
	var selected_profile: String = profile if profile in _profiles else "core"
	var names: Array = []
	for tool_name in _profiles[selected_profile]:
		if is_tool_allowed(tool_name, selected_profile):
			names.append(tool_name)
	return names


func get_tool_exposure(profile: String, detected_language_mode: String = "") -> Array:
	var selected_profile: String = profile if profile in _profiles else "core"
	var language_mode: String = detected_language_mode if detected_language_mode != "" else _core_tools.detect_script_language_mode()
	var tools: Array = []
	for tool_name in _profiles[selected_profile]:
		if not _tools.has(tool_name):
			continue

		var tool_data: Dictionary = _tools[tool_name]
		var language_modes: Array = tool_data.get("language_modes", ["universal"])
		var language_allowed: bool = "universal" in language_modes or language_mode in language_modes
		var disabled: bool = _settings != null and _settings.has_method("is_tool_disabled") and _settings.is_tool_disabled(tool_name)
		var definition: Dictionary = tool_data.get("definition", {})
		tools.append({
			"name": tool_name,
			"description": str(definition.get("description", "")),
			"profiles": _get_tool_profiles(tool_name),
			"language_modes": language_modes,
			"language_allowed": language_allowed,
			"disabled": disabled,
			"exposed": language_allowed and not disabled,
		})
	return tools


func get_exposure_summary(profile: String) -> Dictionary:
	var language_mode: String = _core_tools.detect_script_language_mode()
	var tools: Array = get_tool_exposure(profile, language_mode)
	var exposed_count: int = 0
	var disabled_count: int = 0
	var language_hidden_count: int = 0
	for tool in tools:
		if bool(tool.get("exposed", false)):
			exposed_count += 1
		elif bool(tool.get("disabled", false)):
			disabled_count += 1
		else:
			language_hidden_count += 1
	return {
		"profile": profile if profile in _profiles else "core",
		"language_mode": language_mode,
		"total_in_profile": tools.size(),
		"exposed": exposed_count,
		"disabled": disabled_count,
		"language_hidden": language_hidden_count,
		"tools": tools,
	}


func get_tool_catalog(profile: String, group_filter: String = "", include_hidden: bool = true) -> Dictionary:
	var selected_profile: String = profile if profile in _profiles else "core"
	var language_mode: String = _core_tools.detect_script_language_mode()
	var groups: Dictionary = {}
	var tools: Array = []
	for tool_name in _profiles[selected_profile]:
		if not _tools.has(tool_name):
			continue

		var tool_data: Dictionary = _tools[tool_name]
		var group_name: String = str(tool_data.get("group", "other"))
		if group_filter.strip_edges() != "" and group_name != group_filter:
			continue

		var language_modes: Array = tool_data.get("language_modes", ["universal"])
		var language_allowed: bool = "universal" in language_modes or language_mode in language_modes
		var disabled: bool = _settings != null and _settings.has_method("is_tool_disabled") and _settings.is_tool_disabled(tool_name)
		var exposed: bool = language_allowed and not disabled
		if not include_hidden and not exposed:
			continue

		var definition: Dictionary = tool_data.get("definition", {})
		var entry: Dictionary = {
			"name": tool_name,
			"group": group_name,
			"description": str(definition.get("description", "")),
			"inputSchema": definition.get("inputSchema", {}),
			"profiles": _get_tool_profiles(tool_name),
			"language_modes": language_modes,
			"exposed": exposed,
			"hidden_reason": _tool_hidden_reason(language_allowed, disabled),
		}
		tools.append(entry)
		if not groups.has(group_name):
			groups[group_name] = {
				"name": group_name,
				"description": _group_description(group_name),
				"tools": [],
			}
		groups[group_name]["tools"].append(tool_name)

	var sorted_groups: Array = []
	for group_name in groups.keys():
		var group_entry: Dictionary = groups[group_name]
		group_entry["tool_count"] = group_entry["tools"].size()
		sorted_groups.append(group_entry)
	sorted_groups.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))

	return {
		"profile": selected_profile,
		"language_mode": language_mode,
		"group_filter": group_filter,
		"include_hidden": include_hidden,
		"group_count": sorted_groups.size(),
		"tool_count": tools.size(),
		"groups": sorted_groups,
		"tools": tools,
	}


func _register_tools() -> void:
	_register_tool("execute_code", "Primary high-flexibility Godot editor execution tool. Runs a GDScript snippet inside run(ctx), with context helpers, logs, and change tracking.", {
		"type": "object",
		"properties": {
			"code": {"type": "string"},
			"context_mode": {"type": "string", "enum": ["dictionary", "object"], "default": "dictionary"},
			"include_metadata": {"type": "boolean", "default": true},
			"safety_checks": {"type": "boolean", "default": true},
		},
		"required": ["code"],
	}, "execute_code", ["core", "full"])

	_register_tool("get_project_info", "Return current Godot project metadata and editor context.", _empty_schema(), "get_project_info", ["core", "full"])
	_register_tool("get_scene_info", "Return focused information about the currently edited scene.", _empty_schema(), "get_scene_info", ["core", "full"])
	_register_tool("get_scene_tree", "Return a structured summary of the currently edited scene tree.", {
		"type": "object",
		"properties": {"max_depth": {"type": "integer", "default": 4}},
	}, "get_scene_tree", ["core", "full"])
	_register_tool("get_selection", "Return the current editor node selection.", _empty_schema(), "get_selection", ["core", "full"])
	_register_tool("map_project", "Return a lightweight project map as structured JSON or self-contained HTML with scenes, scripts, dependencies, signals, functions, and graph edges.", {
		"type": "object",
		"properties": {
			"format": {"type": "string", "enum": ["json", "html"], "default": "json"},
			"include_scripts": {"type": "boolean", "default": true},
			"include_graph": {"type": "boolean", "default": true},
			"max_files": {"type": "integer", "default": 300},
			"max_script_members": {"type": "integer", "default": 80},
		},
	}, "map_project", ["core", "full"])
	_register_tool("find_usages", "Find textual usages of a symbol across project text files with line numbers and snippets.", {
		"type": "object",
		"properties": {
			"symbol": {"type": "string"},
			"path": {"type": "string", "default": "res://"},
			"case_sensitive": {"type": "boolean", "default": true},
			"max_results": {"type": "integer", "default": 200},
		},
		"required": ["symbol"],
	}, "find_usages", ["core", "full"])
	_register_tool("plan_script_refactor", "Preview a safe text-based script refactor across project scripts before applying it.", {
		"type": "object",
		"properties": {
			"operation": {"type": "string", "enum": ["rename_symbol", "replace_text"], "default": "rename_symbol"},
			"symbol": {"type": "string"},
			"new_name": {"type": "string"},
			"find": {"type": "string"},
			"replace": {"type": "string"},
			"path": {"type": "string", "default": "res://"},
			"language": {"type": "string", "enum": ["auto", "gdscript", "dotnet", "mixed"], "default": "auto"},
			"include_resources": {"type": "boolean", "default": false},
			"case_sensitive": {"type": "boolean", "default": true},
			"max_files": {"type": "integer", "default": 300},
			"max_matches_per_file": {"type": "integer", "default": 60},
		},
	}, "plan_script_refactor", ["core", "full"])
	_register_tool("apply_script_refactor", "Apply a previously reviewed script refactor with explicit apply and confirm flags.", {
		"type": "object",
		"properties": {
			"operation": {"type": "string", "enum": ["rename_symbol", "replace_text"], "default": "rename_symbol"},
			"symbol": {"type": "string"},
			"new_name": {"type": "string"},
			"find": {"type": "string"},
			"replace": {"type": "string"},
			"path": {"type": "string", "default": "res://"},
			"language": {"type": "string", "enum": ["auto", "gdscript", "dotnet", "mixed"], "default": "auto"},
			"include_resources": {"type": "boolean", "default": false},
			"case_sensitive": {"type": "boolean", "default": true},
			"max_files": {"type": "integer", "default": 300},
			"max_matches_per_file": {"type": "integer", "default": 60},
			"apply": {"type": "boolean", "default": false},
			"confirm": {"type": "boolean", "default": false},
			"create_backup": {"type": "boolean", "default": false},
		},
	}, "apply_script_refactor", ["full"])
	_register_tool("list_scenes", "List scene files in the project and report currently open scenes.", {
		"type": "object",
		"properties": {
			"path": {"type": "string", "default": "res://"},
			"recursive": {"type": "boolean", "default": true},
			"max_entries": {"type": "integer", "default": 300},
		},
	}, "list_scenes", ["core", "full"])
	_register_tool("open_scene", "Open a scene in the Godot editor.", {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"set_inherited": {"type": "boolean", "default": false},
		},
		"required": ["path"],
	}, "open_scene", ["core", "full"])
	_register_tool("save_scene", "Save the currently edited scene.", _empty_schema(), "save_scene", ["core", "full"])
	_register_tool("save_scene_as", "Save the currently edited scene to a new path.", {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"with_preview": {"type": "boolean", "default": true},
		},
		"required": ["path"],
	}, "save_scene_as", ["core", "full"])

	_register_tool("list_files", "List project files under res://.", {
		"type": "object",
		"properties": {
			"path": {"type": "string", "default": "res://"},
			"recursive": {"type": "boolean", "default": true},
			"include_hidden": {"type": "boolean", "default": false},
			"max_entries": {"type": "integer", "default": 200},
		},
	}, "list_files", ["core", "full"])
	_register_tool("search_files", "Search files by path and optionally file contents.", {
		"type": "object",
		"properties": {
			"path": {"type": "string", "default": "res://"},
			"pattern": {"type": "string"},
			"mode": {"type": "string", "enum": ["path", "content", "both"], "default": "path"},
			"recursive": {"type": "boolean", "default": true},
			"max_results": {"type": "integer", "default": 100},
		},
		"required": ["pattern"],
	}, "search_files", ["core", "full"])
	_register_tool("file_exists", "Check whether a file, directory, or resource exists.", {
		"type": "object",
		"properties": {"path": {"type": "string"}},
		"required": ["path"],
	}, "file_exists", ["core", "full"])
	_register_tool("read_file", "Read a UTF-8 text file from the project.", {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"max_chars": {"type": "integer", "default": 12000},
		},
		"required": ["path"],
	}, "read_file", ["core", "full"])
	_register_tool("write_file", "Write a UTF-8 text file into the project.", {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"content": {"type": "string"},
		},
		"required": ["path", "content"],
	}, "write_file", ["core", "full"])

	_register_tool("create_script", "Create a GDScript file from a lightweight template.", {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"language": {"type": "string", "enum": ["auto", "gdscript", "dotnet", "csharp"], "default": "auto"},
			"extends": {"type": "string", "default": "Node"},
			"class_name": {"type": "string"},
			"namespace": {"type": "string"},
			"body": {"type": "string"},
			"tool": {"type": "boolean", "default": false},
			"partial": {"type": "boolean", "default": true},
			"include_system": {"type": "boolean", "default": false},
			"open_in_editor": {"type": "boolean", "default": true},
		},
		"required": ["path"],
	}, "create_script", ["core", "full"])
	_register_tool("list_scripts", "List project scripts for the active or requested language.", {
		"type": "object",
		"properties": {
			"path": {"type": "string", "default": "res://"},
			"language": {"type": "string", "enum": ["auto", "gdscript", "dotnet", "mixed"], "default": "auto"},
			"recursive": {"type": "boolean", "default": true},
			"max_entries": {"type": "integer", "default": 300},
		},
	}, "list_scripts", ["core", "full"])
	_register_tool("get_dotnet_project_info", "Return Godot .NET project metadata, .csproj/.sln files, and C# script inventory.", _empty_schema(), "get_dotnet_project_info", ["core", "full"], ["dotnet", "mixed"])
	_register_tool("edit_script", "Overwrite a script file with new contents.", {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"content": {"type": "string"},
		},
		"required": ["path", "content"],
	}, "edit_script", ["core", "full"])
	_register_tool("patch_script", "Patch a script file with replace/prepend/append operations.", {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"find": {"type": "string"},
			"replace": {"type": "string"},
			"prepend": {"type": "string"},
			"append": {"type": "string"},
		},
		"required": ["path"],
	}, "patch_script", ["core", "full"])
	_register_tool("open_script", "Open a script in Godot’s script editor.", {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"line": {"type": "integer", "default": -1},
			"column": {"type": "integer", "default": 0},
		},
		"required": ["path"],
	}, "open_script", ["core", "full"])

	_register_tool("get_play_state", "Return whether the editor is currently playing a scene.", _empty_schema(), "get_play_state", ["core", "full"])
	_register_tool("enter_play_mode", "Enter play mode using the current, main, or a custom scene.", {
		"type": "object",
		"properties": {
			"mode": {"type": "string", "enum": ["current", "main", "custom"], "default": "current"},
			"scene_path": {"type": "string"},
		},
	}, "enter_play_mode", ["core", "full"])
	_register_tool("play_main_scene", "Play the project’s configured main scene.", _empty_schema(), "play_main_scene", ["core", "full"])
	_register_tool("exit_play_mode", "Stop the scene currently running in the editor.", _empty_schema(), "exit_play_mode", ["core", "full"])
	_register_tool("simulate_action", "Simulate a Godot input action press, release, or tap. Most useful during play mode.", {
		"type": "object",
		"properties": {
			"action": {"type": "string"},
			"mode": {"type": "string", "enum": ["press", "release", "tap"], "default": "tap"},
			"strength": {"type": "number", "default": 1.0},
		},
		"required": ["action"],
	}, "simulate_action", ["core", "full"])
	_register_tool("simulate_key_event", "Simulate a keyboard event by key name, keycode, or physical keycode. Most useful during play mode.", {
		"type": "object",
		"properties": {
			"key": {},
			"physical_key": {},
			"mode": {"type": "string", "enum": ["press", "release", "tap"], "default": "tap"},
		},
	}, "simulate_key_event", ["core", "full"])
	_register_tool("simulate_mouse_button", "Simulate a mouse button press, release, or tap. Most useful during play mode.", {
		"type": "object",
		"properties": {
			"button": {},
			"position": {},
			"mode": {"type": "string", "enum": ["press", "release", "tap"], "default": "tap"},
		},
	}, "simulate_mouse_button", ["core", "full"])
	_register_tool("simulate_mouse_drag", "Simulate a mouse drag from one position to another. Most useful during play mode.", {
		"type": "object",
		"properties": {
			"button": {},
			"from_position": {},
			"to_position": {},
			"steps": {"type": "integer", "default": 8},
		},
		"required": ["from_position", "to_position"],
	}, "simulate_mouse_drag", ["core", "full"])
	_register_tool("simulate_input_sequence", "Simulate a sequence of action/key/mouse input events.", {
		"type": "object",
		"properties": {
			"events": {"type": "array"},
		},
		"required": ["events"],
	}, "simulate_input_sequence", ["core", "full"])
	_register_tool("get_time_scale", "Return the current Engine.time_scale.", _empty_schema(), "get_time_scale", ["core", "full"])
	_register_tool("set_time_scale", "Set Engine.time_scale.", {
		"type": "object",
		"properties": {"value": {"type": "number"}},
		"required": ["value"],
	}, "set_time_scale", ["core", "full"])

	_register_tool("get_performance_snapshot", "Return lightweight editor/runtime metrics useful during validation.", _empty_schema(), "get_performance_snapshot", ["core", "full"])
	_register_tool("analyze_scene_complexity", "Estimate scene complexity from the current edited scene tree.", _empty_schema(), "analyze_scene_complexity", ["core", "full"])
	_register_tool("get_console_logs", "Read recent lines from Godot's file logs for this project.", {
		"type": "object",
		"properties": {
			"max_lines": {"type": "integer", "default": 200},
			"include_rotated": {"type": "boolean", "default": true},
			"severity": {"type": "string", "enum": ["all", "info", "warning", "error"], "default": "all"},
			"filter": {"type": "string"},
		},
	}, "get_console_logs", ["core", "full"])
	_register_tool("validate_script", "Validate a GDScript or C# script using the active/requested language workflow.", {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"language": {"type": "string", "enum": ["auto", "gdscript", "dotnet", "csharp"], "default": "auto"},
			"run_build": {"type": "boolean", "default": false},
			"target": {"type": "string"},
			"configuration": {"type": "string", "default": "Debug"},
		},
		"required": ["path"],
	}, "validate_script", ["core", "full"])
	_register_tool("get_script_errors", "Compile-check GDScript files under a path and return files that fail to reload.", {
		"type": "object",
		"properties": {
			"path": {"type": "string", "default": "res://"},
			"language": {"type": "string", "enum": ["auto", "gdscript", "dotnet", "mixed"], "default": "auto"},
			"max_files": {"type": "integer", "default": 200},
			"run_build": {"type": "boolean", "default": true},
			"target": {"type": "string"},
			"configuration": {"type": "string", "default": "Debug"},
		},
	}, "get_script_errors", ["core", "full"])
	_register_tool("request_script_reload", "Reload one script or rescan the Godot resource filesystem.", {
		"type": "object",
		"properties": {"path": {"type": "string"}},
	}, "request_script_reload", ["core", "full"])
	_register_tool("log_message", "Write a message to Godot output using print, push_warning, or push_error.", {
		"type": "object",
		"properties": {
			"message": {"type": "string"},
			"level": {"type": "string", "enum": ["info", "warning", "error"], "default": "info"},
		},
		"required": ["message"],
	}, "log_message", ["core", "full"])
	_register_tool("list_tool_catalog", "Return a grouped tool catalog with profiles, exposure, schemas, and hidden reasons.", {
		"type": "object",
		"properties": {
			"profile": {"type": "string", "enum": ["core", "full"]},
			"group": {"type": "string"},
			"include_hidden": {"type": "boolean", "default": true},
		},
	}, "list_tool_catalog", ["core", "full"])
	_register_tool("funplay_help", "Return workflow help for common Funplay MCP tasks and tool-selection guidance.", {
		"type": "object",
		"properties": {
			"topic": {"type": "string", "enum": ["overview", "scene", "runtime", "scripts", "refactor", "ui", "assets", "release"], "default": "overview"},
		},
	}, "funplay_help", ["core", "full"])
	_register_tool("get_capability_status", "Return detected project, editor, protocol, undo/redo, and runtime bridge capability gates.", _empty_schema(), "get_capability_status", ["core", "full"])
	_register_tool("get_editor_protocol_status", "Return Godot editor LSP and debug-adapter settings discovered from EditorSettings.", _empty_schema(), "get_editor_protocol_status", ["core", "full"])
	_register_tool("get_release_readiness", "Return release, npm wrapper, MCP Registry, Asset Library, and validation readiness checks.", {
		"type": "object",
		"properties": {
			"version": {"type": "string"},
			"include_commands": {"type": "boolean", "default": true},
		},
	}, "get_release_readiness", ["core", "full"])
	_register_tool("get_undo_redo_status", "Return availability of the Godot EditorUndoRedoManager bridge.", _empty_schema(), "get_undo_redo_status", ["core", "full"])
	_register_tool("editor_undo", "Run one editor undo step through EditorUndoRedoManager when available.", _empty_schema(), "editor_undo", ["core", "full"])
	_register_tool("editor_redo", "Run one editor redo step through EditorUndoRedoManager when available.", _empty_schema(), "editor_redo", ["core", "full"])
	_register_tool("install_runtime_bridge", "Install the Funplay runtime bridge autoload for play-mode heartbeat state.", {
		"type": "object",
		"properties": {
			"autoload_name": {"type": "string", "default": "FunplayMcpRuntimeBridge"},
			"value": {"type": "string"},
			"save": {"type": "boolean", "default": true},
		},
	}, "install_runtime_bridge", ["core", "full"])
	_register_tool("remove_runtime_bridge", "Remove the Funplay runtime bridge autoload from ProjectSettings.", {
		"type": "object",
		"properties": {
			"autoload_name": {"type": "string", "default": "FunplayMcpRuntimeBridge"},
			"save": {"type": "boolean", "default": true},
		},
	}, "remove_runtime_bridge", ["core", "full"])
	_register_tool("get_runtime_bridge_status", "Return runtime bridge install status and the latest play-mode heartbeat state.", _empty_schema(), "get_runtime_bridge_status", ["core", "full"])
	_register_tool("list_workflow_coverage", "Return a compact workflow coverage matrix for high-value Godot MCP workflows.", _empty_schema(), "list_workflow_coverage", ["core", "full"])
	_register_tool("get_project_skills_status", "Return whether Funplay project skill files have been generated.", _empty_schema(), "get_project_skills_status", ["core", "full"])
	_register_tool("generate_project_skills", "Generate Funplay project skill files and an optional AGENTS.md bridge for AI clients.", {
		"type": "object",
		"properties": {
			"endpoint": {"type": "string"},
			"include_agents_bridge": {"type": "boolean", "default": true},
		},
	}, "generate_project_skills", ["core", "full"])
	_register_tool("list_project_features", "Return project settings such as main scene, input actions, and autoloads.", _empty_schema(), "list_project_features", ["core", "full"])
	_register_tool("plan_asset_import", "Create a safe optional asset import plan and optional manifest under res://assets/imported/.", {
		"type": "object",
		"properties": {
			"source": {"type": "string", "default": "external"},
			"package_name": {"type": "string", "default": "asset_pack"},
			"license": {"type": "string", "default": "CC0-1.0"},
			"target_root": {"type": "string", "default": "res://assets/imported"},
			"assets": {"type": "array"},
			"notes": {"type": "string"},
			"create_directories": {"type": "boolean", "default": false},
			"write_manifest": {"type": "boolean", "default": false},
			"overwrite_manifest": {"type": "boolean", "default": false},
		},
	}, "plan_asset_import", ["core", "full"])
	_register_tool("list_project_settings", "List ProjectSettings entries, optionally filtered by prefix.", {
		"type": "object",
		"properties": {
			"prefix": {"type": "string"},
			"include_internal": {"type": "boolean", "default": false},
			"max_results": {"type": "integer", "default": 500},
		},
	}, "list_project_settings", ["core", "full"])
	_register_tool("get_project_setting", "Read a single ProjectSettings value.", {
		"type": "object",
		"properties": {"key": {"type": "string"}},
		"required": ["key"],
	}, "get_project_setting", ["core", "full"])
	_register_tool("set_project_setting", "Write a ProjectSettings value and optionally save project.godot.", {
		"type": "object",
		"properties": {
			"key": {"type": "string"},
			"value": {},
			"save": {"type": "boolean", "default": true},
		},
		"required": ["key", "value"],
	}, "set_project_setting", ["full"])
	_register_tool("list_input_actions", "List InputMap actions and their configured events.", _empty_schema(), "list_input_actions", ["core", "full"])
	_register_tool("get_input_action", "Read one InputMap action and its configured events.", {
		"type": "object",
		"properties": {"action": {"type": "string"}},
		"required": ["action"],
	}, "get_input_action", ["core", "full"])
	_register_tool("add_input_action", "Create an InputMap action and optionally add events.", {
		"type": "object",
		"properties": {
			"action": {"type": "string"},
			"deadzone": {"type": "number", "default": 0.2},
			"events": {"type": "array"},
			"save": {"type": "boolean", "default": true},
		},
		"required": ["action"],
	}, "add_input_action", ["full"])
	_register_tool("remove_input_action", "Remove an InputMap action.", {
		"type": "object",
		"properties": {
			"action": {"type": "string"},
			"save": {"type": "boolean", "default": true},
		},
		"required": ["action"],
	}, "remove_input_action", ["full"])
	_register_tool("add_input_event_to_action", "Add an InputEvent to an existing InputMap action.", {
		"type": "object",
		"properties": {
			"action": {"type": "string"},
			"event": {"type": "object"},
			"save": {"type": "boolean", "default": true},
		},
		"required": ["action", "event"],
	}, "add_input_event_to_action", ["full"])
	_register_tool("clear_input_events", "Remove all configured events from an InputMap action.", {
		"type": "object",
		"properties": {
			"action": {"type": "string"},
			"save": {"type": "boolean", "default": true},
		},
		"required": ["action"],
	}, "clear_input_events", ["full"])
	_register_tool("list_autoloads", "List configured autoload singletons from ProjectSettings.", _empty_schema(), "list_autoloads", ["core", "full"])
	_register_tool("set_autoload", "Add or update an autoload ProjectSettings entry.", {
		"type": "object",
		"properties": {
			"name": {"type": "string"},
			"path": {"type": "string"},
			"value": {"type": "string"},
			"save": {"type": "boolean", "default": true},
		},
		"required": ["name", "path"],
	}, "set_autoload", ["full"])
	_register_tool("remove_autoload", "Remove an autoload ProjectSettings entry.", {
		"type": "object",
		"properties": {
			"name": {"type": "string"},
			"save": {"type": "boolean", "default": true},
		},
		"required": ["name"],
	}, "remove_autoload", ["full"])
	_register_tool("assert_node_exists", "Assert that a node exists or does not exist.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"should_exist": {"type": "boolean", "default": true},
		},
		"required": ["node_path"],
	}, "assert_node_exists", ["core", "full"])
	_register_tool("assert_node_property", "Assert that a node property equals the expected value.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"property": {"type": "string"},
			"expected": {},
		},
		"required": ["node_path", "property", "expected"],
	}, "assert_node_property", ["core", "full"])
	_register_tool("assert_signal_connected", "Assert that a source signal is connected to a target method.", {
		"type": "object",
		"properties": {
			"source_path": {"type": "string"},
			"signal_name": {"type": "string"},
			"target_path": {"type": "string"},
			"method_name": {"type": "string"},
		},
		"required": ["source_path", "signal_name", "target_path", "method_name"],
	}, "assert_signal_connected", ["core", "full"])
	_register_tool("wait_msec", "Block for a short duration in milliseconds. Use sparingly for simple stabilization steps.", {
		"type": "object",
		"properties": {"duration": {"type": "integer", "default": 16, "minimum": 0, "maximum": 30000}},
	}, "wait_msec", ["core", "full"])
	_register_tool("capture_editor_view", "Capture the editor 2D or 3D viewport and optionally return a PNG data URI.", {
		"type": "object",
		"properties": {
			"view": {"type": "string", "enum": ["2d", "3d"], "default": "2d"},
			"index": {"type": "integer", "default": 0},
			"save_to_file": {"type": "boolean", "default": false},
			"save_path": {"type": "string"},
			"return_data_uri": {"type": "boolean", "default": true},
		},
	}, "capture_editor_view", ["core", "full"])

	_register_tool("get_node_info", "Return detailed information about a specific node in the edited scene.", {
		"type": "object",
		"properties": {"node_path": {"type": "string"}},
		"required": ["node_path"],
	}, "get_node_info", ["core", "full"])
	_register_tool("list_node_properties", "List reflected properties for a node, including type and hint metadata.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"include_usage": {"type": "boolean", "default": false},
		},
		"required": ["node_path"],
	}, "list_node_properties", ["core", "full"])
	_register_tool("list_node_signals", "List signals exposed by a node.", {
		"type": "object",
		"properties": {"node_path": {"type": "string"}},
		"required": ["node_path"],
	}, "list_node_signals", ["core", "full"])
	_register_tool("list_node_methods", "List methods exposed by a node.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"include_private": {"type": "boolean", "default": false},
		},
		"required": ["node_path"],
	}, "list_node_methods", ["core", "full"])
	_register_tool("find_nodes", "Find nodes in the edited scene by name, class, or attached script.", {
		"type": "object",
		"properties": {
			"name_contains": {"type": "string"},
			"class_name": {"type": "string"},
			"script_path": {"type": "string"},
			"max_results": {"type": "integer", "default": 100},
		},
	}, "find_nodes", ["core", "full"])
	_register_tool("select_node", "Select a node in the editor and optionally focus it.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"focus": {"type": "boolean", "default": true},
		},
		"required": ["node_path"],
	}, "select_node", ["core", "full"])
	_register_tool("select_file", "Select a file in the FileSystem dock.", {
		"type": "object",
		"properties": {"path": {"type": "string"}},
		"required": ["path"],
	}, "select_file", ["core", "full"])

	_register_tool("create_new_scene", "Create a new scene file with a single root node, save it, and optionally open it.", {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"root_type": {"type": "string", "default": "Node2D"},
			"root_name": {"type": "string", "default": "Main"},
			"script_path": {"type": "string"},
			"open_after": {"type": "boolean", "default": true},
		},
		"required": ["path"],
	}, "create_new_scene", ["full"])
	_register_tool("instantiate_scene", "Instantiate a scene inside the currently edited scene.", {
		"type": "object",
		"properties": {
			"scene_path": {"type": "string"},
			"parent_path": {"type": "string"},
			"name": {"type": "string"},
			"select_new_node": {"type": "boolean", "default": true},
		},
		"required": ["scene_path"],
	}, "instantiate_scene", ["full"])
	_register_tool("create_packed_scene_from_node", "Save a node subtree as a PackedScene resource.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"path": {"type": "string"},
			"select_file": {"type": "boolean", "default": true},
		},
		"required": ["node_path", "path"],
	}, "create_packed_scene_from_node", ["full"])
	_register_tool("get_packed_scene_info", "Instantiate a PackedScene temporarily and summarize its root and node tree.", {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"max_depth": {"type": "integer", "default": 3},
		},
		"required": ["path"],
	}, "get_packed_scene_info", ["full"])
	_register_tool("create_node", "Create a new node in the currently edited scene.", {
		"type": "object",
		"properties": {
			"node_type": {"type": "string"},
			"name": {"type": "string"},
			"parent_path": {"type": "string"},
			"script_path": {"type": "string"},
			"select_new_node": {"type": "boolean", "default": true},
		},
		"required": ["node_type"],
	}, "create_node", ["full"])
	_register_tool("duplicate_node", "Duplicate a node in the edited scene.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"new_name": {"type": "string"},
			"select_new_node": {"type": "boolean", "default": true},
		},
		"required": ["node_path"],
	}, "duplicate_node", ["full"])
	_register_tool("rename_node", "Rename a node in the edited scene.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"new_name": {"type": "string"},
			"undoable": {"type": "boolean", "default": true},
		},
		"required": ["node_path", "new_name"],
	}, "rename_node", ["full"])
	_register_tool("reparent_node", "Move a node under another parent node.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"new_parent_path": {"type": "string"},
			"keep_global_transform": {"type": "boolean", "default": false},
		},
		"required": ["node_path", "new_parent_path"],
	}, "reparent_node", ["full"])
	_register_tool("set_node_property", "Set a single property on a node in the edited scene.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"property": {"type": "string"},
			"value": {},
			"undoable": {"type": "boolean", "default": true},
		},
		"required": ["node_path", "property", "value"],
	}, "set_node_property", ["full"])
	_register_tool("set_node_properties", "Set multiple properties on a node in the edited scene.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"properties": {"type": "object"},
			"undoable": {"type": "boolean", "default": true},
		},
		"required": ["node_path", "properties"],
	}, "set_node_properties", ["full"])
	_register_tool("set_transform_2d", "Set transform values on a Node2D or Control.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"position": {},
			"rotation_degrees": {"type": "number"},
			"scale": {},
			"size": {},
			"undoable": {"type": "boolean", "default": true},
		},
		"required": ["node_path"],
	}, "set_transform_2d", ["full"])
	_register_tool("set_transform_3d", "Set transform values on a Node3D.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"position": {},
			"rotation_degrees": {},
			"scale": {},
			"undoable": {"type": "boolean", "default": true},
		},
		"required": ["node_path"],
	}, "set_transform_3d", ["full"])
	_register_tool("remove_node", "Remove a node from the currently edited scene.", {
		"type": "object",
		"properties": {"node_path": {"type": "string"}},
		"required": ["node_path"],
	}, "remove_node", ["full"])
	_register_tool("set_node_script", "Attach a script resource to a node.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"script_path": {"type": "string"},
		},
		"required": ["node_path", "script_path"],
	}, "set_node_script", ["full"])
	_register_tool("create_material", "Create and save a material resource.", {
		"type": "object",
		"properties": {
			"path": {"type": "string"},
			"material_type": {"type": "string", "default": "StandardMaterial3D"},
			"properties": {"type": "object"},
		},
		"required": ["path"],
	}, "create_material", ["full"])
	_register_tool("assign_material", "Assign a material to a compatible node.", {
		"type": "object",
		"properties": {
			"target_path": {"type": "string"},
			"material_path": {"type": "string"},
			"surface_index": {"type": "integer", "default": -1},
		},
		"required": ["target_path", "material_path"],
	}, "assign_material", ["full"])
	_register_tool("create_animation_player", "Create an AnimationPlayer in the current scene.", {
		"type": "object",
		"properties": {
			"name": {"type": "string"},
			"parent_path": {"type": "string"},
			"root_node": {"type": "string"},
			"select_new_node": {"type": "boolean", "default": true},
		},
	}, "create_animation_player", ["full"])
	_register_tool("create_animation_clip", "Create or replace an animation clip in an AnimationPlayer library.", {
		"type": "object",
		"properties": {
			"animation_player_path": {"type": "string"},
			"animation_name": {"type": "string"},
			"library_name": {"type": "string", "default": ""},
			"length": {"type": "number", "default": 1.0},
			"loop_mode": {"type": "integer", "default": 0},
			"step": {"type": "number", "default": 0.1},
			"set_current": {"type": "boolean", "default": true},
		},
		"required": ["animation_player_path", "animation_name"],
	}, "create_animation_clip", ["full"])
	_register_tool("add_animation_track", "Add a track and optional keys to an Animation resource in an AnimationPlayer.", {
		"type": "object",
		"properties": {
			"animation_player_path": {"type": "string"},
			"animation_name": {"type": "string"},
			"library_name": {"type": "string", "default": ""},
			"track_type": {"type": "string", "default": "value"},
			"path": {"type": "string"},
			"keys": {"type": "array"},
			"interpolation_type": {"type": "integer"},
			"update_mode": {"type": "integer"},
		},
		"required": ["animation_player_path", "animation_name", "path"],
	}, "add_animation_track", ["full"])
	_register_tool("list_animations", "List animation libraries and clips on an AnimationPlayer.", {
		"type": "object",
		"properties": {"animation_player_path": {"type": "string"}},
		"required": ["animation_player_path"],
	}, "list_animations", ["full"])
	_register_tool("play_animation", "Play an animation on an AnimationPlayer.", {
		"type": "object",
		"properties": {
			"animation_player_path": {"type": "string"},
			"animation_name": {"type": "string"},
			"custom_blend": {"type": "number", "default": -1.0},
			"custom_speed": {"type": "number", "default": 1.0},
			"from_end": {"type": "boolean", "default": false},
		},
		"required": ["animation_player_path", "animation_name"],
	}, "play_animation", ["full"])
	_register_tool("get_camera_info", "Return Camera2D or Camera3D properties.", {
		"type": "object",
		"properties": {"node_path": {"type": "string"}},
		"required": ["node_path"],
	}, "get_camera_info", ["full"])
	_register_tool("set_camera_2d", "Configure Camera2D properties such as enabled, zoom, offset, limits, and transform.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"enabled": {"type": "boolean"},
			"zoom": {},
			"offset": {},
			"position": {},
			"rotation_degrees": {"type": "number"},
			"limits": {"type": "object"},
		},
		"required": ["node_path"],
	}, "set_camera_2d", ["full"])
	_register_tool("set_camera_3d", "Configure Camera3D properties such as projection, fov, near/far, cull_mask, and transform.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"current": {"type": "boolean"},
			"projection": {"type": "integer"},
			"fov": {"type": "number"},
			"size": {"type": "number"},
			"near": {"type": "number"},
			"far": {"type": "number"},
			"cull_mask": {"type": "integer"},
			"position": {},
			"rotation_degrees": {},
		},
		"required": ["node_path"],
	}, "set_camera_3d", ["full"])
	_register_tool("create_ui_root", "Create a CanvasLayer-based or Control-based UI root in the current scene.", {
		"type": "object",
		"properties": {
			"kind": {"type": "string", "enum": ["canvas_layer", "control"], "default": "canvas_layer"},
			"name": {"type": "string"},
			"control_name": {"type": "string"},
			"parent_path": {"type": "string"},
			"layout_preset": {"type": "string", "default": "full_rect"},
			"select_new_node": {"type": "boolean", "default": true},
		},
	}, "create_ui_root", ["full"])
	_register_tool("create_control", "Create an arbitrary Control subclass node.", {
		"type": "object",
		"properties": {
			"control_type": {"type": "string"},
			"name": {"type": "string"},
			"parent_path": {"type": "string"},
			"text": {"type": "string"},
			"placeholder_text": {"type": "string"},
			"tooltip_text": {"type": "string"},
			"position": {},
			"size": {},
			"custom_minimum_size": {},
			"layout_preset": {"type": "string"},
			"horizontal_size_flags": {},
			"vertical_size_flags": {},
			"theme_type_variation": {"type": "string"},
			"select_new_node": {"type": "boolean", "default": true},
		},
		"required": ["control_type"],
	}, "create_control", ["full"])
	_register_tool("create_label", "Create a Label control.", {
		"type": "object",
		"properties": {
			"name": {"type": "string"},
			"parent_path": {"type": "string"},
			"text": {"type": "string"},
			"position": {},
			"size": {},
			"layout_preset": {"type": "string"},
			"horizontal_size_flags": {},
			"vertical_size_flags": {},
		},
	}, "create_label", ["full"])
	_register_tool("create_button", "Create a Button control.", {
		"type": "object",
		"properties": {
			"name": {"type": "string"},
			"parent_path": {"type": "string"},
			"text": {"type": "string"},
			"position": {},
			"size": {},
			"layout_preset": {"type": "string"},
			"horizontal_size_flags": {},
			"vertical_size_flags": {},
		},
	}, "create_button", ["full"])
	_register_tool("create_panel", "Create a Panel control.", {
		"type": "object",
		"properties": {
			"name": {"type": "string"},
			"parent_path": {"type": "string"},
			"position": {},
			"size": {},
			"layout_preset": {"type": "string"},
		},
	}, "create_panel", ["full"])
	_register_tool("create_texture_rect", "Create a TextureRect control.", {
		"type": "object",
		"properties": {
			"name": {"type": "string"},
			"parent_path": {"type": "string"},
			"texture_path": {"type": "string"},
			"position": {},
			"size": {},
			"layout_preset": {"type": "string"},
			"stretch_mode": {"type": "integer"},
			"expand_mode": {"type": "integer"},
		},
	}, "create_texture_rect", ["full"])
	_register_tool("create_container", "Create a BoxContainer, GridContainer, MarginContainer, or other Container subclass.", {
		"type": "object",
		"properties": {
			"container_type": {"type": "string"},
			"name": {"type": "string"},
			"parent_path": {"type": "string"},
			"position": {},
			"size": {},
			"layout_preset": {"type": "string"},
			"horizontal_size_flags": {},
			"vertical_size_flags": {},
		},
		"required": ["container_type"],
	}, "create_container", ["full"])
	_register_tool("set_control_layout", "Set layout anchors, offsets, position, size, and growth settings on a Control.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"layout_preset": {"type": "string"},
			"anchors": {"type": "object"},
			"offsets": {"type": "object"},
			"position": {},
			"size": {},
			"grow_horizontal": {"type": "integer"},
			"grow_vertical": {"type": "integer"},
			"undoable": {"type": "boolean", "default": true},
		},
		"required": ["node_path"],
	}, "set_control_layout", ["full"])
	_register_tool("set_control_size_flags", "Set horizontal and vertical size flags on a Control.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"horizontal": {},
			"vertical": {},
			"stretch_ratio": {"type": "number"},
			"undoable": {"type": "boolean", "default": true},
		},
		"required": ["node_path"],
	}, "set_control_size_flags", ["full"])
	_register_tool("set_control_text", "Set text-like properties on a Control, such as text or placeholder_text.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"property": {"type": "string", "default": "text"},
			"text": {"type": "string"},
			"undoable": {"type": "boolean", "default": true},
		},
		"required": ["node_path", "text"],
	}, "set_control_text", ["full"])
	_register_tool("set_control_theme_override", "Apply theme overrides to a Control.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"override_type": {"type": "string", "enum": ["color", "constant", "font_size", "font", "stylebox"]},
			"name": {"type": "string"},
			"value": {},
			"resource_path": {"type": "string"},
		},
		"required": ["node_path", "override_type", "name"],
	}, "set_control_theme_override", ["full"])
	_register_tool("set_control_texture", "Assign a texture to a TextureRect or other compatible Control.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"texture_path": {"type": "string"},
			"stretch_mode": {"type": "integer"},
			"expand_mode": {"type": "integer"},
		},
		"required": ["node_path", "texture_path"],
	}, "set_control_texture", ["full"])
	_register_tool("connect_node_signal", "Connect a source node signal to a target node method.", {
		"type": "object",
		"properties": {
			"source_path": {"type": "string"},
			"signal_name": {"type": "string"},
			"target_path": {"type": "string"},
			"method_name": {"type": "string"},
			"flags": {"type": "integer", "default": 0},
		},
		"required": ["source_path", "signal_name", "target_path", "method_name"],
	}, "connect_node_signal", ["full"])
	_register_tool("delete_file", "Delete a file or empty directory from the project.", {
		"type": "object",
		"properties": {"path": {"type": "string"}},
		"required": ["path"],
	}, "delete_file", ["full"])
	_register_tool("move_file", "Move or rename a project file.", {
		"type": "object",
		"properties": {
			"from_path": {"type": "string"},
			"to_path": {"type": "string"},
		},
		"required": ["from_path", "to_path"],
	}, "move_file", ["full"])
	_register_tool("copy_file", "Copy a project file.", {
		"type": "object",
		"properties": {
			"from_path": {"type": "string"},
			"to_path": {"type": "string"},
		},
		"required": ["from_path", "to_path"],
	}, "copy_file", ["full"])
	_register_tool("list_addons", "List addons under res://addons and plugin.cfg metadata.", _empty_schema(), "list_addons", ["full"])
	_register_tool("set_addon_enabled", "Enable or disable a Godot editor plugin by addon folder name when supported by the editor.", {
		"type": "object",
		"properties": {
			"addon": {"type": "string"},
			"enabled": {"type": "boolean"},
		},
		"required": ["addon", "enabled"],
	}, "set_addon_enabled", ["full"])


func _register_tool(name: String, description: String, input_schema: Dictionary, method_name: String, profiles: Array, language_modes: Array = ["universal"]) -> void:
	_tools[name] = {
		"definition": {
			"name": name,
			"description": description,
			"inputSchema": input_schema,
		},
		"handler": Callable(_core_tools, method_name),
		"language_modes": language_modes,
		"group": _infer_tool_group(name),
	}

	for profile_name in profiles:
		if not _profiles.has(profile_name):
			_profiles[profile_name] = []
		_profiles[profile_name].append(name)


func _get_tool_profiles(tool_name: String) -> Array:
	var profiles: Array = []
	for profile_name in _profiles.keys():
		if tool_name in _profiles[profile_name]:
			profiles.append(profile_name)
	profiles.sort()
	return profiles


func _tool_hidden_reason(language_allowed: bool, disabled: bool) -> String:
	if disabled:
		return "disabled_by_tool_exposure"
	if not language_allowed:
		return "hidden_by_project_language"
	return ""


func _infer_tool_group(tool_name: String) -> String:
	if tool_name in ["execute_code", "capture_editor_view", "log_message", "wait_msec"]:
		return "execution"
	if tool_name in ["funplay_help", "list_tool_catalog", "get_capability_status", "get_release_readiness", "list_workflow_coverage"]:
		return "guidance"
	if tool_name in ["map_project", "find_usages", "plan_script_refactor", "apply_script_refactor"]:
		return "project_map"
	if tool_name in ["get_editor_protocol_status", "get_script_errors", "validate_script", "request_script_reload", "get_console_logs", "get_performance_snapshot", "analyze_scene_complexity"]:
		return "diagnostics"
	if tool_name in ["get_project_info", "list_project_features", "plan_asset_import", "list_project_settings", "get_project_setting", "set_project_setting", "get_project_skills_status", "generate_project_skills"]:
		return "project"
	if tool_name in ["list_input_actions", "get_input_action", "add_input_action", "remove_input_action", "add_input_event_to_action", "clear_input_events"]:
		return "input"
	if tool_name in ["list_autoloads", "set_autoload", "remove_autoload", "install_runtime_bridge", "remove_runtime_bridge", "get_runtime_bridge_status"]:
		return "runtime"
	if tool_name in ["editor_undo", "editor_redo", "get_undo_redo_status"]:
		return "undo_redo"
	if tool_name in ["list_scenes", "open_scene", "save_scene", "save_scene_as", "create_new_scene", "instantiate_scene", "create_packed_scene_from_node", "get_packed_scene_info"]:
		return "scene"
	if tool_name in ["get_scene_info", "get_scene_tree", "get_selection", "get_node_info", "find_nodes", "select_node", "create_node", "duplicate_node", "rename_node", "reparent_node", "remove_node", "set_node_property", "set_node_properties", "set_transform_2d", "set_transform_3d", "set_node_script", "list_node_properties", "list_node_signals", "list_node_methods"]:
		return "nodes"
	if tool_name in ["create_script", "list_scripts", "get_dotnet_project_info", "edit_script", "patch_script", "open_script"]:
		return "scripts"
	if tool_name in ["get_play_state", "enter_play_mode", "play_main_scene", "exit_play_mode", "simulate_action", "simulate_key_event", "simulate_mouse_button", "simulate_mouse_drag", "simulate_input_sequence", "get_time_scale", "set_time_scale"]:
		return "play"
	if tool_name in ["assert_node_exists", "assert_node_property", "assert_signal_connected"]:
		return "assertions"
	if tool_name in ["create_animation_player", "create_animation_clip", "add_animation_track", "list_animations", "play_animation"]:
		return "animation"
	if tool_name in ["get_camera_info", "set_camera_2d", "set_camera_3d"]:
		return "camera"
	if tool_name in ["create_material", "assign_material"]:
		return "materials"
	if tool_name in ["create_ui_root", "create_control", "create_label", "create_button", "create_panel", "create_texture_rect", "create_container", "set_control_layout", "set_control_size_flags", "set_control_text", "set_control_theme_override", "set_control_texture", "connect_node_signal"]:
		return "ui"
	if tool_name in ["list_files", "search_files", "file_exists", "read_file", "write_file", "delete_file", "move_file", "copy_file", "select_file"]:
		return "files"
	if tool_name in ["list_addons", "set_addon_enabled"]:
		return "addons"
	return "other"


func _group_description(group_name: String) -> String:
	match group_name:
		"guidance":
			return "Help, tool catalog, capability status, and workflow coverage."
		"execution":
			return "Primary execution, capture, logging, and stabilization tools."
		"diagnostics":
			return "Script, log, performance, LSP/DAP, and scene diagnostic tools."
		"project_map":
			return "Project map, script relationship, and usage analysis."
		"project":
			return "Project settings, feature summaries, and Project Skills."
		"input":
			return "InputMap inspection and editing."
		"runtime":
			return "Autoloads, play-state context, and runtime bridge support."
		"undo_redo":
			return "Editor undo and redo status/commands."
		"scene":
			return "Scene file creation, opening, saving, instancing, and PackedScene workflows."
		"nodes":
			return "Node inspection, selection, mutation, transforms, and reflection."
		"scripts":
			return "GDScript and .NET script creation, editing, and navigation."
		"play":
			return "Play mode, input simulation, and time-scale control."
		"assertions":
			return "Runtime/editor assertions for validation flows."
		"animation":
			return "AnimationPlayer, animation clips, tracks, and playback."
		"camera":
			return "Camera2D and Camera3D inspection and configuration."
		"materials":
			return "Material creation and assignment."
		"ui":
			return "Godot Control and CanvasLayer UI authoring."
		"files":
			return "Project file listing, search, read/write, and file operations."
		"addons":
			return "Addon listing and plugin enable/disable support."
		_:
			return "Miscellaneous tools."


func _empty_schema() -> Dictionary:
	return {
		"type": "object",
		"properties": {},
	}
