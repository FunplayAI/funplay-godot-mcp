@tool
extends RefCounted

signal settings_changed

const SETTINGS_PATH := "user://funplay_mcp_settings.cfg"

var server_enabled: bool = true
var server_port: int = 8765
var tool_profile: String = "core"


func _init() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		return

	server_enabled = bool(config.get_value("server", "enabled", true))
	server_port = int(config.get_value("server", "port", 8765))
	tool_profile = str(config.get_value("server", "tool_profile", "core"))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("server", "enabled", server_enabled)
	config.set_value("server", "port", server_port)
	config.set_value("server", "tool_profile", tool_profile)
	config.save(SETTINGS_PATH)


func update_server_enabled(value: bool) -> void:
	if server_enabled == value:
		return
	server_enabled = value
	save_settings()
	settings_changed.emit()


func update_server_port(value: int) -> void:
	var normalized := max(value, 1)
	if server_port == normalized:
		return
	server_port = normalized
	save_settings()
	settings_changed.emit()


func update_tool_profile(value: String) -> void:
	var normalized := value if value in ["core", "full"] else "core"
	if tool_profile == normalized:
		return
	tool_profile = normalized
	save_settings()
	settings_changed.emit()
