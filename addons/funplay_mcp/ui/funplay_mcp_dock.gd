@tool
extends VBoxContainer

const FunplayProjectSkillManager = preload("res://addons/funplay_mcp/core/funplay_project_skill_manager.gd")
const FunplayUpdateChecker = preload("res://addons/funplay_mcp/core/funplay_update_checker.gd")

const REFRESH_INTERVAL_MSEC = 1000

var _server
var _settings
var _client_config_writer
var _tool_registry
var _skill_manager = FunplayProjectSkillManager.new()
var _update_checker = FunplayUpdateChecker.new()

var _title_label: Label
var _version_label: Label
var _update_status_label: Label
var _check_updates_button: Button
var _open_release_button: Button
var _status_label: Label
var _endpoint_label: Label
var _enable_checkbox: CheckBox
var _port_spinbox: SpinBox
var _profile_button: OptionButton
var _debug_checkbox: CheckBox
var _execute_safety_checkbox: CheckBox
var _map_status_label: Label
var _tool_exposure_label: Label
var _tool_list: VBoxContainer
var _client_button: OptionButton
var _snippet_text: TextEdit
var _log_text: TextEdit
var _copy_status_label: Label
var _config_status_label: Label
var _config_path_label: Label
var _skill_status_label: Label
var _last_refresh_msec: int = 0
var _last_tool_exposure_signature: String = ""
var _updating_tool_checks: bool = false
var _needs_refresh_when_visible: bool = true


func setup(server, settings, client_config_writer, tool_registry = null) -> void:
	_server = server
	_settings = settings
	_client_config_writer = client_config_writer
	_tool_registry = tool_registry
	name = "Funplay MCP"
	_build_ui()
	_update_checker.setup(self)
	if not _update_checker.state_changed.is_connected(_on_update_state_changed):
		_update_checker.state_changed.connect(_on_update_state_changed)
	call_deferred("_refresh_when_visible")


func refresh_live_state(force: bool = false) -> void:
	if not _is_active_dock_tab():
		_needs_refresh_when_visible = true
		return

	var now: int = Time.get_ticks_msec()
	if not force and now - _last_refresh_msec < REFRESH_INTERVAL_MSEC:
		return
	_last_refresh_msec = now
	_needs_refresh_when_visible = false

	if _status_label == null:
		return

	var status_text: String = "Stopped"
	if _server.is_running():
		status_text = "Attached" if _server.has_method("is_attached_to_existing") and _server.is_attached_to_existing() else "Running"
	_set_label_text(_status_label, "Status: %s" % status_text)
	_set_label_text(_endpoint_label, "Endpoint: %s" % (_server.get_endpoint() if _server.is_running() else "http://127.0.0.1:%d/" % _settings.server_port))
	_set_checkbox_pressed(_enable_checkbox, _settings.server_enabled)
	if int(_port_spinbox.value) != _settings.server_port:
		_port_spinbox.set_value_no_signal(_settings.server_port)
	_set_checkbox_pressed(_debug_checkbox, _settings.debug_logging_enabled)
	_set_checkbox_pressed(_execute_safety_checkbox, _settings.execute_code_safety_checks_enabled)

	if _settings.tool_profile == "core":
		if _profile_button.selected != 0:
			_profile_button.select(0)
	else:
		if _profile_button.selected != 1:
			_profile_button.select(1)

	_refresh_tool_exposure(force)
	_set_text_edit_text(_snippet_text, _build_client_snippet(_client_button.get_item_text(_client_button.selected)))
	_set_text_edit_text(_log_text, _build_log_text())
	_refresh_config_status()
	_refresh_skill_status()
	_refresh_update_state()


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var content_scroll = ScrollContainer.new()
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(content_scroll)

	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	content_scroll.add_child(content)

	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	content.add_child(title_row)

	_title_label = Label.new()
	_title_label.text = "Funplay MCP"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_label)

	_version_label = Label.new()
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(_version_label)

	var update_row = HBoxContainer.new()
	update_row.add_theme_constant_override("separation", 6)
	content.add_child(update_row)

	_update_status_label = Label.new()
	_update_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	update_row.add_child(_update_status_label)

	_check_updates_button = Button.new()
	_check_updates_button.text = "Check Updates"
	_check_updates_button.pressed.connect(_check_for_updates)
	update_row.add_child(_check_updates_button)

	_open_release_button = Button.new()
	_open_release_button.text = "Open Release"
	_open_release_button.pressed.connect(_open_latest_release)
	update_row.add_child(_open_release_button)

	_status_label = Label.new()
	content.add_child(_status_label)

	_endpoint_label = Label.new()
	_endpoint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_endpoint_label)

	_enable_checkbox = CheckBox.new()
	_enable_checkbox.text = "Enable MCP Server"
	_enable_checkbox.toggled.connect(_on_enable_toggled)
	content.add_child(_enable_checkbox)

	var port_label = Label.new()
	port_label.text = "Port"
	content.add_child(port_label)

	_port_spinbox = SpinBox.new()
	_port_spinbox.min_value = 1
	_port_spinbox.max_value = 65535
	_port_spinbox.step = 1
	_port_spinbox.value_changed.connect(_on_port_changed)
	content.add_child(_port_spinbox)

	var profile_label = Label.new()
	profile_label.text = "Tool Profile"
	content.add_child(profile_label)

	_profile_button = OptionButton.new()
	_profile_button.add_item("core")
	_profile_button.add_item("full")
	_profile_button.item_selected.connect(_on_profile_selected)
	content.add_child(_profile_button)

	_debug_checkbox = CheckBox.new()
	_debug_checkbox.text = "Debug Logging"
	_debug_checkbox.tooltip_text = "Print MCP activity to the Godot output panel."
	_debug_checkbox.toggled.connect(_on_debug_logging_toggled)
	content.add_child(_debug_checkbox)

	_execute_safety_checkbox = CheckBox.new()
	_execute_safety_checkbox.text = "execute_code Safety Checks"
	_execute_safety_checkbox.tooltip_text = "Block common dangerous filesystem, process, and project-setting snippets by default. Tool calls can still override with safety_checks=false."
	_execute_safety_checkbox.toggled.connect(_on_execute_safety_toggled)
	content.add_child(_execute_safety_checkbox)

	var map_row = HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 6)
	content.add_child(map_row)

	var open_map_button = Button.new()
	open_map_button.text = "Open Project Map"
	open_map_button.tooltip_text = "Generate a read-only HTML project visualizer from map_project and open it in the browser."
	open_map_button.pressed.connect(_open_project_map)
	map_row.add_child(open_map_button)

	_map_status_label = Label.new()
	_map_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_row.add_child(_map_status_label)

	var exposure_header = HBoxContainer.new()
	exposure_header.add_theme_constant_override("separation", 6)
	content.add_child(exposure_header)

	_tool_exposure_label = Label.new()
	_tool_exposure_label.text = "Tool Exposure"
	_tool_exposure_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exposure_header.add_child(_tool_exposure_label)

	var reset_tools_button = Button.new()
	reset_tools_button.text = "Reset"
	reset_tools_button.tooltip_text = "Expose every tool allowed by the current profile and project language."
	reset_tools_button.pressed.connect(_reset_tool_exposure)
	exposure_header.add_child(reset_tools_button)

	var tool_scroll = ScrollContainer.new()
	tool_scroll.custom_minimum_size = Vector2(0, 160)
	tool_scroll.size_flags_vertical = Control.SIZE_FILL
	content.add_child(tool_scroll)

	_tool_list = VBoxContainer.new()
	_tool_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_list.add_theme_constant_override("separation", 2)
	tool_scroll.add_child(_tool_list)

	var client_label = Label.new()
	client_label.text = "Client Config Snippet"
	content.add_child(client_label)

	_client_button = OptionButton.new()
	for client_name in ["Codex", "Claude Code", "Cursor", "VS Code"]:
		_client_button.add_item(client_name)
	_client_button.select(0)
	_client_button.item_selected.connect(_on_client_selected)
	content.add_child(_client_button)

	var action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	content.add_child(action_row)

	var copy_button = Button.new()
	copy_button.text = "Copy Snippet"
	copy_button.pressed.connect(_copy_snippet)
	action_row.add_child(copy_button)

	var configure_button = Button.new()
	configure_button.text = "Configure"
	configure_button.pressed.connect(_configure_client)
	action_row.add_child(configure_button)

	var configure_skills_button = Button.new()
	configure_skills_button.text = "Configure + Skills"
	configure_skills_button.tooltip_text = "Write the selected MCP client config and generate project skill files."
	configure_skills_button.pressed.connect(_configure_client_with_skills)
	action_row.add_child(configure_skills_button)

	_copy_status_label = Label.new()
	content.add_child(_copy_status_label)

	_config_status_label = Label.new()
	content.add_child(_config_status_label)

	_config_path_label = Label.new()
	_config_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_config_path_label)

	_skill_status_label = Label.new()
	_skill_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_skill_status_label)

	_snippet_text = TextEdit.new()
	_snippet_text.custom_minimum_size = Vector2(0, 130)
	_snippet_text.editable = false
	_snippet_text.size_flags_vertical = Control.SIZE_FILL
	content.add_child(_snippet_text)

	var log_label = Label.new()
	log_label.text = "Recent Activity"
	content.add_child(log_label)

	_log_text = TextEdit.new()
	_log_text.custom_minimum_size = Vector2(0, 180)
	_log_text.editable = false
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_log_text)


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
	var value: String = "core" if index == 0 else "full"
	_settings.update_tool_profile(value)
	_last_tool_exposure_signature = ""
	if _server.is_running():
		_server.restart()
	refresh_live_state(true)


func _on_debug_logging_toggled(pressed: bool) -> void:
	_settings.update_debug_logging_enabled(pressed)
	refresh_live_state(true)


func _on_execute_safety_toggled(pressed: bool) -> void:
	_settings.update_execute_code_safety_checks_enabled(pressed)
	refresh_live_state(true)


func _on_client_selected(_index: int) -> void:
	refresh_live_state(true)


func _copy_snippet() -> void:
	DisplayServer.clipboard_set(_snippet_text.text)
	_copy_status_label.text = "Copied to clipboard."


func _configure_client() -> void:
	var target: Dictionary = _get_selected_target()
	var result: Dictionary = _client_config_writer.configure_target(target)
	_copy_status_label.text = result.get("message", "")
	refresh_live_state(true)


func _configure_client_with_skills() -> void:
	var target: Dictionary = _get_selected_target()
	var config_result: Dictionary = _client_config_writer.configure_target(target)
	var skill_result: Dictionary = _skill_manager.generate_project_skills(_get_endpoint(), _settings, _tool_registry)
	var messages: Array[String] = []
	messages.append(str(config_result.get("message", "")))
	messages.append(str(skill_result.get("message", "")))
	_copy_status_label.text = "\n".join(messages)
	refresh_live_state(true)


func _reset_tool_exposure() -> void:
	_settings.clear_disabled_tools()
	_last_tool_exposure_signature = ""
	refresh_live_state(true)


func _check_for_updates() -> void:
	_update_checker.check_for_updates()
	_refresh_update_state()


func _open_latest_release() -> void:
	_update_checker.open_latest_release()


func _open_project_map() -> void:
	if _tool_registry == null:
		_map_status_label.text = "Project map unavailable."
		return
	var html: String = _tool_registry.call_tool("map_project", {
		"format": "html",
		"max_files": 500,
		"max_script_members": 120,
	})
	if html.begins_with("Error:"):
		_map_status_label.text = html
		return
	var output_path: String = "user://funplay_mcp_project_map.html"
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		_map_status_label.text = "Failed to write project map."
		return
	file.store_string(html)
	var global_path: String = ProjectSettings.globalize_path(output_path)
	OS.shell_open(global_path)
	_map_status_label.text = "Opened %s" % global_path


func _on_update_state_changed() -> void:
	_refresh_update_state()


func _on_tool_toggled(pressed: bool, tool_name: String) -> void:
	if _updating_tool_checks:
		return
	_settings.update_tool_disabled(tool_name, not pressed)
	_last_tool_exposure_signature = ""
	refresh_live_state(true)


func _build_client_snippet(client_name: String) -> String:
	var target: Dictionary = _get_selected_target()
	return _client_config_writer.build_snippet(target)


func _build_log_text() -> String:
	var log_entries: Array = _server.get_interaction_log()
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
	var targets: Array = _client_config_writer.list_targets(_get_endpoint(), _settings.server_auth_token)
	var selected_name: String = _client_button.get_item_text(_client_button.selected)
	for target in targets:
		if str(target.get("name", "")) == selected_name:
			return target
	return targets[0] if not targets.is_empty() else {}


func _refresh_config_status() -> void:
	if _config_status_label == null or _config_path_label == null or _client_config_writer == null:
		return

	var target: Dictionary = _get_selected_target()
	if target.is_empty():
		_set_label_text(_config_status_label, "Config status: unavailable")
		_set_label_text(_config_path_label, "")
		return

	var exists: bool = _client_config_writer.target_exists(target)
	_set_label_text(_config_status_label, "Config status: Configured" if exists else "Config status: Not configured")
	_set_label_text(_config_path_label, str(target.get("path", "")))


func _refresh_skill_status() -> void:
	if _skill_status_label == null:
		return

	var status: Dictionary = _skill_manager.get_status()
	if bool(status.get("skill_exists", false)):
		_set_label_text(_skill_status_label, "Project skills: Generated at %s" % str(status.get("skill_path", "")))
	else:
		_set_label_text(_skill_status_label, "Project skills: Not generated")


func _refresh_update_state() -> void:
	if _version_label == null or _update_status_label == null:
		return

	var state: Dictionary = _update_checker.get_state()
	_set_label_text(_version_label, "v%s" % str(state.get("current_version", "0.0.0")))
	_set_label_text(_update_status_label, str(state.get("status_message", "Updates: Not checked")))
	_check_updates_button.disabled = bool(state.get("is_checking", false))
	_check_updates_button.text = "Checking..." if bool(state.get("is_checking", false)) else "Check Updates"
	_open_release_button.disabled = bool(state.get("is_checking", false))


func _refresh_tool_exposure(force: bool) -> void:
	if _tool_registry == null or _tool_list == null:
		return

	var summary: Dictionary = _tool_registry.get_exposure_summary(_settings.tool_profile)
	var signature = "%s:%s" % [
		str(summary.get("profile", "")),
		str(summary.get("language_mode", "")) + ":" + ",".join(_settings.disabled_tools),
	]
	if not force and signature == _last_tool_exposure_signature:
		_update_tool_exposure_label(summary)
		return
	_last_tool_exposure_signature = signature

	_update_tool_exposure_label(summary)
	_updating_tool_checks = true
	for child in _tool_list.get_children():
		_tool_list.remove_child(child)
		child.queue_free()

	for tool in summary.get("tools", []):
		if not (tool is Dictionary):
			continue
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_tool_list.add_child(row)

		var checkbox = CheckBox.new()
		var tool_name: String = str(tool.get("name", ""))
		checkbox.text = tool_name
		checkbox.tooltip_text = str(tool.get("description", ""))
		checkbox.button_pressed = bool(tool.get("exposed", false))
		checkbox.disabled = not bool(tool.get("language_allowed", true))
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		checkbox.toggled.connect(_on_tool_toggled.bind(tool_name))
		row.add_child(checkbox)

		if bool(tool.get("disabled", false)):
			var badge = Label.new()
			badge.text = "disabled"
			row.add_child(badge)
		elif not bool(tool.get("language_allowed", true)):
			var language_badge = Label.new()
			language_badge.text = "language"
			row.add_child(language_badge)
	_updating_tool_checks = false


func _update_tool_exposure_label(summary: Dictionary) -> void:
	if _tool_exposure_label == null:
		return
	_set_label_text(_tool_exposure_label, "Tool Exposure: %d/%d exposed" % [
		int(summary.get("exposed", 0)),
		int(summary.get("total_in_profile", 0)),
	])


func _get_endpoint() -> String:
	return _server.get_endpoint() if _server.is_running() else "http://127.0.0.1:%d/" % _settings.server_port


func _refresh_when_visible() -> void:
	if _needs_refresh_when_visible or _is_active_dock_tab():
		refresh_live_state(true)


func _is_active_dock_tab() -> bool:
	if not is_inside_tree():
		return false

	var current: Node = self
	var parent: Node = get_parent()
	while parent != null:
		if parent is TabContainer:
			var tab_container: TabContainer = parent
			var current_tab: int = tab_container.current_tab
			return current_tab >= 0 and current_tab < tab_container.get_child_count() and tab_container.get_child(current_tab) == current
		current = parent
		parent = parent.get_parent()
	return is_visible_in_tree()


func _set_label_text(label: Label, value: String) -> void:
	if label != null and label.text != value:
		label.text = value


func _set_text_edit_text(text_edit: TextEdit, value: String) -> void:
	if text_edit != null and text_edit.text != value:
		text_edit.text = value


func _set_checkbox_pressed(checkbox: CheckBox, pressed: bool) -> void:
	if checkbox != null and checkbox.button_pressed != pressed:
		checkbox.set_pressed_no_signal(pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _is_active_dock_tab():
		refresh_live_state(true)
	elif what == NOTIFICATION_PREDELETE and _update_checker != null:
		_update_checker.teardown()
