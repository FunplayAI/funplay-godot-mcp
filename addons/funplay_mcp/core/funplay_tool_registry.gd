@tool
extends RefCounted

const FunplayCoreTools = preload("res://addons/funplay_mcp/core/funplay_core_tools.gd")

var _plugin
var _settings
var _core_tools
var _tools := {}
var _profiles := {
	"core": [],
	"full": [],
}


func _init(plugin, settings) -> void:
	_plugin = plugin
	_settings = settings
	_core_tools = FunplayCoreTools.new(plugin, settings)
	_register_tools()


func list_tools(profile: String) -> Array:
	var selected_profile := profile if profile in _profiles else "core"
	var tools: Array = []
	for tool_name in _profiles[selected_profile]:
		if _tools.has(tool_name):
			tools.append(_tools[tool_name]["definition"])
	return tools


func call_tool(name: String, arguments: Dictionary) -> String:
	if not _tools.has(name):
		return "Error: Unknown tool '%s'." % name
	if not is_tool_allowed(name, _settings.tool_profile):
		return "Error: Tool '%s' is not exposed by the current profile '%s'." % [name, _settings.tool_profile]
	return _tools[name]["handler"].call(arguments)


func is_tool_allowed(name: String, profile: String) -> bool:
	var selected_profile := profile if profile in _profiles else "core"
	return name in _profiles[selected_profile]


func get_tool_names(profile: String) -> Array:
	var selected_profile := profile if profile in _profiles else "core"
	return _profiles[selected_profile].duplicate()


func _register_tools() -> void:
	_register_tool("execute_code", "Primary high-flexibility Godot editor execution tool. Runs a GDScript snippet inside run(ctx).", {
		"type": "object",
		"properties": {"code": {"type": "string"}},
		"required": ["code"],
	}, "execute_code", ["core", "full"])

	_register_tool("get_project_info", "Return current Godot project metadata and editor context.", _empty_schema(), "get_project_info", ["core", "full"])
	_register_tool("get_scene_info", "Return focused information about the currently edited scene.", _empty_schema(), "get_scene_info", ["core", "full"])
	_register_tool("get_scene_tree", "Return a structured summary of the currently edited scene tree.", {
		"type": "object",
		"properties": {"max_depth": {"type": "integer", "default": 4}},
	}, "get_scene_tree", ["core", "full"])
	_register_tool("get_selection", "Return the current editor node selection.", _empty_schema(), "get_selection", ["core", "full"])
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
			"extends": {"type": "string", "default": "Node"},
			"class_name": {"type": "string"},
			"body": {"type": "string"},
			"tool": {"type": "boolean", "default": false},
			"open_in_editor": {"type": "boolean", "default": true},
		},
		"required": ["path"],
	}, "create_script", ["core", "full"])
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
	_register_tool("validate_gdscript_file", "Compile-check a GDScript file using GDScript.reload().", {
		"type": "object",
		"properties": {"path": {"type": "string"}},
		"required": ["path"],
	}, "validate_gdscript_file", ["core", "full"])
	_register_tool("get_script_errors", "Compile-check GDScript files under a path and return files that fail to reload.", {
		"type": "object",
		"properties": {
			"path": {"type": "string", "default": "res://"},
			"max_files": {"type": "integer", "default": 200},
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
	_register_tool("list_project_features", "Return project settings such as main scene, input actions, and autoloads.", _empty_schema(), "list_project_features", ["core", "full"])
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
		},
		"required": ["node_path", "property", "value"],
	}, "set_node_property", ["full"])
	_register_tool("set_node_properties", "Set multiple properties on a node in the edited scene.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"properties": {"type": "object"},
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
		},
		"required": ["node_path"],
	}, "set_control_size_flags", ["full"])
	_register_tool("set_control_text", "Set text-like properties on a Control, such as text or placeholder_text.", {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"property": {"type": "string", "default": "text"},
			"text": {"type": "string"},
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


func _register_tool(name: String, description: String, input_schema: Dictionary, method_name: String, profiles: Array) -> void:
	_tools[name] = {
		"definition": {
			"name": name,
			"description": description,
			"inputSchema": input_schema,
		},
		"handler": Callable(_core_tools, method_name),
	}

	for profile_name in profiles:
		if not _profiles.has(profile_name):
			_profiles[profile_name] = []
		_profiles[profile_name].append(name)


func _empty_schema() -> Dictionary:
	return {
		"type": "object",
		"properties": {},
	}
