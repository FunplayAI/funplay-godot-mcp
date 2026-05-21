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
	]


func read_resource(uri: String) -> Dictionary:
	if uri == "godot://project/context":
		return _content_response(uri, _core_tools.get_project_info({}), "application/json")
	if uri == "godot://scene/current":
		return _content_response(uri, _core_tools.get_scene_tree({}), "application/json")
	if uri == "godot://selection/current":
		return _content_response(uri, _core_tools.get_selection({}), "application/json")
	if uri == "godot://interaction/history":
		return _content_response(uri, JSON.stringify(_get_interaction_log(), "\t"), "application/json")
	if uri == "godot://project/skills":
		return _content_response(uri, _core_tools.get_project_skills_status({}), "application/json")
	if uri == "godot://tools/catalog":
		return _content_response(uri, _core_tools.list_tool_catalog({"include_hidden": true}), "application/json")
	if uri == "godot://capabilities/status":
		return _content_response(uri, _core_tools.get_capability_status({}), "application/json")
	if uri == "godot://runtime/bridge":
		return _content_response(uri, _core_tools.get_runtime_bridge_status({}), "application/json")
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
