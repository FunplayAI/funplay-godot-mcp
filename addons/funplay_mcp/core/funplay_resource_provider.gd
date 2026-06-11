@tool
extends RefCounted

const FunplayCoreTools = preload("res://addons/funplay_mcp/core/funplay_core_tools.gd")

var _plugin
var _settings
var _tool_registry
var _core_tools
var _interaction_log_getter: Callable


func _init(plugin, settings) -> void:
	_plugin = plugin
	_settings = settings
	_core_tools = FunplayCoreTools.new(plugin, settings)


func set_interaction_log_getter(getter: Callable) -> void:
	_interaction_log_getter = getter


func set_tool_registry(tool_registry) -> void:
	_tool_registry = tool_registry
	if _core_tools != null and _core_tools.has_method("set_tool_registry"):
		_core_tools.set_tool_registry(tool_registry)


func list_resources() -> Array:
	var resources: Array = [
		{
			"uri": "godot://project/context",
			"name": "Project Context",
			"description": "High-level Godot project and editor context.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://project/map",
			"name": "Project Map",
			"description": "Lightweight scene, script, dependency, signal, function, and graph map.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://project/map.html",
			"name": "Project Map HTML",
			"description": "Self-contained read-only HTML project visualizer.",
			"mimeType": "text/html",
		},
		{
			"uri": "godot://scene/current",
			"name": "Current Scene",
			"description": "Structured view of the currently edited scene tree.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://selection/current",
			"name": "Current Selection",
			"description": "Current editor selection.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://interaction/history",
			"name": "Interaction History",
			"description": "Recent MCP tool activity log.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://project/skills",
			"name": "Project Skills",
			"description": "Generated Funplay project skill status and file paths.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://templates/catalog",
			"name": "Template Catalog",
			"description": "Bundled prompt/resource templates for UI, networking, performance, architecture, assets, and update safety.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://tools/catalog",
			"name": "Tool Catalog",
			"description": "Grouped tool catalog with exposure status and schemas.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://capabilities/status",
			"name": "Capability Status",
			"description": "Detected editor, project, protocol, undo/redo, and runtime bridge capabilities.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://runtime/bridge",
			"name": "Runtime Bridge",
			"description": "Runtime bridge install status and latest play-mode heartbeat state.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://runtime/scene_tree",
			"name": "Runtime Scene Tree",
			"description": "Latest play-mode scene tree snapshot written by the runtime bridge.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://workflow/coverage",
			"name": "Workflow Coverage",
			"description": "Coverage matrix for high-value Funplay MCP Godot workflows.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://logs/recent",
			"name": "Recent Logs",
			"description": "Recent lines from Godot's project log files.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://scripts/errors",
			"name": "Script Errors",
			"description": "Script validation summary for the active project language.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://project/features",
			"name": "Project Features",
			"description": "Main scene, input actions, autoloads, and key project settings.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://project/settings",
			"name": "Project Settings",
			"description": "ProjectSettings entries and their current values.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://input/actions",
			"name": "Input Actions",
			"description": "InputMap actions and configured input events.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://autoloads/list",
			"name": "Autoloads",
			"description": "Configured project autoload singletons.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://play/state",
			"name": "Play State",
			"description": "Current play-mode state and time scale.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://performance/snapshot",
			"name": "Performance Snapshot",
			"description": "Lightweight editor/runtime metrics.",
			"mimeType": "application/json",
		},
		{
			"uri": "godot://scenes/list",
			"name": "Scene List",
			"description": "Project scenes and currently open scenes.",
			"mimeType": "application/json",
		},
	]
	var language_mode: String = _core_tools.detect_script_language_mode()
	if language_mode == "dotnet" or language_mode == "mixed":
		resources.append({
			"uri": "godot://dotnet/project",
			"name": "Dotnet Project",
			"description": "Godot .NET project metadata, C# files, and project files.",
			"mimeType": "application/json",
		})
	return resources


func list_resource_templates() -> Array:
	return [
		{
			"uriTemplate": "godot://file/{path}",
			"name": "Project File",
			"description": "Read a project file from res:// by relative path.",
			"mimeType": "text/plain",
		},
		{
			"uriTemplate": "godot://scene/file/{path}",
			"name": "Scene File",
			"description": "Read a scene file from res:// by relative path.",
			"mimeType": "text/plain",
		},
		{
			"uriTemplate": "godot://templates/{name}",
			"name": "Implementation Template",
			"description": "Read a bundled implementation template by name.",
			"mimeType": "text/markdown",
		},
	]


func read_resource(uri: String) -> Dictionary:
	if uri == "godot://project/context":
		return _content_response(uri, _core_tools.get_project_info({}), "application/json")
	if uri == "godot://project/map":
		return _content_response(uri, _core_tools.map_project({"format": "json", "max_files": 300, "max_script_members": 60}), "application/json")
	if uri == "godot://project/map.html":
		return _content_response(uri, _core_tools.map_project({"format": "html", "max_files": 500, "max_script_members": 120}), "text/html")
	if uri == "godot://scene/current":
		return _content_response(uri, _core_tools.get_scene_tree({}), "application/json")
	if uri == "godot://selection/current":
		return _content_response(uri, _core_tools.get_selection({}), "application/json")
	if uri == "godot://interaction/history":
		return _content_response(uri, JSON.stringify(_get_interaction_log(), "\t"), "application/json")
	if uri == "godot://project/skills":
		return _content_response(uri, _core_tools.get_project_skills_status({}), "application/json")
	if uri == "godot://templates/catalog":
		return _content_response(uri, JSON.stringify(_template_catalog(), "\t"), "application/json")
	if uri == "godot://tools/catalog":
		return _content_response(uri, _core_tools.list_tool_catalog({"include_hidden": true}), "application/json")
	if uri == "godot://capabilities/status":
		return _content_response(uri, _core_tools.get_capability_status({}), "application/json")
	if uri == "godot://runtime/bridge":
		return _content_response(uri, _core_tools.get_runtime_bridge_status({}), "application/json")
	if uri == "godot://runtime/scene_tree":
		return _content_response(uri, _runtime_scene_tree(), "application/json")
	if uri == "godot://workflow/coverage":
		return _content_response(uri, _core_tools.list_workflow_coverage({}), "application/json")
	if uri == "godot://logs/recent":
		return _content_response(uri, _core_tools.get_console_logs({}), "application/json")
	if uri == "godot://scripts/errors":
		return _content_response(uri, _core_tools.get_script_errors({}), "application/json")
	if uri == "godot://dotnet/project":
		return _content_response(uri, _core_tools.get_dotnet_project_info({}), "application/json")
	if uri == "godot://project/features":
		return _content_response(uri, _core_tools.list_project_features({}), "application/json")
	if uri == "godot://project/settings":
		return _content_response(uri, _core_tools.list_project_settings({}), "application/json")
	if uri == "godot://input/actions":
		return _content_response(uri, _core_tools.list_input_actions({}), "application/json")
	if uri == "godot://autoloads/list":
		return _content_response(uri, _core_tools.list_autoloads({}), "application/json")
	if uri == "godot://play/state":
		return _content_response(uri, _core_tools.get_play_state({}), "application/json")
	if uri == "godot://performance/snapshot":
		return _content_response(uri, _core_tools.get_performance_snapshot({}), "application/json")
	if uri == "godot://scenes/list":
		return _content_response(uri, _core_tools.list_scenes({}), "application/json")
	if uri.begins_with("godot://file/"):
		var relative_path: String = uri.trim_prefix("godot://file/")
		return _content_response(uri, _read_project_file(relative_path), "text/plain")
	if uri.begins_with("godot://scene/file/"):
		var scene_relative_path: String = uri.trim_prefix("godot://scene/file/")
		return _content_response(uri, _read_project_file(scene_relative_path), "text/plain")
	if uri.begins_with("godot://templates/"):
		var template_name: String = uri.trim_prefix("godot://templates/").strip_edges().to_lower()
		return _content_response(uri, _template_markdown(template_name), "text/markdown")

	return {
		"contents": [{
			"uri": uri,
			"mimeType": "text/plain",
			"text": "Error: Unknown resource '%s'." % uri,
		}],
	}


func _content_response(uri: String, text: String, mime_type: String) -> Dictionary:
	return {
		"contents": [{
			"uri": uri,
			"mimeType": mime_type,
			"text": text,
		}],
	}


func _get_interaction_log() -> Array:
	if _interaction_log_getter.is_valid():
		return _interaction_log_getter.call()
	return []


func _read_project_file(relative_path: String) -> String:
	var path: String = relative_path
	if not path.begins_with("res://"):
		path = ("res://" + path.trim_prefix("/")).simplify_path()
	else:
		path = path.simplify_path()

	if not FileAccess.file_exists(path):
		return "Error: File not found: %s" % path

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "Error: Failed to open file: %s" % path

	return file.get_as_text()


func _runtime_scene_tree() -> String:
	var parsed = JSON.parse_string(_core_tools.get_runtime_bridge_status({}))
	if not (parsed is Dictionary):
		return JSON.stringify({"available": false, "error": "Runtime bridge status is unavailable."}, "\t")
	var state: Dictionary = {}
	var state_value = parsed.get("state", {})
	if state_value is Dictionary:
		state = state_value
	if state.is_empty() or not state.has("scene_tree"):
		return JSON.stringify({
			"available": false,
			"installed": bool(parsed.get("installed", false)),
			"state_exists": bool(parsed.get("state_exists", false)),
			"message": "Install the runtime bridge and enter play mode to populate scene_tree.",
		}, "\t")
	return JSON.stringify({
		"available": true,
		"timestamp": state.get("timestamp", ""),
		"status": state.get("status", ""),
		"fps": state.get("fps", 0),
		"time_scale": state.get("time_scale", 1.0),
		"paused": state.get("paused", false),
		"current_scene": state.get("current_scene"),
		"scene_tree": state.get("scene_tree"),
		"truncated": bool(state.get("scene_tree_truncated", false)),
	}, "\t")


func _template_catalog() -> Array:
	return [
		{
			"name": "ui_screen",
			"description": "Control tree, layout, theme, and validation checklist for a UI screen or HUD.",
		},
		{
			"name": "network_system",
			"description": "Autoload, message schema, connection lifecycle, and test plan for Godot networking.",
		},
		{
			"name": "performance_review",
			"description": "Evidence-first performance review template using counters, logs, scene complexity, and project map.",
		},
		{
			"name": "architecture_review",
			"description": "Scene/script ownership, dependency, autoload, and migration review template.",
		},
		{
			"name": "asset_pipeline",
			"description": "Optional CC0 asset search/download workflow with license capture and safe import paths.",
		},
		{
			"name": "release_update_safety",
			"description": "Release package checksum and updater allowlist design notes.",
		},
	]


func _template_markdown(name: String) -> String:
	match name:
		"ui_screen":
			return "\n".join([
				"# UI Screen Template",
				"",
				"Use this for HUDs, menus, popups, inspectors, and tool panels.",
				"",
				"1. Define the user flow and primary state.",
				"2. Create a CanvasLayer or root Control with named containers.",
				"3. Use anchors, containers, size flags, and theme overrides instead of absolute positioning.",
				"4. Connect signals through named methods and verify with get_scene_tree plus UI-specific tool calls.",
				"5. Add responsive checks for long text, small viewport, focus order, and disabled/loading states.",
			])
		"network_system":
			return "\n".join([
				"# Network System Template",
				"",
				"Use this for multiplayer, WebSocket, HTTP, relay, or backend-backed gameplay.",
				"",
				"1. Put connection lifecycle in one autoload, not scattered scene scripts.",
				"2. Define message dictionaries with version, type, request_id, payload, and error fields.",
				"3. Separate transport, serialization, gameplay handlers, and retry/backoff policy.",
				"4. Add editor-testable fake transport hooks before wiring live services.",
				"5. Validate connect, disconnect, timeout, malformed message, and scene transition behavior.",
			])
		"performance_review":
			return "\n".join([
				"# Performance Review Template",
				"",
				"Use this when frame time, memory, scene load, draw calls, physics, or script hot paths are suspicious.",
				"",
				"1. Capture performance counters, recent logs, script errors, scene complexity, and project map.",
				"2. Separate measured facts from hypotheses.",
				"3. Rank fixes by expected impact and implementation risk.",
				"4. Prefer scene/node count, resource loading, physics tick, signal churn, and allocation checks before broad rewrites.",
				"5. Re-run the same measurement after each fix.",
			])
		"architecture_review":
			return "\n".join([
				"# Architecture Review Template",
				"",
				"Use this to clean up scene boundaries, script ownership, dependency direction, and project conventions.",
				"",
				"1. Start from map_project and find large scenes, highly reused scripts, and dependency cycles.",
				"2. Assign ownership for gameplay, UI, persistence, networking, and editor-only code.",
				"3. Keep autoloads small and stable; move feature logic back into scenes/resources where possible.",
				"4. Create migration slices that keep existing scenes loadable.",
				"5. Validate with scene open/save, script errors, play-state smoke tests, and find_usages.",
			])
		"asset_pipeline":
			return "\n".join([
				"# Asset Pipeline Template",
				"",
				"Use this for optional CC0 or permissive asset discovery and import workflows.",
				"",
				"1. Search approved sources only after the user asks for network asset lookup.",
				"2. Capture source URL, license, author/pack name, checksum, and download time.",
				"3. Import under res://assets/imported/<source>/<pack>/ and never overwrite existing project files by default.",
				"4. Store attribution and license metadata next to imported files.",
				"5. Trigger filesystem scan, then return imported paths and suggested usage steps.",
			])
		"release_update_safety":
			return "\n".join([
				"# Release Update Safety Template",
				"",
				"Use this before adding automatic update or package import flows.",
				"",
				"1. Verify release artifact checksums before unpacking or installing.",
				"2. Allow writes only under res://addons/funplay_mcp/ unless a future installer explicitly asks for broader scope.",
				"3. Reject absolute paths, parent-directory traversal, symlinks, hidden local metadata, and host project config writes.",
				"4. Dry-run the file list and report added, changed, and skipped paths before writing.",
				"5. Keep manual install as the fallback when safety checks fail.",
			])
		_:
			return "Error: Unknown template '%s'. Read godot://templates/catalog for available names." % name
