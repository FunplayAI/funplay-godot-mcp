@tool
extends RefCounted


func list_targets(endpoint: String) -> Array:
	var home_path := _get_user_home_path()
	return [
		{
			"name": "Codex",
			"path": home_path.path_join(".codex/config.toml"),
			"type": "toml",
			"server_name": "funplay",
			"endpoint": endpoint,
		},
		{
			"name": "Claude Code",
			"path": home_path.path_join(".claude.json"),
			"type": "json",
			"root_key": "mcpServers",
			"include_type": true,
			"server_name": "funplay",
			"endpoint": endpoint,
		},
		{
			"name": "Cursor",
			"path": home_path.path_join(".cursor/mcp.json"),
			"type": "json",
			"root_key": "mcpServers",
			"include_type": false,
			"server_name": "funplay",
			"endpoint": endpoint,
		},
		{
			"name": "VS Code",
			"path": _get_vscode_config_path(home_path),
			"type": "json",
			"root_key": "servers",
			"include_type": true,
			"server_name": "funplay",
			"endpoint": endpoint,
		},
	]


func configure_target(target: Dictionary) -> Dictionary:
	var path := str(target.get("path", ""))
	if path == "":
		return {"ok": false, "message": "Missing config path."}

	var ensure_err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if ensure_err != OK:
		return {"ok": false, "message": "Failed to create config directory: %s" % path.get_base_dir()}

	var target_type := str(target.get("type", "json"))
	if target_type == "toml":
		return _configure_toml_target(target)
	return _configure_json_target(target)


func target_exists(target: Dictionary) -> bool:
	return FileAccess.file_exists(str(target.get("path", "")))


func build_snippet(target: Dictionary) -> String:
	var endpoint := str(target.get("endpoint", ""))
	var target_type := str(target.get("type", "json"))
	if target_type == "toml":
		return "[mcp_servers.funplay]\nurl = \"%s\"\n" % endpoint

	var root_key := str(target.get("root_key", "mcpServers"))
	var server_name := str(target.get("server_name", "funplay"))
	var entry := {
		"url": endpoint,
	}
	if bool(target.get("include_type", false)):
		entry["type"] = "http"

	var servers := {}
	servers[server_name] = entry
	var root := {}
	root[root_key] = servers
	return JSON.stringify(root, "\t")


func _configure_json_target(target: Dictionary) -> Dictionary:
	var path := str(target.get("path", ""))
	var root_key := str(target.get("root_key", "mcpServers"))
	var server_name := str(target.get("server_name", "funplay"))
	var entry := {
		"url": str(target.get("endpoint", "")),
	}
	if bool(target.get("include_type", false)):
		entry["type"] = "http"

	var root := {}
	if FileAccess.file_exists(path):
		var text := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			root = parsed

	var servers = root.get(root_key, {})
	if not (servers is Dictionary):
		servers = {}
	servers[server_name] = entry
	root[root_key] = servers

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Failed to open config for writing: %s" % path}
	file.store_string(JSON.stringify(root, "\t"))
	return {"ok": true, "message": "Configuration written to %s" % path}


func _configure_toml_target(target: Dictionary) -> Dictionary:
	var path := str(target.get("path", ""))
	var section_header := "[mcp_servers.%s]" % str(target.get("server_name", "funplay"))
	var section_text := "%s\nurl = \"%s\"\n" % [section_header, str(target.get("endpoint", ""))]
	var content := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

	if content.find(section_header) >= 0:
		var start_idx := content.find(section_header)
		var after_header := start_idx + section_header.length()
		var next_section := content.find("\n[", after_header)
		var end_idx := next_section if next_section >= 0 else content.length()
		content = content.substr(0, start_idx) + section_text + content.substr(end_idx)
	else:
		if content != "" and not content.ends_with("\n"):
			content += "\n"
		content += "\n" + section_text

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Failed to open config for writing: %s" % path}
	file.store_string(content)
	return {"ok": true, "message": "Configuration written to %s" % path}


func _get_user_home_path() -> String:
	var home_path := OS.get_environment("HOME")
	if home_path == "":
		home_path = OS.get_environment("USERPROFILE")
	if home_path != "":
		return home_path.simplify_path()

	var user_data_dir := OS.get_user_data_dir()
	match OS.get_name():
		"Windows":
			var app_data_marker := "/AppData/"
			var idx := user_data_dir.find(app_data_marker)
			if idx >= 0:
				return user_data_dir.substr(0, idx)
		"macOS":
			var mac_marker := "/Library/Application Support/"
			var mac_idx := user_data_dir.find(mac_marker)
			if mac_idx >= 0:
				return user_data_dir.substr(0, mac_idx)
		_:
			var linux_marker := "/.local/share/"
			var linux_idx := user_data_dir.find(linux_marker)
			if linux_idx >= 0:
				return user_data_dir.substr(0, linux_idx)

	return user_data_dir.get_base_dir()


func _get_vscode_config_path(home_path: String) -> String:
	match OS.get_name():
		"Windows":
			var app_data := OS.get_environment("APPDATA")
			if app_data != "":
				return app_data.path_join("Code/User/mcp.json")
			return home_path.path_join("AppData/Roaming/Code/User/mcp.json")
		"macOS":
			var primary_path := home_path.path_join("Library/Application Support/Code/User/mcp.json")
			if FileAccess.file_exists(primary_path) or DirAccess.dir_exists_absolute(primary_path.get_base_dir()):
				return primary_path
			return home_path.path_join(".vscode/mcp.json")
		_:
			return home_path.path_join(".config/Code/User/mcp.json")
