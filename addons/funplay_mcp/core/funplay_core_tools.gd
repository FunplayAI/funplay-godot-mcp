@tool
extends RefCounted

const SCENE_EXTENSIONS := [".tscn", ".scn"]
const TEXT_EXTENSIONS := [
	".gd", ".gdshader", ".tres", ".tscn", ".json", ".txt", ".md",
	".cfg", ".ini", ".toml", ".yaml", ".yml", ".shader", ".cs"
]
const KEY_NAME_MAP := {
	"enter": KEY_ENTER,
	"escape": KEY_ESCAPE,
	"esc": KEY_ESCAPE,
	"space": KEY_SPACE,
	"tab": KEY_TAB,
	"backspace": KEY_BACKSPACE,
	"up": KEY_UP,
	"down": KEY_DOWN,
	"left": KEY_LEFT,
	"right": KEY_RIGHT,
	"shift": KEY_SHIFT,
	"ctrl": KEY_CTRL,
	"control": KEY_CTRL,
	"alt": KEY_ALT,
}
const MOUSE_BUTTON_MAP := {
	"left": MOUSE_BUTTON_LEFT,
	"right": MOUSE_BUTTON_RIGHT,
	"middle": MOUSE_BUTTON_MIDDLE,
	"wheel_up": MOUSE_BUTTON_WHEEL_UP,
	"wheel_down": MOUSE_BUTTON_WHEEL_DOWN,
}
const SIZE_FLAG_MAP := {
	"fill": 1,
	"expand": 2,
	"expand_fill": 3,
	"shrink_center": 4,
	"shrink_end": 8,
}

var _plugin
var _settings


func _init(plugin, settings) -> void:
	_plugin = plugin
	_settings = settings


func execute_code(arguments: Dictionary) -> String:
	var code := str(arguments.get("code", "")).strip_edges()
	if code == "":
		return "Error: 'code' is required."

	var wrapped_lines := PackedStringArray([
		"@tool",
		"extends RefCounted",
		"func run(ctx):",
	])
	for line in code.split("\n"):
		if line == "":
			wrapped_lines.append("\t")
		else:
			wrapped_lines.append("\t%s" % line)

	var script := GDScript.new()
	script.source_code = "\n".join(wrapped_lines)
	var reload_err := script.reload()
	if reload_err != OK:
		return "Error: Failed to compile dynamic GDScript snippet (code %s)." % str(reload_err)
	if not script.can_instantiate():
		return "Error: Dynamic GDScript snippet could not be instantiated."

	var instance = script.new()
	if instance == null or not instance.has_method("run"):
		return "Error: Dynamic GDScript snippet must define run(ctx)."

	var editor := _editor()
	var context := {
		"plugin": _plugin,
		"editor_interface": editor,
		"scene_root": editor.get_edited_scene_root(),
		"selection": editor.get_selection().get_selected_nodes(),
		"project_root": ProjectSettings.globalize_path("res://"),
		"resource_filesystem": editor.get_resource_filesystem(),
		"open_scenes": editor.get_open_scenes(),
		"is_playing_scene": editor.is_playing_scene(),
		"time_scale": Engine.time_scale,
		"settings": {
			"tool_profile": _settings.tool_profile if _settings != null else "core",
			"server_port": _settings.server_port if _settings != null else 8765,
		},
	}

	var result = instance.call("run", context)
	return _render_variant(result)


func get_project_info(_arguments: Dictionary) -> String:
	var editor := _editor()
	var root = editor.get_edited_scene_root()
	var info := {
		"project_name": str(ProjectSettings.get_setting("application/config/name", "")),
		"godot_version": Engine.get_version_info(),
		"project_root": ProjectSettings.globalize_path("res://"),
		"current_scene_path": editor.get_current_path(),
		"current_scene_root": _node_to_summary(root),
		"open_scenes": editor.get_open_scenes(),
		"open_scene_count": editor.get_open_scenes().size(),
		"is_playing_scene": editor.is_playing_scene(),
		"time_scale": Engine.time_scale,
		"tool_profile": _settings.tool_profile if _settings != null else "core",
		"server_enabled": _settings.server_enabled if _settings != null else true,
		"server_port": _settings.server_port if _settings != null else 8765,
	}
	return _render_variant(info)


func get_scene_info(_arguments: Dictionary) -> String:
	var editor := _editor()
	var scene_root = editor.get_edited_scene_root()
	if scene_root == null:
		return "Error: No scene is currently open in the editor."

	var info := _build_scene_info(scene_root)
	info["open_scenes"] = editor.get_open_scenes()
	info["is_playing_scene"] = editor.is_playing_scene()
	info["time_scale"] = Engine.time_scale
	return _render_variant(info)


func get_scene_tree(arguments: Dictionary) -> String:
	var scene_root = _editor().get_edited_scene_root()
	if scene_root == null:
		return "Error: No scene is currently open in the editor."

	var max_depth := int(arguments.get("max_depth", 4))
	return _render_variant(_serialize_scene_tree(scene_root, max_depth))


func get_selection(_arguments: Dictionary) -> String:
	var nodes: Array = []
	for node in _editor().get_selection().get_selected_nodes():
		nodes.append(_node_to_summary(node))
	return _render_variant(nodes)


func list_scenes(arguments: Dictionary) -> String:
	var root_path := _normalize_path(str(arguments.get("path", "res://")))
	var max_entries := clamp(int(arguments.get("max_entries", 300)), 1, 3000)
	var recursive := bool(arguments.get("recursive", true))
	var scene_paths: Array = []
	_collect_matching_files(root_path, recursive, max_entries, scene_paths, SCENE_EXTENSIONS)

	return _render_variant({
		"path": root_path,
		"scene_count": scene_paths.size(),
		"scenes": scene_paths,
		"open_scenes": _editor().get_open_scenes(),
	})


func open_scene(arguments: Dictionary) -> String:
	var path := _normalize_path(str(arguments.get("path", "")))
	if path == "":
		return "Error: 'path' is required."
	if not FileAccess.file_exists(path):
		return "Error: Scene not found: %s" % path

	_editor().open_scene_from_path(path, bool(arguments.get("set_inherited", false)))
	return "Opened scene: %s" % path


func create_new_scene(arguments: Dictionary) -> String:
	var path := _normalize_path(str(arguments.get("path", "")))
	if path == "":
		return "Error: 'path' is required."

	var root_type := str(arguments.get("root_type", "Node2D")).strip_edges()
	if not ClassDB.class_exists(root_type):
		return "Error: Unknown Godot class '%s'." % root_type

	var instance = ClassDB.instantiate(root_type)
	if instance == null or not (instance is Node):
		return "Error: '%s' is not instantiable as a Node." % root_type

	var root: Node = instance
	root.name = str(arguments.get("root_name", root_type)).strip_edges()
	if root.name == "":
		root.name = root_type

	var script_path := _normalize_path(str(arguments.get("script_path", "")))
	if script_path != "":
		var script = load(script_path)
		if script == null or not (script is Script):
			root.free()
			return "Error: Script not found or invalid: %s" % script_path
		root.set_script(script)

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		root.free()
		return "Error: Failed to pack scene (code %s)." % str(pack_err)

	var ensure_err := _ensure_parent_dir(path)
	if ensure_err != OK:
		root.free()
		return "Error: Failed to create parent directory for %s" % path

	var save_err := ResourceSaver.save(packed, path, ResourceSaver.FLAG_CHANGE_PATH)
	root.free()
	if save_err != OK:
		return "Error: Failed to save scene to %s (code %s)." % [path, str(save_err)]

	_refresh_filesystem()
	if bool(arguments.get("open_after", true)):
		_editor().open_scene_from_path(path)

	return _render_variant({
		"created_scene": path,
		"root_type": root_type,
		"root_name": str(arguments.get("root_name", root_type)).strip_edges(),
	})


func save_scene(_arguments: Dictionary) -> String:
	var scene_root = _editor().get_edited_scene_root()
	if scene_root == null:
		return "Error: No edited scene is open."

	var save_result = _editor().save_scene()
	if typeof(save_result) == TYPE_BOOL:
		return "Scene saved successfully." if save_result else "Error: Failed to save scene."
	if int(save_result) == OK:
		return "Scene saved successfully."
	return "Error: save_scene returned error code %s" % str(save_result)


func save_scene_as(arguments: Dictionary) -> String:
	var path := _normalize_path(str(arguments.get("path", "")))
	if path == "":
		return "Error: 'path' is required."

	var scene_root = _editor().get_edited_scene_root()
	if scene_root == null:
		return "Error: No edited scene is open."

	var ensure_err := _ensure_parent_dir(path)
	if ensure_err != OK:
		return "Error: Failed to create parent directory for %s" % path

	_editor().save_scene_as(path, bool(arguments.get("with_preview", true)))
	return "Saved current scene as: %s" % path


func list_files(arguments: Dictionary) -> String:
	var root_path := _normalize_path(str(arguments.get("path", "res://")))
	var recursive := bool(arguments.get("recursive", true))
	var include_hidden := bool(arguments.get("include_hidden", false))
	var max_entries := clamp(int(arguments.get("max_entries", 200)), 1, 4000)
	var results: Array = []

	if DirAccess.open(root_path) == null:
		return "Error: Directory not found: %s" % root_path

	_collect_files(root_path, recursive, include_hidden, max_entries, results)
	return _render_variant({
		"path": root_path,
		"count": results.size(),
		"entries": results,
	})


func search_files(arguments: Dictionary) -> String:
	var root_path := _normalize_path(str(arguments.get("path", "res://")))
	var pattern := str(arguments.get("pattern", "")).strip_edges()
	if pattern == "":
		return "Error: 'pattern' is required."

	var mode := str(arguments.get("mode", "path")).to_lower()
	var recursive := bool(arguments.get("recursive", true))
	var max_results := clamp(int(arguments.get("max_results", 100)), 1, 2000)
	var matches: Array = []
	_search_files_recursive(root_path, pattern, mode, recursive, max_results, matches)

	return _render_variant({
		"path": root_path,
		"pattern": pattern,
		"mode": mode,
		"count": matches.size(),
		"matches": matches,
	})


func file_exists(arguments: Dictionary) -> String:
	var path := _normalize_path(str(arguments.get("path", "")))
	if path == "":
		return "Error: 'path' is required."

	var exists := FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path) or ResourceLoader.exists(path)
	return _render_variant({
		"path": path,
		"exists": exists,
	})


func read_file(arguments: Dictionary) -> String:
	var path := _normalize_path(str(arguments.get("path", "")))
	if path == "":
		return "Error: 'path' is required."
	if not FileAccess.file_exists(path):
		return "Error: File not found: %s" % path

	var max_chars := clamp(int(arguments.get("max_chars", 12000)), 200, 500000)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "Error: Failed to open file: %s" % path

	var text := file.get_as_text()
	if text.length() > max_chars:
		text = text.substr(0, max_chars) + "\n...[truncated]"

	return _render_variant({
		"path": path,
		"content": text,
	})


func write_file(arguments: Dictionary) -> String:
	var path := _normalize_path(str(arguments.get("path", "")))
	if path == "":
		return "Error: 'path' is required."

	var ensure_err := _ensure_parent_dir(path)
	if ensure_err != OK:
		return "Error: Failed to create parent directory for %s" % path

	var content := str(arguments.get("content", ""))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "Error: Failed to open file for writing: %s" % path

	file.store_string(content)
	_refresh_filesystem()
	return _render_variant({
		"path": path,
		"bytes_written": content.to_utf8_buffer().size(),
	})


func delete_file(arguments: Dictionary) -> String:
	var path := _normalize_path(str(arguments.get("path", "")))
	if path == "":
		return "Error: 'path' is required."

	var err := DirAccess.remove_absolute(path)
	if err != OK:
		return "Error: Failed to delete '%s' (code %s)." % [path, str(err)]

	_refresh_filesystem()
	return "Deleted: %s" % path


func move_file(arguments: Dictionary) -> String:
	var from_path := _normalize_path(str(arguments.get("from_path", "")))
	var to_path := _normalize_path(str(arguments.get("to_path", "")))
	if from_path == "" or to_path == "":
		return "Error: 'from_path' and 'to_path' are required."

	var ensure_err := _ensure_parent_dir(to_path)
	if ensure_err != OK:
		return "Error: Failed to create parent directory for %s" % to_path

	var err := DirAccess.rename_absolute(from_path, to_path)
	if err != OK:
		return "Error: Failed to move '%s' to '%s' (code %s)." % [from_path, to_path, str(err)]

	_refresh_filesystem()
	return "Moved '%s' to '%s'." % [from_path, to_path]


func copy_file(arguments: Dictionary) -> String:
	var from_path := _normalize_path(str(arguments.get("from_path", "")))
	var to_path := _normalize_path(str(arguments.get("to_path", "")))
	if from_path == "" or to_path == "":
		return "Error: 'from_path' and 'to_path' are required."

	var ensure_err := _ensure_parent_dir(to_path)
	if ensure_err != OK:
		return "Error: Failed to create parent directory for %s" % to_path

	var err := DirAccess.copy_absolute(from_path, to_path)
	if err != OK:
		return "Error: Failed to copy '%s' to '%s' (code %s)." % [from_path, to_path, str(err)]

	_refresh_filesystem()
	return "Copied '%s' to '%s'." % [from_path, to_path]


func create_script(arguments: Dictionary) -> String:
	var path := _normalize_path(str(arguments.get("path", "")))
	if path == "":
		return "Error: 'path' is required."

	var extends_name := str(arguments.get("extends", "Node")).strip_edges()
	var class_name := str(arguments.get("class_name", "")).strip_edges()
	var body := str(arguments.get("body", "")).strip_edges()
	var use_tool := bool(arguments.get("tool", false))

	var lines: Array[String] = []
	if use_tool:
		lines.append("@tool")
	lines.append("extends %s" % extends_name)
	if class_name != "":
		lines.append("class_name %s" % class_name)
	lines.append("")
	if body != "":
		lines.append(body)
	else:
		lines.append("func _ready() -> void:")
		lines.append("\tpass")

	var result := write_file({
		"path": path,
		"content": "\n".join(lines) + "\n",
	})

	if bool(arguments.get("open_in_editor", true)):
		open_script({
			"path": path,
			"line": int(arguments.get("line", 1)),
			"column": 0,
		})

	return result


func edit_script(arguments: Dictionary) -> String:
	return write_file(arguments)


func patch_script(arguments: Dictionary) -> String:
	var path := _normalize_path(str(arguments.get("path", "")))
	if path == "":
		return "Error: 'path' is required."
	if not FileAccess.file_exists(path):
		return "Error: File not found: %s" % path

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "Error: Failed to open file: %s" % path

	var content := file.get_as_text()
	var find_text := str(arguments.get("find", ""))
	var replace_text := str(arguments.get("replace", ""))
	var prepend_text := str(arguments.get("prepend", ""))
	var append_text := str(arguments.get("append", ""))

	if find_text != "":
		content = content.replace(find_text, replace_text)
	if prepend_text != "":
		content = prepend_text + content
	if append_text != "":
		content += append_text

	return write_file({
		"path": path,
		"content": content,
	})


func open_script(arguments: Dictionary) -> String:
	var path := _normalize_path(str(arguments.get("path", "")))
	if path == "":
		return "Error: 'path' is required."

	var script = load(path)
	if script == null or not (script is Script):
		return "Error: Script not found or invalid: %s" % path

	_editor().edit_script(script, int(arguments.get("line", -1)), int(arguments.get("column", 0)), true)
	return "Opened script: %s" % path


func get_play_state(_arguments: Dictionary) -> String:
	var editor := _editor()
	return _render_variant({
		"is_playing_scene": editor.is_playing_scene(),
		"current_scene_path": editor.get_current_path(),
		"open_scenes": editor.get_open_scenes(),
		"time_scale": Engine.time_scale,
	})


func enter_play_mode(arguments: Dictionary) -> String:
	var mode := str(arguments.get("mode", "current")).to_lower()
	var editor := _editor()

	match mode:
		"current":
			editor.play_current_scene()
		"main":
			editor.play_main_scene()
		"custom":
			var scene_path := _normalize_path(str(arguments.get("scene_path", "")))
			if scene_path == "":
				return "Error: 'scene_path' is required when mode is 'custom'."
			editor.play_custom_scene(scene_path)
		_:
			return "Error: Unsupported play mode '%s'." % mode

	return "Entered play mode using '%s' scene selection." % mode


func play_main_scene(_arguments: Dictionary) -> String:
	_editor().play_main_scene()
	return "Started the main scene."


func exit_play_mode(_arguments: Dictionary) -> String:
	_editor().stop_playing_scene()
	return "Stopped the running scene."


func simulate_action(arguments: Dictionary) -> String:
	var action_name := str(arguments.get("action", "")).strip_edges()
	if action_name == "":
		return "Error: 'action' is required."

	var mode := str(arguments.get("mode", "tap")).to_lower()
	var strength := float(arguments.get("strength", 1.0))
	if mode == "press" or mode == "tap":
		var press_event := InputEventAction.new()
		press_event.action = action_name
		press_event.pressed = true
		press_event.strength = strength
		Input.parse_input_event(press_event)
	if mode == "release" or mode == "tap":
		var release_event := InputEventAction.new()
		release_event.action = action_name
		release_event.pressed = false
		release_event.strength = 0.0
		Input.parse_input_event(release_event)

	return _render_variant({
		"action": action_name,
		"mode": mode,
		"strength": strength,
	})


func simulate_key_event(arguments: Dictionary) -> String:
	var mode := str(arguments.get("mode", "tap")).to_lower()
	var keycode := _to_keycode(arguments.get("key"))
	var physical_keycode := _to_keycode(arguments.get("physical_key"))
	if keycode == 0 and physical_keycode == 0:
		return "Error: 'key' or 'physical_key' is required."

	if mode == "press" or mode == "tap":
		var press_event := InputEventKey.new()
		press_event.pressed = true
		if keycode != 0:
			press_event.keycode = keycode
		if physical_keycode != 0:
			press_event.physical_keycode = physical_keycode
		Input.parse_input_event(press_event)
	if mode == "release" or mode == "tap":
		var release_event := InputEventKey.new()
		release_event.pressed = false
		if keycode != 0:
			release_event.keycode = keycode
		if physical_keycode != 0:
			release_event.physical_keycode = physical_keycode
		Input.parse_input_event(release_event)

	return _render_variant({
		"mode": mode,
		"keycode": keycode,
		"physical_keycode": physical_keycode,
	})


func simulate_mouse_button(arguments: Dictionary) -> String:
	var mode := str(arguments.get("mode", "tap")).to_lower()
	var button_index := _to_mouse_button(arguments.get("button", "left"))
	var position := _to_vector2(arguments.get("position", Vector2.ZERO))

	if mode == "press" or mode == "tap":
		var press_event := InputEventMouseButton.new()
		press_event.button_index = button_index
		press_event.position = position
		press_event.pressed = true
		Input.parse_input_event(press_event)
	if mode == "release" or mode == "tap":
		var release_event := InputEventMouseButton.new()
		release_event.button_index = button_index
		release_event.position = position
		release_event.pressed = false
		Input.parse_input_event(release_event)

	return _render_variant({
		"mode": mode,
		"button_index": button_index,
		"position": _json_safe(position),
	})


func simulate_mouse_drag(arguments: Dictionary) -> String:
	var from_position := _to_vector2(arguments.get("from_position", Vector2.ZERO))
	var to_position := _to_vector2(arguments.get("to_position", Vector2.ZERO))
	var steps := clamp(int(arguments.get("steps", 8)), 1, 240)
	var button_index := _to_mouse_button(arguments.get("button", "left"))

	var press_event := InputEventMouseButton.new()
	press_event.button_index = button_index
	press_event.position = from_position
	press_event.global_position = from_position
	press_event.pressed = true
	Input.parse_input_event(press_event)

	var previous := from_position
	for step_index in range(1, steps + 1):
		var weight := float(step_index) / float(steps)
		var current := from_position.lerp(to_position, weight)
		var motion_event := InputEventMouseMotion.new()
		motion_event.position = current
		motion_event.global_position = current
		motion_event.relative = current - previous
		motion_event.screen_relative = current - previous
		motion_event.button_mask = 1 << (button_index - 1)
		Input.parse_input_event(motion_event)
		previous = current

	var release_event := InputEventMouseButton.new()
	release_event.button_index = button_index
	release_event.position = to_position
	release_event.global_position = to_position
	release_event.pressed = false
	Input.parse_input_event(release_event)

	return _render_variant({
		"from_position": _json_safe(from_position),
		"to_position": _json_safe(to_position),
		"steps": steps,
		"button_index": button_index,
	})


func simulate_input_sequence(arguments: Dictionary) -> String:
	var events = arguments.get("events", [])
	if not (events is Array):
		return "Error: 'events' must be an array."

	var results: Array = []
	for item in events:
		if not (item is Dictionary):
			results.append("Error: Sequence item must be an object.")
			continue

		var event_type := str(item.get("type", "")).strip_edges()
		var result_text := ""
		match event_type:
			"action":
				result_text = simulate_action(item)
			"key":
				result_text = simulate_key_event(item)
			"mouse_button":
				result_text = simulate_mouse_button(item)
			"mouse_drag":
				result_text = simulate_mouse_drag(item)
			_:
				result_text = "Error: Unsupported sequence event type '%s'." % event_type
		results.append({
			"type": event_type,
			"result": result_text,
		})

	return _render_variant({
		"count": events.size(),
		"results": results,
	})


func get_time_scale(_arguments: Dictionary) -> String:
	return _render_variant({
		"time_scale": Engine.time_scale,
	})


func get_console_logs(arguments: Dictionary) -> String:
	var max_lines := clamp(int(arguments.get("max_lines", 200)), 10, 4000)
	var include_rotated := bool(arguments.get("include_rotated", true))
	var filter_text := str(arguments.get("filter", "")).strip_edges()
	var severity := str(arguments.get("severity", "all")).to_lower()
	var log_files := _get_log_files(include_rotated)
	if log_files.is_empty():
		return "Error: No log files found. File logging may be disabled."

	var selected_file := log_files[-1]
	var file_text := FileAccess.get_file_as_string(selected_file)
	var lines := file_text.split("\n")
	var filtered_lines: Array[String] = []
	for line in lines:
		if not _matches_log_filters(line, severity, filter_text):
			continue
		filtered_lines.append(line)

	var start_index := max(filtered_lines.size() - max_lines, 0)
	var tail := filtered_lines.slice(start_index)
	return _render_variant({
		"log_path": selected_file,
		"available_logs": log_files,
		"line_count": tail.size(),
		"lines": tail,
	})


func set_time_scale(arguments: Dictionary) -> String:
	if not arguments.has("value"):
		return "Error: 'value' is required."
	Engine.time_scale = float(arguments.get("value"))
	return _render_variant({
		"time_scale": Engine.time_scale,
	})


func get_performance_snapshot(_arguments: Dictionary) -> String:
	var editor := _editor()
	var scene_root = editor.get_edited_scene_root()
	var viewport_2d = editor.get_editor_viewport_2d()
	var viewport_3d = editor.get_editor_viewport_3d(0)

	return _render_variant({
		"is_playing_scene": editor.is_playing_scene(),
		"frames_per_second": Engine.get_frames_per_second(),
		"time_scale": Engine.time_scale,
		"open_scene_count": editor.get_open_scenes().size(),
		"edited_scene": _node_to_summary(scene_root),
		"scene_node_count": _count_nodes(scene_root),
		"viewport_2d_size": viewport_2d.get_visible_rect().size if viewport_2d != null else null,
		"viewport_3d_size": viewport_3d.get_visible_rect().size if viewport_3d != null else null,
	})


func analyze_scene_complexity(_arguments: Dictionary) -> String:
	var scene_root = _editor().get_edited_scene_root()
	if scene_root == null:
		return "Error: No scene is currently open in the editor."

	var stats := {
		"total_nodes": 0,
		"max_depth": 0,
		"node_2d_count": 0,
		"node_3d_count": 0,
		"control_count": 0,
		"scripted_nodes": 0,
		"light_count": 0,
		"camera_count": 0,
		"collision_count": 0,
		"audio_count": 0,
		"particles_count": 0,
		"unique_classes": {},
	}
	_analyze_node_recursive(scene_root, 0, stats)

	var unique_class_count := stats["unique_classes"].size()
	stats.erase("unique_classes")
	stats["unique_class_count"] = unique_class_count
	stats["complexity_score"] = int(
		stats["total_nodes"]
		+ stats["scripted_nodes"] * 2
		+ stats["light_count"] * 4
		+ stats["camera_count"] * 2
		+ stats["particles_count"] * 5
	)

	return _render_variant(stats)


func capture_editor_view(arguments: Dictionary) -> String:
	var view := str(arguments.get("view", "2d")).to_lower()
	var viewport = null
	if view == "3d":
		viewport = _editor().get_editor_viewport_3d(int(arguments.get("index", 0)))
	else:
		viewport = _editor().get_editor_viewport_2d()

	if viewport == null:
		return "Error: Editor viewport '%s' is not available." % view

	var texture = viewport.get_texture()
	if texture == null:
		return "Error: The selected viewport has no texture to capture."

	var image = texture.get_image()
	if image == null:
		return "Error: Failed to capture viewport image."

	var save_path := _normalize_path(str(arguments.get("save_path", "user://funplay_mcp_capture_%s.png" % view)))
	if bool(arguments.get("save_to_file", false)):
		var ensure_err := _ensure_parent_dir(save_path)
		if ensure_err != OK:
			return "Error: Failed to create parent directory for %s" % save_path
		var save_err := image.save_png(save_path)
		if save_err != OK:
			return "Error: Failed to save screenshot to %s (code %s)." % [save_path, str(save_err)]

	if bool(arguments.get("return_data_uri", true)):
		var png_bytes := image.save_png_to_buffer()
		return "data:image/png;base64,%s" % Marshalls.raw_to_base64(png_bytes)

	return _render_variant({
		"captured_view": view,
		"saved_path": save_path if bool(arguments.get("save_to_file", false)) else "",
		"size": image.get_size(),
	})


func get_node_info(arguments: Dictionary) -> String:
	var node_path := str(arguments.get("node_path", "")).strip_edges()
	if node_path == "":
		return "Error: 'node_path' is required."

	var node = _resolve_node_path(node_path)
	if node == null:
		return "Error: Node not found: %s" % node_path

	return _render_variant(_build_node_info(node))


func find_nodes(arguments: Dictionary) -> String:
	var scene_root = _editor().get_edited_scene_root()
	if scene_root == null:
		return "Error: No scene is currently open in the editor."

	var name_contains := str(arguments.get("name_contains", "")).to_lower()
	var class_name := str(arguments.get("class_name", "")).strip_edges()
	var script_path := _normalize_path(str(arguments.get("script_path", "")))
	var max_results := clamp(int(arguments.get("max_results", 100)), 1, 2000)
	var results: Array = []

	_find_nodes_recursive(scene_root, name_contains, class_name, script_path, max_results, results)
	return _render_variant({
		"count": results.size(),
		"results": results,
	})


func select_node(arguments: Dictionary) -> String:
	var node_path := str(arguments.get("node_path", "")).strip_edges()
	if node_path == "":
		return "Error: 'node_path' is required."

	var node = _resolve_node_path(node_path)
	if node == null:
		return "Error: Node not found: %s" % node_path

	var selection = _editor().get_selection()
	selection.clear()
	selection.add_node(node)
	if bool(arguments.get("focus", true)):
		_editor().edit_node(node)

	return "Selected node: %s" % node_path


func select_file(arguments: Dictionary) -> String:
	var path := _normalize_path(str(arguments.get("path", "")))
	if path == "":
		return "Error: 'path' is required."

	_editor().select_file(path)
	return "Selected file in FileSystem dock: %s" % path


func create_node(arguments: Dictionary) -> String:
	var node_type := str(arguments.get("node_type", "")).strip_edges()
	if node_type == "":
		return "Error: 'node_type' is required."

	var scene_root = _editor().get_edited_scene_root()
	if scene_root == null:
		return "Error: No edited scene is open."

	var parent = _resolve_node_path(str(arguments.get("parent_path", "")))
	if parent == null:
		parent = scene_root
	if not (parent is Node):
		return "Error: Parent path does not resolve to a node."
	if not ClassDB.class_exists(node_type):
		return "Error: Unknown Godot class '%s'." % node_type

	var instance = ClassDB.instantiate(node_type)
	if instance == null or not (instance is Node):
		return "Error: '%s' is not instantiable as a Node." % node_type

	var node: Node = instance
	node.name = _safe_name(str(arguments.get("name", node_type)), node_type)
	parent.add_child(node)
	_assign_owner_recursive(node, scene_root)

	if arguments.has("script_path"):
		var set_script_result := set_node_script({
			"node_path": str(node.get_path()),
			"script_path": arguments.get("script_path"),
		})
		if set_script_result.begins_with("Error:"):
			return set_script_result

	if bool(arguments.get("select_new_node", true)):
		select_node({
			"node_path": str(node.get_path()),
			"focus": true,
		})

	return _render_variant({
		"created": _node_to_summary(node),
		"parent_path": str(parent.get_path()),
		"note": "Scene modified. Call save_scene to persist it.",
	})


func instantiate_scene(arguments: Dictionary) -> String:
	var scene_path := _normalize_path(str(arguments.get("scene_path", "")))
	if scene_path == "":
		return "Error: 'scene_path' is required."

	var packed = load(scene_path)
	if packed == null or not (packed is PackedScene):
		return "Error: Scene not found or invalid: %s" % scene_path

	var scene_root = _editor().get_edited_scene_root()
	if scene_root == null:
		return "Error: No edited scene is open."

	var parent = _resolve_node_path(str(arguments.get("parent_path", "")))
	if parent == null:
		parent = scene_root

	var instance = packed.instantiate()
	if instance == null:
		return "Error: Failed to instantiate scene: %s" % scene_path

	if str(arguments.get("name", "")).strip_edges() != "":
		instance.name = str(arguments.get("name")).strip_edges()

	parent.add_child(instance)
	_assign_owner_recursive(instance, scene_root)

	if bool(arguments.get("select_new_node", true)):
		select_node({
			"node_path": str(instance.get_path()),
			"focus": true,
		})

	return _render_variant({
		"instantiated_scene": scene_path,
		"instance": _node_to_summary(instance),
	})


func duplicate_node(arguments: Dictionary) -> String:
	var node_path := str(arguments.get("node_path", "")).strip_edges()
	if node_path == "":
		return "Error: 'node_path' is required."

	var node = _resolve_node_path(node_path)
	if node == null:
		return "Error: Node not found: %s" % node_path

	var duplicate = node.duplicate()
	if duplicate == null or not (duplicate is Node):
		return "Error: Failed to duplicate node '%s'." % node_path

	var parent = node.get_parent()
	if parent == null:
		return "Error: Node '%s' has no parent." % node_path

	parent.add_child(duplicate)
	if str(arguments.get("new_name", "")).strip_edges() != "":
		duplicate.name = str(arguments.get("new_name")).strip_edges()
	_assign_owner_recursive(duplicate, _editor().get_edited_scene_root())

	if bool(arguments.get("select_new_node", true)):
		select_node({
			"node_path": str(duplicate.get_path()),
			"focus": true,
		})

	return _render_variant({
		"source": _node_to_summary(node),
		"duplicate": _node_to_summary(duplicate),
	})


func rename_node(arguments: Dictionary) -> String:
	var node_path := str(arguments.get("node_path", "")).strip_edges()
	var new_name := str(arguments.get("new_name", "")).strip_edges()
	if node_path == "" or new_name == "":
		return "Error: 'node_path' and 'new_name' are required."

	var node = _resolve_node_path(node_path)
	if node == null:
		return "Error: Node not found: %s" % node_path

	node.name = new_name
	return _render_variant({
		"node": _node_to_summary(node),
	})


func reparent_node(arguments: Dictionary) -> String:
	var node_path := str(arguments.get("node_path", "")).strip_edges()
	var new_parent_path := str(arguments.get("new_parent_path", "")).strip_edges()
	if node_path == "" or new_parent_path == "":
		return "Error: 'node_path' and 'new_parent_path' are required."

	var node = _resolve_node_path(node_path)
	var new_parent = _resolve_node_path(new_parent_path)
	if node == null:
		return "Error: Node not found: %s" % node_path
	if new_parent == null:
		return "Error: New parent not found: %s" % new_parent_path
	if node == _editor().get_edited_scene_root():
		return "Error: Reparenting the edited scene root is not supported."

	var keep_global := bool(arguments.get("keep_global_transform", false))
	var stored_transform = null
	if keep_global:
		stored_transform = _capture_global_transform(node)

	var old_parent = node.get_parent()
	if old_parent != null:
		old_parent.remove_child(node)
	new_parent.add_child(node)
	_assign_owner_recursive(node, _editor().get_edited_scene_root())

	if keep_global:
		_restore_global_transform(node, stored_transform)

	return _render_variant({
		"node": _node_to_summary(node),
		"new_parent_path": str(new_parent.get_path()),
	})


func set_node_property(arguments: Dictionary) -> String:
	var node_path := str(arguments.get("node_path", "")).strip_edges()
	var property_name := str(arguments.get("property", "")).strip_edges()
	if node_path == "" or property_name == "":
		return "Error: 'node_path' and 'property' are required."

	var node = _resolve_node_path(node_path)
	if node == null:
		return "Error: Node not found: %s" % node_path

	node.set(property_name, arguments.get("value"))
	return _render_variant({
		"node": _node_to_summary(node),
		"property": property_name,
		"value": _json_safe(arguments.get("value")),
	})


func set_node_properties(arguments: Dictionary) -> String:
	var node_path := str(arguments.get("node_path", "")).strip_edges()
	var properties = arguments.get("properties", {})
	if node_path == "":
		return "Error: 'node_path' is required."
	if not (properties is Dictionary):
		return "Error: 'properties' must be an object."

	var node = _resolve_node_path(node_path)
	if node == null:
		return "Error: Node not found: %s" % node_path

	for key in properties.keys():
		node.set(str(key), properties[key])

	return _render_variant({
		"node": _node_to_summary(node),
		"properties": _json_safe(properties),
	})


func set_transform_2d(arguments: Dictionary) -> String:
	var node_path := str(arguments.get("node_path", "")).strip_edges()
	if node_path == "":
		return "Error: 'node_path' is required."

	var node = _resolve_node_path(node_path)
	if node == null:
		return "Error: Node not found: %s" % node_path

	if node is Node2D:
		if arguments.has("position"):
			node.position = _to_vector2(arguments.get("position"))
		if arguments.has("rotation_degrees"):
			node.rotation_degrees = float(arguments.get("rotation_degrees"))
		if arguments.has("scale"):
			node.scale = _to_vector2(arguments.get("scale"))
	elif node is Control:
		if arguments.has("position"):
			node.position = _to_vector2(arguments.get("position"))
		if arguments.has("rotation_degrees"):
			node.rotation_degrees = float(arguments.get("rotation_degrees"))
		if arguments.has("scale"):
			node.scale = _to_vector2(arguments.get("scale"))
		if arguments.has("size"):
			node.size = _to_vector2(arguments.get("size"))
	else:
		return "Error: Node '%s' is not a Node2D or Control." % node_path

	return _render_variant({
		"node": _build_node_info(node),
	})


func set_transform_3d(arguments: Dictionary) -> String:
	var node_path := str(arguments.get("node_path", "")).strip_edges()
	if node_path == "":
		return "Error: 'node_path' is required."

	var node = _resolve_node_path(node_path)
	if node == null:
		return "Error: Node not found: %s" % node_path
	if not (node is Node3D):
		return "Error: Node '%s' is not a Node3D." % node_path

	if arguments.has("position"):
		node.position = _to_vector3(arguments.get("position"))
	if arguments.has("rotation_degrees"):
		node.rotation_degrees = _to_vector3(arguments.get("rotation_degrees"))
	if arguments.has("scale"):
		node.scale = _to_vector3(arguments.get("scale"))

	return _render_variant({
		"node": _build_node_info(node),
	})


func remove_node(arguments: Dictionary) -> String:
	var node_path := str(arguments.get("node_path", "")).strip_edges()
	if node_path == "":
		return "Error: 'node_path' is required."

	var node = _resolve_node_path(node_path)
	if node == null:
		return "Error: Node not found: %s" % node_path
	if node == _editor().get_edited_scene_root():
		return "Error: Removing the edited scene root is not supported."

	var parent = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.free()

	return "Removed node: %s" % node_path


func set_node_script(arguments: Dictionary) -> String:
	var node_path := str(arguments.get("node_path", "")).strip_edges()
	var script_path := _normalize_path(str(arguments.get("script_path", "")))
	if node_path == "" or script_path == "":
		return "Error: 'node_path' and 'script_path' are required."

	var node = _resolve_node_path(node_path)
	if node == null:
		return "Error: Node not found: %s" % node_path

	var script = load(script_path)
	if script == null or not (script is Script):
		return "Error: Script not found or invalid: %s" % script_path

	node.set_script(script)
	return _render_variant({
		"node": _node_to_summary(node),
		"script_path": script_path,
	})


func create_material(arguments: Dictionary) -> String:
	var path := _normalize_path(str(arguments.get("path", "")))
	if path == "":
		return "Error: 'path' is required."

	var material_type := str(arguments.get("material_type", "StandardMaterial3D")).strip_edges()
	if not ClassDB.class_exists(material_type):
		return "Error: Unknown material type '%s'." % material_type

	var material = ClassDB.instantiate(material_type)
	if material == null or not (material is Resource):
		return "Error: '%s' is not instantiable as a Resource." % material_type

	var properties = arguments.get("properties", {})
	if properties is Dictionary:
		for key in properties.keys():
			material.set(str(key), properties[key])

	var ensure_err := _ensure_parent_dir(path)
	if ensure_err != OK:
		return "Error: Failed to create parent directory for %s" % path

	var save_err := ResourceSaver.save(material, path, ResourceSaver.FLAG_CHANGE_PATH)
	if save_err != OK:
		return "Error: Failed to save material to %s (code %s)." % [path, str(save_err)]

	_refresh_filesystem()
	return _render_variant({
		"material_type": material_type,
		"path": path,
	})


func assign_material(arguments: Dictionary) -> String:
	var target_path := str(arguments.get("target_path", "")).strip_edges()
	var material_path := _normalize_path(str(arguments.get("material_path", "")))
	if target_path == "" or material_path == "":
		return "Error: 'target_path' and 'material_path' are required."

	var node = _resolve_node_path(target_path)
	if node == null:
		return "Error: Node not found: %s" % target_path

	var material = load(material_path)
	if material == null or not (material is Material):
		return "Error: Material not found or invalid: %s" % material_path

	var surface_index := int(arguments.get("surface_index", -1))
	if node is CanvasItem:
		node.material = material
	elif node is GeometryInstance3D:
		if surface_index >= 0 and node.has_method("set_surface_override_material"):
			node.set_surface_override_material(surface_index, material)
		else:
			node.material_override = material
	elif _has_property(node, "material"):
		node.set("material", material)
	else:
		return "Error: Node '%s' does not expose a supported material slot." % target_path

	return _render_variant({
		"target": _node_to_summary(node),
		"material_path": material_path,
		"surface_index": surface_index,
	})


func create_ui_root(arguments: Dictionary) -> String:
	var scene_root = _editor().get_edited_scene_root()
	if scene_root == null:
		return "Error: No edited scene is open."

	var kind := str(arguments.get("kind", "canvas_layer")).to_lower()
	var parent = _resolve_node_path(str(arguments.get("parent_path", "")))
	if parent == null:
		parent = scene_root

	var created_root: Node = null
	var primary_control: Control = null

	match kind:
		"canvas_layer":
			var canvas_layer := CanvasLayer.new()
			canvas_layer.name = _safe_name(str(arguments.get("name", "UI")), "UI")
			parent.add_child(canvas_layer)
			_assign_owner_recursive(canvas_layer, scene_root)
			created_root = canvas_layer

			var control_root := Control.new()
			control_root.name = _safe_name(str(arguments.get("control_name", "Root")), "Root")
			canvas_layer.add_child(control_root)
			_assign_owner_recursive(control_root, scene_root)
			_apply_layout_preset(control_root, "full_rect")
			primary_control = control_root
		"control":
			var control := Control.new()
			control.name = _safe_name(str(arguments.get("name", "UIRoot")), "UIRoot")
			parent.add_child(control)
			_assign_owner_recursive(control, scene_root)
			_apply_layout_preset(control, str(arguments.get("layout_preset", "full_rect")))
			created_root = control
			primary_control = control
		_:
			return "Error: Unsupported ui root kind '%s'." % kind

	if bool(arguments.get("select_new_node", true)):
		select_node({"node_path": str(created_root.get_path()), "focus": true})

	return _render_variant({
		"created_root": _node_to_summary(created_root),
		"primary_control": _node_to_summary(primary_control),
	})


func create_control(arguments: Dictionary) -> String:
	var control_type := str(arguments.get("control_type", "")).strip_edges()
	if control_type == "":
		return "Error: 'control_type' is required."
	return _create_control_internal(control_type, arguments)


func create_label(arguments: Dictionary) -> String:
	var merged := arguments.duplicate(true)
	merged["control_type"] = "Label"
	return _create_control_internal("Label", merged)


func create_button(arguments: Dictionary) -> String:
	var merged := arguments.duplicate(true)
	merged["control_type"] = "Button"
	return _create_control_internal("Button", merged)


func create_panel(arguments: Dictionary) -> String:
	var merged := arguments.duplicate(true)
	merged["control_type"] = "Panel"
	return _create_control_internal("Panel", merged)


func create_texture_rect(arguments: Dictionary) -> String:
	var merged := arguments.duplicate(true)
	merged["control_type"] = "TextureRect"
	return _create_control_internal("TextureRect", merged)


func create_container(arguments: Dictionary) -> String:
	var container_type := str(arguments.get("container_type", "")).strip_edges()
	if container_type == "":
		return "Error: 'container_type' is required."
	return _create_control_internal(container_type, arguments)


func set_control_layout(arguments: Dictionary) -> String:
	var control = _resolve_control(str(arguments.get("node_path", "")))
	if control == null:
		return "Error: Control not found."

	if arguments.has("layout_preset"):
		_apply_layout_preset(control, str(arguments.get("layout_preset")))
	if arguments.has("anchors"):
		var anchors = arguments.get("anchors")
		if anchors is Dictionary:
			control.anchor_left = float(anchors.get("left", control.anchor_left))
			control.anchor_top = float(anchors.get("top", control.anchor_top))
			control.anchor_right = float(anchors.get("right", control.anchor_right))
			control.anchor_bottom = float(anchors.get("bottom", control.anchor_bottom))
	if arguments.has("offsets"):
		var offsets = arguments.get("offsets")
		if offsets is Dictionary:
			control.offset_left = float(offsets.get("left", control.offset_left))
			control.offset_top = float(offsets.get("top", control.offset_top))
			control.offset_right = float(offsets.get("right", control.offset_right))
			control.offset_bottom = float(offsets.get("bottom", control.offset_bottom))
	if arguments.has("size"):
		control.size = _to_vector2(arguments.get("size"))
	if arguments.has("position"):
		control.position = _to_vector2(arguments.get("position"))
	if arguments.has("grow_horizontal"):
		control.grow_horizontal = int(arguments.get("grow_horizontal"))
	if arguments.has("grow_vertical"):
		control.grow_vertical = int(arguments.get("grow_vertical"))

	return _render_variant({
		"control": _build_control_info(control),
	})


func set_control_size_flags(arguments: Dictionary) -> String:
	var control = _resolve_control(str(arguments.get("node_path", "")))
	if control == null:
		return "Error: Control not found."

	if arguments.has("horizontal"):
		control.size_flags_horizontal = _parse_size_flags(arguments.get("horizontal"))
	if arguments.has("vertical"):
		control.size_flags_vertical = _parse_size_flags(arguments.get("vertical"))
	if arguments.has("stretch_ratio"):
		control.size_flags_stretch_ratio = float(arguments.get("stretch_ratio"))

	return _render_variant({
		"control": _build_control_info(control),
	})


func set_control_text(arguments: Dictionary) -> String:
	var control = _resolve_control(str(arguments.get("node_path", "")))
	if control == null:
		return "Error: Control not found."

	var text := str(arguments.get("text", ""))
	var property_name := str(arguments.get("property", "text")).strip_edges()
	if property_name == "":
		property_name = "text"

	if not _has_property(control, property_name):
		return "Error: Control '%s' does not expose property '%s'." % [control.name, property_name]

	control.set(property_name, text)
	return _render_variant({
		"control": _build_control_info(control),
		"property": property_name,
		"text": text,
	})


func set_control_theme_override(arguments: Dictionary) -> String:
	var control = _resolve_control(str(arguments.get("node_path", "")))
	if control == null:
		return "Error: Control not found."

	var override_type := str(arguments.get("override_type", "")).to_lower()
	var name := str(arguments.get("name", "")).strip_edges()
	if override_type == "" or name == "":
		return "Error: 'override_type' and 'name' are required."

	match override_type:
		"color":
			control.add_theme_color_override(name, _to_color(arguments.get("value")))
		"constant":
			control.add_theme_constant_override(name, int(arguments.get("value", 0)))
		"font_size":
			control.add_theme_font_size_override(name, int(arguments.get("value", 0)))
		"font":
			var font_path := _normalize_path(str(arguments.get("resource_path", "")))
			var font = load(font_path)
			if font == null:
				return "Error: Font resource not found: %s" % font_path
			control.add_theme_font_override(name, font)
		"stylebox":
			var style_path := _normalize_path(str(arguments.get("resource_path", "")))
			var stylebox = load(style_path)
			if stylebox == null:
				return "Error: StyleBox resource not found: %s" % style_path
			control.add_theme_stylebox_override(name, stylebox)
		_:
			return "Error: Unsupported override_type '%s'." % override_type

	return _render_variant({
		"control": _build_control_info(control),
		"override_type": override_type,
		"name": name,
	})


func set_control_texture(arguments: Dictionary) -> String:
	var control = _resolve_control(str(arguments.get("node_path", "")))
	if control == null:
		return "Error: Control not found."

	var texture_path := _normalize_path(str(arguments.get("texture_path", "")))
	if texture_path == "":
		return "Error: 'texture_path' is required."
	var texture = load(texture_path)
	if texture == null:
		return "Error: Texture not found: %s" % texture_path

	if _has_property(control, "texture"):
		control.set("texture", texture)
	else:
		return "Error: Control '%s' does not expose a 'texture' property." % control.name

	if control is TextureRect:
		if arguments.has("stretch_mode"):
			control.stretch_mode = int(arguments.get("stretch_mode"))
		if arguments.has("expand_mode"):
			control.expand_mode = int(arguments.get("expand_mode"))

	return _render_variant({
		"control": _build_control_info(control),
		"texture_path": texture_path,
	})


func connect_node_signal(arguments: Dictionary) -> String:
	var source_node = _resolve_node_path(str(arguments.get("source_path", "")).strip_edges())
	var target_node = _resolve_node_path(str(arguments.get("target_path", "")).strip_edges())
	var signal_name := str(arguments.get("signal_name", "")).strip_edges()
	var method_name := str(arguments.get("method_name", "")).strip_edges()

	if source_node == null or target_node == null:
		return "Error: Source or target node not found."
	if signal_name == "" or method_name == "":
		return "Error: 'signal_name' and 'method_name' are required."
	if not source_node.has_signal(signal_name):
		return "Error: Source node does not have signal '%s'." % signal_name
	if not target_node.has_method(method_name):
		return "Error: Target node does not have method '%s'." % method_name

	var callable := Callable(target_node, method_name)
	if source_node.is_connected(signal_name, callable):
		return "Signal already connected."

	var err := source_node.connect(signal_name, callable, int(arguments.get("flags", 0)))
	if err != OK:
		return "Error: Failed to connect signal '%s' (code %s)." % [signal_name, str(err)]

	return _render_variant({
		"source": _node_to_summary(source_node),
		"target": _node_to_summary(target_node),
		"signal_name": signal_name,
		"method_name": method_name,
	})


func create_animation_player(arguments: Dictionary) -> String:
	var scene_root = _editor().get_edited_scene_root()
	if scene_root == null:
		return "Error: No edited scene is open."

	var parent = _resolve_node_path(str(arguments.get("parent_path", "")))
	if parent == null:
		parent = scene_root

	var player := AnimationPlayer.new()
	player.name = _safe_name(str(arguments.get("name", "AnimationPlayer")), "AnimationPlayer")
	parent.add_child(player)
	_assign_owner_recursive(player, scene_root)

	if arguments.has("root_node"):
		player.root_node = NodePath(str(arguments.get("root_node")))

	if bool(arguments.get("select_new_node", true)):
		select_node({"node_path": str(player.get_path()), "focus": true})

	return _render_variant({
		"created": _node_to_summary(player),
		"parent_path": str(parent.get_path()),
	})


func create_animation_clip(arguments: Dictionary) -> String:
	var player = _resolve_animation_player(str(arguments.get("animation_player_path", "")))
	if player == null:
		return "Error: AnimationPlayer not found."

	var animation_name := str(arguments.get("animation_name", "")).strip_edges()
	if animation_name == "":
		return "Error: 'animation_name' is required."

	var library_name := str(arguments.get("library_name", "")).strip_edges()
	var animation := Animation.new()
	animation.length = float(arguments.get("length", 1.0))
	animation.loop_mode = int(arguments.get("loop_mode", Animation.LOOP_NONE))
	animation.step = float(arguments.get("step", 0.1))

	var library := _get_or_create_animation_library(player, library_name)
	if library.has_animation(animation_name):
		library.remove_animation(animation_name)
	library.add_animation(animation_name, animation)

	if bool(arguments.get("set_current", true)):
		player.current_animation = animation_name

	return _render_variant({
		"animation_player": _node_to_summary(player),
		"library_name": library_name,
		"animation_name": animation_name,
		"length": animation.length,
		"loop_mode": animation.loop_mode,
	})


func add_animation_track(arguments: Dictionary) -> String:
	var player = _resolve_animation_player(str(arguments.get("animation_player_path", "")))
	if player == null:
		return "Error: AnimationPlayer not found."

	var animation_name := str(arguments.get("animation_name", "")).strip_edges()
	if animation_name == "":
		return "Error: 'animation_name' is required."

	var library_name := str(arguments.get("library_name", "")).strip_edges()
	var library := _get_or_create_animation_library(player, library_name)
	var animation = library.get_animation(animation_name)
	if animation == null:
		return "Error: Animation '%s' not found." % animation_name

	var track_type := _animation_track_type(str(arguments.get("track_type", "value")))
	var track_index := animation.add_track(track_type)
	animation.track_set_path(track_index, NodePath(str(arguments.get("path", ""))))
	if arguments.has("interpolation_type"):
		animation.track_set_interpolation_type(track_index, int(arguments.get("interpolation_type")))
	if arguments.has("update_mode") and track_type == Animation.TYPE_VALUE:
		animation.value_track_set_update_mode(track_index, int(arguments.get("update_mode")))

	var keys = arguments.get("keys", [])
	if keys is Array:
		for key_data in keys:
			if key_data is Dictionary:
				animation.track_insert_key(
					track_index,
					float(key_data.get("time", 0.0)),
					key_data.get("value"),
					float(key_data.get("transition", 1.0))
				)

	return _render_variant({
		"animation_player": _node_to_summary(player),
		"animation_name": animation_name,
		"track_index": track_index,
		"track_type": track_type,
		"path": str(arguments.get("path", "")),
		"key_count": animation.track_get_key_count(track_index),
	})


func list_animations(arguments: Dictionary) -> String:
	var player = _resolve_animation_player(str(arguments.get("animation_player_path", "")))
	if player == null:
		return "Error: AnimationPlayer not found."

	var libraries: Array = []
	for library_name in player.get_animation_library_list():
		var library = player.get_animation_library(library_name)
		var animations: Array = []
		for animation_name in library.get_animation_list():
			var animation = library.get_animation(animation_name)
			animations.append({
				"name": animation_name,
				"length": animation.length,
				"loop_mode": animation.loop_mode,
				"track_count": animation.get_track_count(),
			})
		libraries.append({
			"name": library_name,
			"animations": animations,
		})

	return _render_variant({
		"animation_player": _node_to_summary(player),
		"libraries": libraries,
	})


func play_animation(arguments: Dictionary) -> String:
	var player = _resolve_animation_player(str(arguments.get("animation_player_path", "")))
	if player == null:
		return "Error: AnimationPlayer not found."

	var animation_name := str(arguments.get("animation_name", "")).strip_edges()
	if animation_name == "":
		return "Error: 'animation_name' is required."

	player.play(animation_name, float(arguments.get("custom_blend", -1.0)), float(arguments.get("custom_speed", 1.0)), bool(arguments.get("from_end", false)))
	return "Playing animation '%s'." % animation_name


func create_packed_scene_from_node(arguments: Dictionary) -> String:
	var node = _resolve_node_path(str(arguments.get("node_path", "")))
	var path := _normalize_path(str(arguments.get("path", "")))
	if node == null:
		return "Error: Node not found."
	if path == "":
		return "Error: 'path' is required."

	var packed := PackedScene.new()
	var pack_err := packed.pack(node)
	if pack_err != OK:
		return "Error: Failed to pack node (code %s)." % str(pack_err)

	var ensure_err := _ensure_parent_dir(path)
	if ensure_err != OK:
		return "Error: Failed to create parent directory for %s" % path

	var save_err := ResourceSaver.save(packed, path, ResourceSaver.FLAG_CHANGE_PATH)
	if save_err != OK:
		return "Error: Failed to save PackedScene to %s (code %s)." % [path, str(save_err)]

	if bool(arguments.get("select_file", true)):
		_editor().select_file(path)
	_refresh_filesystem()
	return _render_variant({
		"source_node": _node_to_summary(node),
		"packed_scene_path": path,
	})


func get_packed_scene_info(arguments: Dictionary) -> String:
	var path := _normalize_path(str(arguments.get("path", "")))
	if path == "":
		return "Error: 'path' is required."

	var packed = load(path)
	if packed == null or not (packed is PackedScene):
		return "Error: PackedScene not found or invalid: %s" % path

	var instance = packed.instantiate()
	if instance == null:
		return "Error: Failed to instantiate PackedScene for inspection: %s" % path

	var info := {
		"path": path,
		"root": _node_to_summary(instance),
		"node_count": _count_nodes(instance),
		"tree": _serialize_scene_tree(instance, int(arguments.get("max_depth", 3))),
	}
	instance.free()
	return _render_variant(info)


func set_camera_2d(arguments: Dictionary) -> String:
	var camera = _resolve_node_path(str(arguments.get("node_path", "")))
	if camera == null or not (camera is Camera2D):
		return "Error: Camera2D not found."

	if arguments.has("enabled"):
		camera.enabled = bool(arguments.get("enabled"))
	if arguments.has("zoom"):
		camera.zoom = _to_vector2(arguments.get("zoom"))
	if arguments.has("offset"):
		camera.offset = _to_vector2(arguments.get("offset"))
	if arguments.has("position"):
		camera.position = _to_vector2(arguments.get("position"))
	if arguments.has("rotation_degrees"):
		camera.rotation_degrees = float(arguments.get("rotation_degrees"))
	if arguments.has("limits"):
		var limits = arguments.get("limits")
		if limits is Dictionary:
			camera.limit_left = int(limits.get("left", camera.limit_left))
			camera.limit_top = int(limits.get("top", camera.limit_top))
			camera.limit_right = int(limits.get("right", camera.limit_right))
			camera.limit_bottom = int(limits.get("bottom", camera.limit_bottom))

	return _render_variant(_build_camera_info(camera))


func set_camera_3d(arguments: Dictionary) -> String:
	var camera = _resolve_node_path(str(arguments.get("node_path", "")))
	if camera == null or not (camera is Camera3D):
		return "Error: Camera3D not found."

	if arguments.has("current"):
		camera.current = bool(arguments.get("current"))
	if arguments.has("projection"):
		camera.projection = int(arguments.get("projection"))
	if arguments.has("fov"):
		camera.fov = float(arguments.get("fov"))
	if arguments.has("size"):
		camera.size = float(arguments.get("size"))
	if arguments.has("near"):
		camera.near = float(arguments.get("near"))
	if arguments.has("far"):
		camera.far = float(arguments.get("far"))
	if arguments.has("cull_mask"):
		camera.cull_mask = int(arguments.get("cull_mask"))
	if arguments.has("position"):
		camera.position = _to_vector3(arguments.get("position"))
	if arguments.has("rotation_degrees"):
		camera.rotation_degrees = _to_vector3(arguments.get("rotation_degrees"))

	return _render_variant(_build_camera_info(camera))


func get_camera_info(arguments: Dictionary) -> String:
	var camera = _resolve_node_path(str(arguments.get("node_path", "")))
	if camera == null or not (camera is Camera2D or camera is Camera3D):
		return "Error: Camera2D or Camera3D not found."
	return _render_variant(_build_camera_info(camera))


func list_node_properties(arguments: Dictionary) -> String:
	var node = _resolve_node_path(str(arguments.get("node_path", "")))
	if node == null:
		return "Error: Node not found."

	var include_usage := bool(arguments.get("include_usage", false))
	var properties: Array = []
	for property_info in node.get_property_list():
		var item := {
			"name": str(property_info.get("name", "")),
			"type": int(property_info.get("type", TYPE_NIL)),
			"class_name": str(property_info.get("class_name", "")),
			"hint": int(property_info.get("hint", 0)),
			"hint_string": str(property_info.get("hint_string", "")),
		}
		if include_usage:
			item["usage"] = int(property_info.get("usage", 0))
		properties.append(item)

	return _render_variant({
		"node": _node_to_summary(node),
		"count": properties.size(),
		"properties": properties,
	})


func list_node_signals(arguments: Dictionary) -> String:
	var node = _resolve_node_path(str(arguments.get("node_path", "")))
	if node == null:
		return "Error: Node not found."

	var signals: Array = []
	for signal_info in node.get_signal_list():
		signals.append({
			"name": str(signal_info.get("name", "")),
			"args": _json_safe(signal_info.get("args", [])),
		})

	return _render_variant({
		"node": _node_to_summary(node),
		"count": signals.size(),
		"signals": signals,
	})


func list_node_methods(arguments: Dictionary) -> String:
	var node = _resolve_node_path(str(arguments.get("node_path", "")))
	if node == null:
		return "Error: Node not found."

	var include_private := bool(arguments.get("include_private", false))
	var methods: Array = []
	for method_info in node.get_method_list():
		var method_name := str(method_info.get("name", ""))
		if not include_private and method_name.begins_with("_"):
			continue
		methods.append({
			"name": method_name,
			"args": _json_safe(method_info.get("args", [])),
			"return": _json_safe(method_info.get("return", {})),
			"flags": int(method_info.get("flags", 0)),
		})

	return _render_variant({
		"node": _node_to_summary(node),
		"count": methods.size(),
		"methods": methods,
	})


func list_addons(_arguments: Dictionary) -> String:
	var addons_dir := "res://addons"
	var addons: Array = []
	if DirAccess.open(addons_dir) == null:
		return _render_variant({"addons": addons})

	for addon_name in DirAccess.get_directories_at(addons_dir):
		var plugin_cfg_path := addons_dir.path_join(addon_name).path_join("plugin.cfg")
		var info := {
			"name": addon_name,
			"path": addons_dir.path_join(addon_name),
			"has_plugin_cfg": FileAccess.file_exists(plugin_cfg_path),
			"enabled": _is_plugin_enabled(addon_name),
		}
		if FileAccess.file_exists(plugin_cfg_path):
			info.merge(_read_plugin_cfg(plugin_cfg_path), true)
		addons.append(info)

	return _render_variant({
		"count": addons.size(),
		"addons": addons,
	})


func set_addon_enabled(arguments: Dictionary) -> String:
	var addon_name := str(arguments.get("addon", "")).strip_edges()
	if addon_name == "":
		return "Error: 'addon' is required."
	if not arguments.has("enabled"):
		return "Error: 'enabled' is required."

	var editor := _editor()
	if not editor.has_method("set_plugin_enabled"):
		return "Error: This Godot version does not expose EditorInterface.set_plugin_enabled."

	editor.set_plugin_enabled(addon_name, bool(arguments.get("enabled")))
	return _render_variant({
		"addon": addon_name,
		"enabled": bool(arguments.get("enabled")),
	})


func list_project_features(_arguments: Dictionary) -> String:
	return _render_variant({
		"project_name": str(ProjectSettings.get_setting("application/config/name", "")),
		"main_scene": str(ProjectSettings.get_setting("application/run/main_scene", "")),
		"rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"input_actions": InputMap.get_actions(),
		"autoloads": _list_autoloads(),
	})


func validate_gdscript_file(arguments: Dictionary) -> String:
	var path := _normalize_path(str(arguments.get("path", "")))
	if path == "":
		return "Error: 'path' is required."
	if not FileAccess.file_exists(path):
		return "Error: File not found: %s" % path

	var source := FileAccess.get_file_as_string(path)
	var script := GDScript.new()
	script.source_code = source
	var err := script.reload()
	return _render_variant({
		"path": path,
		"ok": err == OK,
		"error_code": err,
	})


func get_script_errors(arguments: Dictionary) -> String:
	var root_path := _normalize_path(str(arguments.get("path", "res://")))
	var max_files := clamp(int(arguments.get("max_files", 200)), 1, 3000)
	var script_paths: Array = []
	_collect_matching_files(root_path, true, max_files, script_paths, [".gd"])
	var results: Array = []
	for path in script_paths:
		var validation_text := validate_gdscript_file({"path": path})
		var validation = JSON.parse_string(validation_text)
		if validation is Dictionary and not bool(validation.get("ok", false)):
			results.append(validation)
	return _render_variant({
		"path": root_path,
		"checked": script_paths.size(),
		"error_count": results.size(),
		"errors": results,
	})


func request_script_reload(arguments: Dictionary) -> String:
	var path := _normalize_path(str(arguments.get("path", "")))
	if path != "":
		var script = load(path)
		if script != null and script is Script:
			var err := script.reload()
			_refresh_filesystem()
			return _render_variant({
				"path": path,
				"reload_error": err,
			})

	_refresh_filesystem()
	return "Requested Godot resource filesystem rescan."


func log_message(arguments: Dictionary) -> String:
	var message := str(arguments.get("message", ""))
	var level := str(arguments.get("level", "info")).to_lower()
	match level:
		"error":
			push_error(message)
		"warning", "warn":
			push_warning(message)
		_:
			print(message)
	return _render_variant({
		"level": level,
		"message": message,
	})


func _editor():
	return _plugin.get_editor_interface()


func _build_scene_info(scene_root: Node) -> Dictionary:
	return {
		"scene_path": scene_root.scene_file_path,
		"scene_root": _node_to_summary(scene_root),
		"node_count": _count_nodes(scene_root),
		"selected_nodes": _editor().get_selection().get_selected_nodes().size(),
		"child_count": scene_root.get_child_count(),
	}


func _build_node_info(node: Node) -> Dictionary:
	var info := _node_to_summary(node)
	info["child_count"] = node.get_child_count()
	info["groups"] = node.get_groups()
	info["script"] = node.get_script().resource_path if node.get_script() != null else ""
	if node is Node2D:
		info["position"] = _json_safe(node.position)
		info["rotation_degrees"] = node.rotation_degrees
		info["scale"] = _json_safe(node.scale)
	if node is Control:
		info["position"] = _json_safe(node.position)
		info["size"] = _json_safe(node.size)
		info["rotation_degrees"] = node.rotation_degrees
		info["scale"] = _json_safe(node.scale)
	if node is Node3D:
		info["position"] = _json_safe(node.position)
		info["rotation_degrees"] = _json_safe(node.rotation_degrees)
		info["scale"] = _json_safe(node.scale)
	if node is Control:
		info.merge(_build_control_info(node))
	return info


func _build_control_info(control: Control) -> Dictionary:
	return {
		"name": control.name,
		"type": control.get_class(),
		"path": str(control.get_path()),
		"position": _json_safe(control.position),
		"size": _json_safe(control.size),
		"anchors": {
			"left": control.anchor_left,
			"top": control.anchor_top,
			"right": control.anchor_right,
			"bottom": control.anchor_bottom,
		},
		"offsets": {
			"left": control.offset_left,
			"top": control.offset_top,
			"right": control.offset_right,
			"bottom": control.offset_bottom,
		},
		"size_flags_horizontal": control.size_flags_horizontal,
		"size_flags_vertical": control.size_flags_vertical,
	}


func _build_camera_info(camera: Node) -> Dictionary:
	var info := _node_to_summary(camera)
	if camera is Camera2D:
		info["enabled"] = camera.enabled
		info["zoom"] = _json_safe(camera.zoom)
		info["offset"] = _json_safe(camera.offset)
		info["position"] = _json_safe(camera.position)
		info["rotation_degrees"] = camera.rotation_degrees
		info["limits"] = {
			"left": camera.limit_left,
			"top": camera.limit_top,
			"right": camera.limit_right,
			"bottom": camera.limit_bottom,
		}
	if camera is Camera3D:
		info["current"] = camera.current
		info["projection"] = camera.projection
		info["fov"] = camera.fov
		info["size"] = camera.size
		info["near"] = camera.near
		info["far"] = camera.far
		info["cull_mask"] = camera.cull_mask
		info["position"] = _json_safe(camera.position)
		info["rotation_degrees"] = _json_safe(camera.rotation_degrees)
	return info


func _collect_files(path: String, recursive: bool, include_hidden: bool, max_entries: int, results: Array) -> void:
	if results.size() >= max_entries:
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if results.size() >= max_entries:
			break
		if not include_hidden and item.begins_with("."):
			item = dir.get_next()
			continue

		var child_path := path.path_join(item)
		if dir.current_is_dir():
			results.append({"path": child_path, "type": "dir"})
			if recursive:
				_collect_files(child_path, recursive, include_hidden, max_entries, results)
		else:
			results.append({"path": child_path, "type": "file"})
		item = dir.get_next()

	dir.list_dir_end()


func _collect_matching_files(path: String, recursive: bool, max_entries: int, results: Array, extensions: Array) -> void:
	if results.size() >= max_entries:
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if results.size() >= max_entries:
			break
		var child_path := path.path_join(item)
		if dir.current_is_dir():
			if recursive:
				_collect_matching_files(child_path, recursive, max_entries, results, extensions)
		elif _matches_extension(child_path, extensions):
			results.append(child_path)
		item = dir.get_next()

	dir.list_dir_end()


func _search_files_recursive(path: String, pattern: String, mode: String, recursive: bool, max_results: int, matches: Array) -> void:
	if matches.size() >= max_results:
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if matches.size() >= max_results:
			break

		var child_path := path.path_join(item)
		if dir.current_is_dir():
			if recursive:
				_search_files_recursive(child_path, pattern, mode, recursive, max_results, matches)
		else:
			var path_match := child_path.to_lower().contains(pattern.to_lower())
			var content_match := false
			if mode == "content" or mode == "both":
				if _matches_extension(child_path, TEXT_EXTENSIONS):
					var file := FileAccess.open(child_path, FileAccess.READ)
					if file != null:
						content_match = file.get_as_text().contains(pattern)
			if (mode == "path" and path_match) or (mode == "content" and content_match) or (mode == "both" and (path_match or content_match)):
				matches.append({
					"path": child_path,
					"path_match": path_match,
					"content_match": content_match,
				})
		item = dir.get_next()

	dir.list_dir_end()


func _serialize_scene_tree(node: Node, max_depth: int, depth: int = 0) -> Dictionary:
	var summary := _node_to_summary(node)
	summary["children"] = []
	if depth >= max_depth:
		summary["truncated"] = node.get_child_count() > 0
		return summary

	for child in node.get_children():
		if child is Node:
			summary["children"].append(_serialize_scene_tree(child, max_depth, depth + 1))
	return summary


func _resolve_node_path(node_path: String):
	var scene_root = _editor().get_edited_scene_root()
	if scene_root == null:
		return null
	if node_path == "" or node_path == ".":
		return scene_root
	if str(scene_root.get_path()) == node_path:
		return scene_root
	if node_path.begins_with("/"):
		return scene_root.get_tree().root.get_node_or_null(NodePath(node_path))
	return scene_root.get_node_or_null(NodePath(node_path))


func _resolve_control(node_path: String) -> Control:
	var node = _resolve_node_path(node_path)
	if node == null or not (node is Control):
		return null
	return node


func _resolve_animation_player(node_path: String):
	var node = _resolve_node_path(node_path)
	if node == null or not (node is AnimationPlayer):
		return null
	return node


func _normalize_path(path: String) -> String:
	var trimmed := path.strip_edges()
	if trimmed == "":
		return ""
	if trimmed.begins_with("res://") or trimmed.begins_with("user://"):
		return trimmed.simplify_path()
	return ("res://" + trimmed.trim_prefix("/")).simplify_path()


func _ensure_parent_dir(path: String) -> int:
	var parent_dir := path.get_base_dir()
	if parent_dir == "" or parent_dir == "res://" or parent_dir == "user://":
		return OK
	return DirAccess.make_dir_recursive_absolute(parent_dir)


func _create_control_internal(control_type: String, arguments: Dictionary) -> String:
	var scene_root = _editor().get_edited_scene_root()
	if scene_root == null:
		return "Error: No edited scene is open."
	if not ClassDB.class_exists(control_type):
		return "Error: Unknown control type '%s'." % control_type

	var instance = ClassDB.instantiate(control_type)
	if instance == null or not (instance is Control):
		return "Error: '%s' is not instantiable as a Control." % control_type

	var parent = _resolve_node_path(str(arguments.get("parent_path", "")))
	if parent == null:
		parent = scene_root
	if not (parent is Node):
		return "Error: Parent not found."

	var control: Control = instance
	control.name = _safe_name(str(arguments.get("name", control_type)), control_type)
	parent.add_child(control)
	_assign_owner_recursive(control, scene_root)

	if arguments.has("text") and _has_property(control, "text"):
		control.set("text", str(arguments.get("text")))
	if arguments.has("placeholder_text") and _has_property(control, "placeholder_text"):
		control.set("placeholder_text", str(arguments.get("placeholder_text")))
	if arguments.has("tooltip_text") and _has_property(control, "tooltip_text"):
		control.tooltip_text = str(arguments.get("tooltip_text"))
	if arguments.has("size"):
		control.size = _to_vector2(arguments.get("size"))
	if arguments.has("position"):
		control.position = _to_vector2(arguments.get("position"))
	if arguments.has("custom_minimum_size"):
		control.custom_minimum_size = _to_vector2(arguments.get("custom_minimum_size"))
	if arguments.has("mouse_filter"):
		control.mouse_filter = int(arguments.get("mouse_filter"))
	if arguments.has("layout_preset"):
		_apply_layout_preset(control, str(arguments.get("layout_preset")))
	if arguments.has("horizontal_size_flags"):
		control.size_flags_horizontal = _parse_size_flags(arguments.get("horizontal_size_flags"))
	if arguments.has("vertical_size_flags"):
		control.size_flags_vertical = _parse_size_flags(arguments.get("vertical_size_flags"))
	if arguments.has("theme_type_variation") and _has_property(control, "theme_type_variation"):
		control.set("theme_type_variation", str(arguments.get("theme_type_variation")))

	if control is TextureRect:
		if arguments.has("texture_path"):
			var texture_path := _normalize_path(str(arguments.get("texture_path")))
			var texture = load(texture_path)
			if texture != null:
				control.texture = texture
		if arguments.has("stretch_mode"):
			control.stretch_mode = int(arguments.get("stretch_mode"))
		if arguments.has("expand_mode"):
			control.expand_mode = int(arguments.get("expand_mode"))

	if bool(arguments.get("select_new_node", true)):
		select_node({"node_path": str(control.get_path()), "focus": true})

	return _render_variant({
		"created": _build_control_info(control),
		"parent_path": str(parent.get_path()),
	})


func _apply_layout_preset(control: Control, preset_name: String) -> void:
	match preset_name.to_lower():
		"full_rect":
			control.anchor_left = 0.0
			control.anchor_top = 0.0
			control.anchor_right = 1.0
			control.anchor_bottom = 1.0
			control.offset_left = 0.0
			control.offset_top = 0.0
			control.offset_right = 0.0
			control.offset_bottom = 0.0
		"top_left":
			control.anchor_left = 0.0
			control.anchor_top = 0.0
			control.anchor_right = 0.0
			control.anchor_bottom = 0.0
		"top_right":
			control.anchor_left = 1.0
			control.anchor_top = 0.0
			control.anchor_right = 1.0
			control.anchor_bottom = 0.0
		"bottom_left":
			control.anchor_left = 0.0
			control.anchor_top = 1.0
			control.anchor_right = 0.0
			control.anchor_bottom = 1.0
		"bottom_right":
			control.anchor_left = 1.0
			control.anchor_top = 1.0
			control.anchor_right = 1.0
			control.anchor_bottom = 1.0
		"center":
			control.anchor_left = 0.5
			control.anchor_top = 0.5
			control.anchor_right = 0.5
			control.anchor_bottom = 0.5
		"left_wide":
			control.anchor_left = 0.0
			control.anchor_top = 0.0
			control.anchor_right = 0.0
			control.anchor_bottom = 1.0
		"right_wide":
			control.anchor_left = 1.0
			control.anchor_top = 0.0
			control.anchor_right = 1.0
			control.anchor_bottom = 1.0
		"top_wide":
			control.anchor_left = 0.0
			control.anchor_top = 0.0
			control.anchor_right = 1.0
			control.anchor_bottom = 0.0
		"bottom_wide":
			control.anchor_left = 0.0
			control.anchor_top = 1.0
			control.anchor_right = 1.0
			control.anchor_bottom = 1.0


func _parse_size_flags(value) -> int:
	if value == null:
		return 0
	if typeof(value) == TYPE_INT:
		return int(value)
	if value is Array:
		var combined := 0
		for item in value:
			combined |= _parse_size_flags(item)
		return combined
	var normalized := str(value).strip_edges().to_lower()
	if SIZE_FLAG_MAP.has(normalized):
		return int(SIZE_FLAG_MAP[normalized])
	return 0


func _get_or_create_animation_library(player: AnimationPlayer, library_name: String):
	if player.has_animation_library(library_name):
		return player.get_animation_library(library_name)
	var library := AnimationLibrary.new()
	player.add_animation_library(library_name, library)
	return library


func _animation_track_type(track_type: String) -> int:
	match track_type.to_lower():
		"value":
			return Animation.TYPE_VALUE
		"position_3d":
			return Animation.TYPE_POSITION_3D
		"rotation_3d":
			return Animation.TYPE_ROTATION_3D
		"scale_3d":
			return Animation.TYPE_SCALE_3D
		"blend_shape":
			return Animation.TYPE_BLEND_SHAPE
		"method":
			return Animation.TYPE_METHOD
		"bezier":
			return Animation.TYPE_BEZIER
		"audio":
			return Animation.TYPE_AUDIO
		"animation":
			return Animation.TYPE_ANIMATION
		_:
			return Animation.TYPE_VALUE


func _is_plugin_enabled(addon_name: String) -> bool:
	var editor := _editor()
	if editor.has_method("is_plugin_enabled"):
		return bool(editor.is_plugin_enabled(addon_name))
	var enabled_plugins = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	for plugin_name in enabled_plugins:
		if str(plugin_name) == addon_name:
			return true
	return false


func _read_plugin_cfg(path: String) -> Dictionary:
	var config := ConfigFile.new()
	var err := config.load(path)
	if err != OK:
		return {"config_error": err}
	return {
		"display_name": str(config.get_value("plugin", "name", "")),
		"description": str(config.get_value("plugin", "description", "")),
		"author": str(config.get_value("plugin", "author", "")),
		"version": str(config.get_value("plugin", "version", "")),
		"script": str(config.get_value("plugin", "script", "")),
	}


func _list_autoloads() -> Array:
	var autoloads: Array = []
	for property_info in ProjectSettings.get_property_list():
		var name := str(property_info.get("name", ""))
		if name.begins_with("autoload/"):
			autoloads.append({
				"name": name.trim_prefix("autoload/"),
				"path": str(ProjectSettings.get_setting(name, "")),
			})
	return autoloads


func _refresh_filesystem() -> void:
	var resource_filesystem = _editor().get_resource_filesystem()
	if resource_filesystem != null:
		resource_filesystem.scan()


func _get_log_files(include_rotated: bool) -> Array:
	var configured_path := String(ProjectSettings.get_setting("debug/file_logging/log_path", "user://logs/godot.log"))
	var current_log_path := ProjectSettings.globalize_path(configured_path)
	var log_dir := current_log_path.get_base_dir()
	var files: Array = []
	if not DirAccess.dir_exists_absolute(log_dir):
		return files

	for file_name in DirAccess.get_files_at(log_dir):
		if not file_name.begins_with(current_log_path.get_file()):
			continue
		if not include_rotated and file_name != current_log_path.get_file():
			continue
		files.append(log_dir.path_join(file_name))
	files.sort()
	return files


func _matches_log_filters(line: String, severity: String, filter_text: String) -> bool:
	var normalized_line := line.to_lower()
	if filter_text != "" and not normalized_line.contains(filter_text.to_lower()):
		return false

	match severity:
		"error":
			return normalized_line.contains("error") or normalized_line.contains("err:")
		"warning":
			return normalized_line.contains("warning") or normalized_line.contains("warn:")
		"info":
			return not normalized_line.contains("error") and not normalized_line.contains("warning")
		_:
			return true


func _safe_name(requested_name: String, fallback: String) -> String:
	var trimmed := requested_name.strip_edges()
	return trimmed if trimmed != "" else fallback


func _assign_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		if child is Node:
			_assign_owner_recursive(child, owner)


func _capture_global_transform(node):
	if node is Node2D:
		return {"kind": "Node2D", "transform": node.global_transform}
	if node is Node3D:
		return {"kind": "Node3D", "transform": node.global_transform}
	if node is Control:
		return {"kind": "Control", "position": node.global_position}
	return null


func _restore_global_transform(node, stored_transform) -> void:
	if stored_transform == null:
		return
	match str(stored_transform.get("kind", "")):
		"Node2D":
			if node is Node2D:
				node.global_transform = stored_transform.get("transform")
		"Node3D":
			if node is Node3D:
				node.global_transform = stored_transform.get("transform")
		"Control":
			if node is Control:
				node.global_position = stored_transform.get("position")


func _count_nodes(node: Node) -> int:
	if node == null:
		return 0
	var total := 1
	for child in node.get_children():
		if child is Node:
			total += _count_nodes(child)
	return total


func _analyze_node_recursive(node: Node, depth: int, stats: Dictionary) -> void:
	stats["total_nodes"] += 1
	stats["max_depth"] = max(int(stats["max_depth"]), depth)
	stats["unique_classes"][node.get_class()] = true

	if node is Node2D:
		stats["node_2d_count"] += 1
	if node is Node3D:
		stats["node_3d_count"] += 1
	if node is Control:
		stats["control_count"] += 1
	if node.get_script() != null:
		stats["scripted_nodes"] += 1
	if "Light" in node.get_class():
		stats["light_count"] += 1
	if "Camera" in node.get_class():
		stats["camera_count"] += 1
	if "Collision" in node.get_class():
		stats["collision_count"] += 1
	if "Audio" in node.get_class():
		stats["audio_count"] += 1
	if "Particles" in node.get_class():
		stats["particles_count"] += 1

	for child in node.get_children():
		if child is Node:
			_analyze_node_recursive(child, depth + 1, stats)


func _find_nodes_recursive(node: Node, name_contains: String, class_name: String, script_path: String, max_results: int, results: Array) -> void:
	if results.size() >= max_results:
		return

	var name_ok := name_contains == "" or node.name.to_lower().contains(name_contains)
	var class_ok := class_name == "" or node.is_class(class_name)
	var script_ok := script_path == "" or (node.get_script() != null and node.get_script().resource_path == script_path)
	if name_ok and class_ok and script_ok:
		results.append(_node_to_summary(node))

	for child in node.get_children():
		if child is Node and results.size() < max_results:
			_find_nodes_recursive(child, name_contains, class_name, script_path, max_results, results)


func _matches_extension(path: String, extensions: Array) -> bool:
	var lower := path.to_lower()
	for extension in extensions:
		if lower.ends_with(str(extension).to_lower()):
			return true
	return false


func _to_vector2(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	if value is String:
		var parts := value.split(",")
		if parts.size() >= 2:
			return Vector2(float(parts[0]), float(parts[1]))
	return Vector2.ZERO


func _to_vector3(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		return Vector3(
			float(value.get("x", 0.0)),
			float(value.get("y", 0.0)),
			float(value.get("z", 0.0))
		)
	if value is String:
		var parts := value.split(",")
		if parts.size() >= 3:
			return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	return Vector3.ZERO


func _to_keycode(value) -> int:
	if value == null:
		return 0
	if typeof(value) == TYPE_INT:
		return int(value)
	var text := str(value).strip_edges()
	if text == "":
		return 0
	var normalized := text.to_lower()
	if KEY_NAME_MAP.has(normalized):
		return int(KEY_NAME_MAP[normalized])
	if text.length() == 1:
		return text.unicode_at(0)
	return 0


func _to_mouse_button(value) -> int:
	if value == null:
		return MOUSE_BUTTON_LEFT
	if typeof(value) == TYPE_INT:
		return int(value)
	var normalized := str(value).strip_edges().to_lower()
	if MOUSE_BUTTON_MAP.has(normalized):
		return int(MOUSE_BUTTON_MAP[normalized])
	return MOUSE_BUTTON_LEFT


func _to_color(value) -> Color:
	if value is Color:
		return value
	if value is Dictionary:
		return Color(
			float(value.get("r", 1.0)),
			float(value.get("g", 1.0)),
			float(value.get("b", 1.0)),
			float(value.get("a", 1.0))
		)
	if value is Array and value.size() >= 3:
		return Color(
			float(value[0]),
			float(value[1]),
			float(value[2]),
			float(value[3]) if value.size() >= 4 else 1.0
		)
	var text := str(value).strip_edges()
	if text == "":
		return Color.WHITE
	return Color.from_string(text, Color.WHITE)


func _has_property(object: Object, property_name: String) -> bool:
	for property_info in object.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return true
	return false


func _node_to_summary(node) -> Variant:
	if node == null:
		return null
	return {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"scene_file_path": node.scene_file_path,
	}


func _render_variant(value) -> String:
	if value == null:
		return "null"
	if value is String:
		return value
	if value is bool or value is int or value is float:
		return str(value)
	return JSON.stringify(_json_safe(value), "\t")


func _json_safe(value):
	match typeof(value):
		TYPE_NIL:
			return null
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_ARRAY:
			var arr: Array = []
			for item in value:
				arr.append(_json_safe(item))
			return arr
		TYPE_DICTIONARY:
			var dict := {}
			for key in value.keys():
				dict[str(key)] = _json_safe(value[key])
			return dict
		TYPE_OBJECT:
			if value is Node:
				return _node_to_summary(value)
			if value is Resource:
				return {
					"type": value.get_class(),
					"resource_path": value.resource_path,
				}
			return {
				"type": value.get_class(),
				"string": str(value),
			}
		_:
			return str(value)
