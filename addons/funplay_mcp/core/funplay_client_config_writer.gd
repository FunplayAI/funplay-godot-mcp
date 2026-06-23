@tool
extends RefCounted

const WRAPPER_PACKAGE = "funplay-godot-mcp@0.9.4"


func list_targets(endpoint: String, auth_token: String = "") -> Array:
	var home_path = _get_user_home_path()
	return [
		{
			"name": "Codex",
			"path": home_path.path_join(".codex/config.toml"),
			"type": "toml",
			"server_name": "funplay",
			"endpoint": endpoint,
			"auth_token": auth_token,
		},
		{
			"name": "Claude Code",
			"path": home_path.path_join(".claude.json"),
			"type": "json",
			"root_key": "mcpServers",
			"include_type": true,
			"server_name": "funplay",
			"endpoint": endpoint,
			"auth_token": auth_token,
		},
		{
			"name": "Cursor",
			"path": home_path.path_join(".cursor/mcp.json"),
			"type": "json",
			"root_key": "mcpServers",
			"include_type": false,
			"server_name": "funplay",
			"endpoint": endpoint,
			"auth_token": auth_token,
		},
		{
			"name": "VS Code",
			"path": _get_vscode_config_path(home_path),
			"type": "json",
			"root_key": "servers",
			"include_type": true,
			"server_name": "funplay",
			"endpoint": endpoint,
			"auth_token": auth_token,
		},
	]


func configure_target(target: Dictionary) -> Dictionary:
	var path = str(target.get("path", ""))
	if path == "":
		return {"ok": false, "message": "Missing config path."}

	var ensure_err = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if ensure_err != OK:
		return {"ok": false, "message": "Failed to create config directory: %s" % path.get_base_dir()}

	var target_type = str(target.get("type", "json"))
	if target_type == "toml":
		return _configure_toml_target(target)
	return _configure_json_target(target)


func target_exists(target: Dictionary) -> bool:
	return FileAccess.file_exists(str(target.get("path", "")))


func build_snippet(target: Dictionary) -> String:
	var target_type = str(target.get("type", "json"))
	if target_type == "toml":
		return _build_toml_section(target)

	var root_key = str(target.get("root_key", "mcpServers"))
	var server_name = str(target.get("server_name", "funplay"))
	var entry = _build_stdio_entry(target)

	var servers = {}
	servers[server_name] = entry
	var root = {}
	root[root_key] = servers
	return JSON.stringify(root, "\t")


func _configure_json_target(target: Dictionary) -> Dictionary:
	var path = str(target.get("path", ""))
	var root_key = str(target.get("root_key", "mcpServers"))
	var server_name = str(target.get("server_name", "funplay"))
	var entry = _build_stdio_entry(target)

	var root = {}
	if FileAccess.file_exists(path):
		var text = FileAccess.get_file_as_string(path)
		if text.strip_edges() != "":
			var parser = JSON.new()
			var parse_err = parser.parse(text)
			if parse_err != OK:
				return {
					"ok": false,
					"message": "Config JSON is invalid and was not modified: %s (line %d: %s)" % [
						path,
						parser.get_error_line(),
						parser.get_error_message(),
					],
				}
			if not (parser.data is Dictionary):
				return {
					"ok": false,
					"message": "Config JSON root must be an object and was not modified: %s" % path,
				}
			root = parser.data

	var servers = root.get(root_key, {})
	if not (servers is Dictionary):
		servers = {}
	servers[server_name] = entry
	root[root_key] = servers

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Failed to open config for writing: %s" % path}
	file.store_string(JSON.stringify(root, "\t") + "\n")
	return {"ok": true, "message": "Configuration written to %s" % path}


func _configure_toml_target(target: Dictionary) -> Dictionary:
	var path = str(target.get("path", ""))
	var section_header = "[mcp_servers.%s]" % str(target.get("server_name", "funplay"))
	var section_text = _build_toml_section(target)
	var content = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

	if content.find(section_header) >= 0:
		var start_idx = content.find(section_header)
		var after_header = start_idx + section_header.length()
		var next_section = _find_toml_section_end(content, after_header, str(target.get("server_name", "funplay")))
		var end_idx = next_section if next_section >= 0 else content.length()
		content = content.substr(0, start_idx) + section_text + content.substr(end_idx)
	else:
		if content != "" and not content.ends_with("\n"):
			content += "\n"
		if content != "":
			content += "\n"
		content += section_text

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Failed to open config for writing: %s" % path}
	file.store_string(content)
	return {"ok": true, "message": "Configuration written to %s" % path}


func _build_stdio_entry(target: Dictionary) -> Dictionary:
	var entry = {
		"command": "npx",
		"args": ["-y", WRAPPER_PACKAGE],
		"env": _build_wrapper_env(target),
	}
	if bool(target.get("include_type", false)):
		entry["type"] = "stdio"
	return entry


func _build_wrapper_env(target: Dictionary) -> Dictionary:
	var wrapper_env = {
		"FUNPLAY_GODOT_MCP_URL": str(target.get("endpoint", "")),
	}
	var auth_token: String = str(target.get("auth_token", "")).strip_edges()
	if auth_token != "":
		wrapper_env["FUNPLAY_GODOT_MCP_TOKEN"] = auth_token
	return wrapper_env


func _build_toml_section(target: Dictionary) -> String:
	var server_name: String = str(target.get("server_name", "funplay"))
	var lines: Array[String] = [
		"[mcp_servers.%s]" % server_name,
		"command = \"npx\"",
		"args = [\"-y\", %s]" % _toml_quote(WRAPPER_PACKAGE),
		"",
		"[mcp_servers.%s.env]" % server_name,
		"FUNPLAY_GODOT_MCP_URL = %s" % _toml_quote(str(target.get("endpoint", ""))),
	]
	var auth_token: String = str(target.get("auth_token", "")).strip_edges()
	if auth_token != "":
		lines.append("FUNPLAY_GODOT_MCP_TOKEN = %s" % _toml_quote(auth_token))
	return "\n".join(lines) + "\n"


func _find_toml_section_end(content: String, after_header: int, server_name: String) -> int:
	var nested_prefix: String = "[mcp_servers.%s." % server_name
	var search_from: int = after_header
	while true:
		var section_index: int = content.find("\n[", search_from)
		if section_index == -1:
			return content.length()
		var line_start: int = section_index + 1
		var line_end: int = content.find("\n", line_start + 1)
		if line_end == -1:
			line_end = content.length()
		var header_line: String = content.substr(line_start, line_end - line_start).strip_edges()
		if header_line.begins_with(nested_prefix):
			search_from = line_end
			continue
		return section_index
	return content.length()


func _toml_quote(value: String) -> String:
	return "\"%s\"" % value.replace("\\", "\\\\").replace("\"", "\\\"")


func _get_user_home_path() -> String:
	var home_path = OS.get_environment("HOME")
	if home_path == "":
		home_path = OS.get_environment("USERPROFILE")
	if home_path != "":
		return home_path.simplify_path()

	var user_data_dir = OS.get_user_data_dir()
	match OS.get_name():
		"Windows":
			var app_data_marker = "/AppData/"
			var idx = user_data_dir.find(app_data_marker)
			if idx >= 0:
				return user_data_dir.substr(0, idx)
		"macOS":
			var mac_marker = "/Library/Application Support/"
			var mac_idx = user_data_dir.find(mac_marker)
			if mac_idx >= 0:
				return user_data_dir.substr(0, mac_idx)
		_:
			var linux_marker = "/.local/share/"
			var linux_idx = user_data_dir.find(linux_marker)
			if linux_idx >= 0:
				return user_data_dir.substr(0, linux_idx)

	return user_data_dir.get_base_dir()


func _get_vscode_config_path(home_path: String) -> String:
	match OS.get_name():
		"Windows":
			var app_data = OS.get_environment("APPDATA")
			if app_data != "":
				return app_data.path_join("Code/User/mcp.json")
			return home_path.path_join("AppData/Roaming/Code/User/mcp.json")
		"macOS":
			var primary_path = home_path.path_join("Library/Application Support/Code/User/mcp.json")
			if FileAccess.file_exists(primary_path) or DirAccess.dir_exists_absolute(primary_path.get_base_dir()):
				return primary_path
			return home_path.path_join(".vscode/mcp.json")
		_:
			return home_path.path_join(".config/Code/User/mcp.json")
