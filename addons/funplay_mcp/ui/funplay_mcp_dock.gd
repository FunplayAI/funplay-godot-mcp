@tool
extends VBoxContainer

var _server
var _settings
var _client_config_writer

var _title_label: Label
var _status_label: Label
var _endpoint_label: Label
var _enable_checkbox: CheckBox
var _port_spinbox: SpinBox
var _profile_button: OptionButton
var _client_button: OptionButton
var _snippet_text: TextEdit
var _log_text: TextEdit
var _copy_status_label: Label
var _config_status_label: Label
var _config_path_label: Label
var _last_refresh_msec := 0


func setup(server, settings, client_config_writer) -> void:
	_server = server
	_settings = settings
	_client_config_writer = client_config_writer
	_build_ui()
	refresh_live_state(true)


func refresh_live_state(force: bool = false) -> void:
	var now := Time.get_ticks_msec()
	if not force and now - _last_refresh_msec < 300:
		return
	_last_refresh_msec = now

	if _status_label == null:
		return

	_status_label.text = "Status: Running" if _server.is_running() else "Status: Stopped"
	_endpoint_label.text = "Endpoint: %s" % (_server.get_endpoint() if _server.is_running() else "http://127.0.0.1:%d/" % _settings.server_port)
	_enable_checkbox.set_pressed_no_signal(_settings.server_enabled)
	_port_spinbox.set_value_no_signal(_settings.server_port)

	if _settings.tool_profile == "core":
		_profile_button.select(0)
	else:
		_profile_button.select(1)

	_snippet_text.text = _build_client_snippet(_client_button.get_item_text(_client_button.selected))
	_log_text.text = _build_log_text()
	_refresh_config_status()


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

	_title_label = Label.new()
	_title_label.text = "Funplay MCP"
	_title_label.add_theme_font_size_override("font_size", 18)
	add_child(_title_label)

	_status_label = Label.new()
	add_child(_status_label)

	_endpoint_label = Label.new()
	_endpoint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_endpoint_label)

	_enable_checkbox = CheckBox.new()
	_enable_checkbox.text = "Enable MCP Server"
	_enable_checkbox.toggled.connect(_on_enable_toggled)
	add_child(_enable_checkbox)

	var port_label := Label.new()
	port_label.text = "Port"
	add_child(port_label)

	_port_spinbox = SpinBox.new()
	_port_spinbox.min_value = 1
	_port_spinbox.max_value = 65535
	_port_spinbox.step = 1
	_port_spinbox.value_changed.connect(_on_port_changed)
	add_child(_port_spinbox)

	var profile_label := Label.new()
	profile_label.text = "Tool Profile"
	add_child(profile_label)

	_profile_button = OptionButton.new()
	_profile_button.add_item("core")
	_profile_button.add_item("full")
	_profile_button.item_selected.connect(_on_profile_selected)
	add_child(_profile_button)

	var client_label := Label.new()
	client_label.text = "Client Config Snippet"
	add_child(client_label)

	_client_button = OptionButton.new()
	for client_name in ["Codex", "Claude Code", "Cursor", "VS Code"]:
		_client_button.add_item(client_name)
	_client_button.select(0)
	_client_button.item_selected.connect(_on_client_selected)
	add_child(_client_button)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	add_child(action_row)

	var copy_button := Button.new()
	copy_button.text = "Copy Snippet"
	copy_button.pressed.connect(_copy_snippet)
	action_row.add_child(copy_button)

	var configure_button := Button.new()
	configure_button.text = "Configure"
	configure_button.pressed.connect(_configure_client)
	action_row.add_child(configure_button)

	_copy_status_label = Label.new()
	add_child(_copy_status_label)

	_config_status_label = Label.new()
	add_child(_config_status_label)

	_config_path_label = Label.new()
	_config_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_config_path_label)

	_snippet_text = TextEdit.new()
	_snippet_text.custom_minimum_size = Vector2(0, 130)
	_snippet_text.editable = false
	_snippet_text.size_flags_vertical = Control.SIZE_FILL
	add_child(_snippet_text)

	var log_label := Label.new()
	log_label.text = "Recent Activity"
	add_child(log_label)

	_log_text = TextEdit.new()
	_log_text.custom_minimum_size = Vector2(0, 180)
	_log_text.editable = false
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_log_text)


func _on_enable_toggled(pressed: bool) -> void:
	_settings.update_server_enabled(pressed)
	if pressed:
		_server.start()
	else:
		_server.stop()
	refresh_live_state(true)


func _on_port_changed(value: float) -> void:
	_settings.update_server_port(int(value))
	if _server.is_running():
		_server.restart()
	refresh_live_state(true)


func _on_profile_selected(index: int) -> void:
	var value := "core" if index == 0 else "full"
	_settings.update_tool_profile(value)
	if _server.is_running():
		_server.restart()
	refresh_live_state(true)


func _on_client_selected(_index: int) -> void:
	refresh_live_state(true)


func _copy_snippet() -> void:
	DisplayServer.clipboard_set(_snippet_text.text)
	_copy_status_label.text = "Copied to clipboard."


func _configure_client() -> void:
	var target := _get_selected_target()
	var result := _client_config_writer.configure_target(target)
	_copy_status_label.text = result.get("message", "")
	refresh_live_state(true)


func _build_client_snippet(client_name: String) -> String:
	var target := _get_selected_target()
	return _client_config_writer.build_snippet(target)


func _build_log_text() -> String:
	var log_entries := _server.get_interaction_log()
	if log_entries.is_empty():
		return "No activity yet."

	var lines: Array[String] = []
	for entry in log_entries:
		lines.append("[%s] %s (%s)\n%s" % [
			entry.get("timestamp", ""),
			entry.get("name", ""),
			entry.get("status", ""),
			entry.get("message", ""),
		])
	return "\n\n".join(lines)


func _get_selected_target() -> Dictionary:
	var endpoint := _server.get_endpoint() if _server.is_running() else "http://127.0.0.1:%d/" % _settings.server_port
	var targets := _client_config_writer.list_targets(endpoint)
	var selected_name := _client_button.get_item_text(_client_button.selected)
	for target in targets:
		if str(target.get("name", "")) == selected_name:
			return target
	return targets[0] if not targets.is_empty() else {}


func _refresh_config_status() -> void:
	if _config_status_label == null or _config_path_label == null or _client_config_writer == null:
		return

	var target := _get_selected_target()
	if target.is_empty():
		_config_status_label.text = "Config status: unavailable"
		_config_path_label.text = ""
		return

	var exists := _client_config_writer.target_exists(target)
	_config_status_label.text = "Config status: Configured" if exists else "Config status: Not configured"
	_config_path_label.text = str(target.get("path", ""))
