@tool
extends RefCounted

signal settings_changed

const SETTINGS_PATH = "user://funplay_mcp_settings.cfg"

var server_enabled: bool = true
var server_port: int = 8765
var server_auth_token: String = ""
var tool_profile: String = "core"
var debug_logging_enabled: bool = false
var execute_code_safety_checks_enabled: bool = true
var disabled_tools: Array[String] = []


func _init() -> void:
	load_settings()
	if server_auth_token == "":
		server_auth_token = _generate_auth_token()
		save_settings()


func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK:
		return

	server_enabled = bool(config.get_value("server", "enabled", true))
	server_port = int(config.get_value("server", "port", 8765))
	server_auth_token = str(config.get_value("server", "auth_token", ""))
	tool_profile = str(config.get_value("server", "tool_profile", "core"))
	debug_logging_enabled = bool(config.get_value("server", "debug_logging_enabled", false))
	execute_code_safety_checks_enabled = bool(config.get_value("server", "execute_code_safety_checks_enabled", true))
	disabled_tools = _normalize_string_array(config.get_value("tools", "disabled", []))


func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("server", "enabled", server_enabled)
	config.set_value("server", "port", server_port)
	config.set_value("server", "auth_token", server_auth_token)
	config.set_value("server", "tool_profile", tool_profile)
	config.set_value("server", "debug_logging_enabled", debug_logging_enabled)
	config.set_value("server", "execute_code_safety_checks_enabled", execute_code_safety_checks_enabled)
	config.set_value("tools", "disabled", disabled_tools)
	config.save(SETTINGS_PATH)


func update_server_enabled(value: bool) -> void:
	if server_enabled == value:
		return
	server_enabled = value
	save_settings()
	settings_changed.emit()


func update_server_port(value: int) -> void:
	var normalized = max(value, 1)
	if server_port == normalized:
		return
	server_port = normalized
	save_settings()
	settings_changed.emit()


func rotate_server_auth_token() -> void:
	server_auth_token = _generate_auth_token()
	save_settings()
	settings_changed.emit()


func update_tool_profile(value: String) -> void:
	var normalized = value if value in ["core", "full"] else "core"
	if tool_profile == normalized:
		return
	tool_profile = normalized
	save_settings()
	settings_changed.emit()


func update_debug_logging_enabled(value: bool) -> void:
	if debug_logging_enabled == value:
		return
	debug_logging_enabled = value
	save_settings()
	settings_changed.emit()


func update_execute_code_safety_checks_enabled(value: bool) -> void:
	if execute_code_safety_checks_enabled == value:
		return
	execute_code_safety_checks_enabled = value
	save_settings()
	settings_changed.emit()


func is_tool_disabled(tool_name: String) -> bool:
	return tool_name in disabled_tools


func update_tool_disabled(tool_name: String, disabled: bool) -> void:
	var normalized = tool_name.strip_edges()
	if normalized == "":
		return

	var changed = false
	if disabled:
		if not (normalized in disabled_tools):
			disabled_tools.append(normalized)
			changed = true
	else:
		var index = disabled_tools.find(normalized)
		if index >= 0:
			disabled_tools.remove_at(index)
			changed = true

	if changed:
		disabled_tools.sort()
		save_settings()
		settings_changed.emit()


func clear_disabled_tools() -> void:
	if disabled_tools.is_empty():
		return
	disabled_tools.clear()
	save_settings()
	settings_changed.emit()


func _normalize_string_array(value) -> Array[String]:
	var results: Array[String] = []
	if value is Array:
		for item in value:
			var text = str(item).strip_edges()
			if text != "" and not (text in results):
				results.append(text)
	results.sort()
	return results


func _generate_auth_token() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var seed = "%s:%s:%s:%s:%s" % [
		ProjectSettings.globalize_path("res://"),
		Time.get_datetime_string_from_system(true, true),
		str(Time.get_ticks_usec()),
		str(rng.randi()),
		str(rng.randi()),
	]
	return seed.sha256_text()
