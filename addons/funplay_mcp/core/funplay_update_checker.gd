@tool
extends RefCounted

signal state_changed

const LATEST_RELEASE_API_URL = "https://api.github.com/repos/FunplayAI/funplay-godot-mcp/releases/latest"
const DEFAULT_RELEASES_URL = "https://github.com/FunplayAI/funplay-godot-mcp/releases"
const PLUGIN_CFG_PATH = "res://addons/funplay_mcp/plugin.cfg"
const DEFAULT_VERSION = "0.0.0"

var _request: HTTPRequest
var _current_version: String = DEFAULT_VERSION
var _latest_version: String = ""
var _latest_release_url: String = DEFAULT_RELEASES_URL
var _latest_published_at: String = ""
var _status_message: String = "Updates: Not checked"
var _is_checking: bool = false
var _has_update: bool = false
var _last_checked_at: String = ""


func setup(owner: Node) -> void:
	if _request != null:
		return
	_current_version = _read_current_version()
	_request = HTTPRequest.new()
	_request.timeout = 15.0
	_request.max_redirects = 3
	owner.add_child(_request)
	_request.request_completed.connect(_on_request_completed)


func teardown() -> void:
	if _request != null and is_instance_valid(_request):
		_request.queue_free()
	_request = null


func get_state() -> Dictionary:
	return {
		"current_version": _current_version,
		"latest_version": _latest_version,
		"latest_release_url": _latest_release_url,
		"latest_published_at": _latest_published_at,
		"status_message": _status_message,
		"is_checking": _is_checking,
		"has_update": _has_update,
		"last_checked_at": _last_checked_at,
	}


func check_for_updates() -> Dictionary:
	if _request == null:
		return {"ok": false, "message": "Update checker is not initialized."}
	if _is_checking:
		return {"ok": true, "message": "Update check is already running."}

	_is_checking = true
	_status_message = "Updates: Checking GitHub..."
	state_changed.emit()

	var headers = PackedStringArray([
		"Accept: application/vnd.github+json",
		"User-Agent: Funplay-Godot-MCP",
	])
	var err: int = _request.request(LATEST_RELEASE_API_URL, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_is_checking = false
		_status_message = "Updates: Failed to start check (%s)" % error_string(err)
		state_changed.emit()
		return {"ok": false, "message": _status_message}

	return {"ok": true, "message": _status_message}


func open_latest_release() -> void:
	var url = _latest_release_url if _latest_release_url.strip_edges() != "" else DEFAULT_RELEASES_URL
	OS.shell_open(url)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_checking = false
	_last_checked_at = Time.get_datetime_string_from_system(true, true)

	if result != HTTPRequest.RESULT_SUCCESS:
		_status_message = "Updates: Check failed (%s)" % result
		state_changed.emit()
		return

	if response_code < 200 or response_code >= 300:
		_status_message = "Updates: GitHub returned HTTP %d" % response_code
		state_changed.emit()
		return

	var text: String = body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_status_message = "Updates: Invalid GitHub response"
		state_changed.emit()
		return

	_latest_version = _normalize_version(str(parsed.get("tag_name", "")))
	_latest_release_url = str(parsed.get("html_url", DEFAULT_RELEASES_URL))
	_latest_published_at = str(parsed.get("published_at", ""))

	if _latest_version == DEFAULT_VERSION:
		_status_message = "Updates: Latest release has no valid version"
		_has_update = false
	elif _compare_versions(_latest_version, _current_version) > 0:
		_has_update = true
		_status_message = "Updates: v%s available" % _latest_version
	elif _compare_versions(_latest_version, _current_version) == 0:
		_has_update = false
		_status_message = "Updates: Up to date (v%s)" % _current_version
	else:
		_has_update = false
		_status_message = "Updates: Local v%s is newer than latest v%s" % [_current_version, _latest_version]

	state_changed.emit()


func _read_current_version() -> String:
	var config = ConfigFile.new()
	var err: int = config.load(PLUGIN_CFG_PATH)
	if err != OK:
		return DEFAULT_VERSION
	return _normalize_version(str(config.get_value("plugin", "version", DEFAULT_VERSION)))


func _normalize_version(version: String) -> String:
	var normalized: String = version.strip_edges()
	while normalized.begins_with("v") or normalized.begins_with("V"):
		normalized = normalized.substr(1)
	return normalized if normalized != "" else DEFAULT_VERSION


func _compare_versions(left: String, right: String) -> int:
	var left_parts: Array = _parse_version(left)
	var right_parts: Array = _parse_version(right)
	for i in range(3):
		var left_value: int = int(left_parts[i])
		var right_value: int = int(right_parts[i])
		if left_value > right_value:
			return 1
		if left_value < right_value:
			return -1
	return 0


func _parse_version(version: String) -> Array:
	var base: String = _normalize_version(version).split("-", false, 1)[0]
	var raw_parts: PackedStringArray = base.split(".")
	var parts: Array[int] = [0, 0, 0]
	for i in range(min(3, raw_parts.size())):
		parts[i] = int(raw_parts[i]) if raw_parts[i].is_valid_int() else 0
	return parts
