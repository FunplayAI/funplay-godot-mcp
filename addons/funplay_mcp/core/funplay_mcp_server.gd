@tool
extends RefCounted

const FunplayHttpTransport = preload("res://addons/funplay_mcp/core/funplay_http_transport.gd")
const FunplayMcpRequestHandler = preload("res://addons/funplay_mcp/core/funplay_mcp_request_handler.gd")

const SERVER_NAME = "Funplay MCP Server - Godot"
const SERVER_VERSION = "0.9.2"
const DEFAULT_PORT = 8765
const MAX_LOG_ENTRIES = 50

var _plugin
var _settings
var _tool_registry
var _resource_provider
var _prompt_provider
var _transport
var _request_handler
var _interaction_log: Array = []
var _is_running: bool = false
var _attached_to_existing: bool = false
var _port: int = DEFAULT_PORT


func _init(plugin, settings, tool_registry, resource_provider, prompt_provider) -> void:
	_plugin = plugin
	_settings = settings
	_tool_registry = tool_registry
	_resource_provider = resource_provider
	_prompt_provider = prompt_provider
	_transport = FunplayHttpTransport.new()
	_request_handler = FunplayMcpRequestHandler.new(
		_settings,
		_tool_registry,
		_resource_provider,
		_prompt_provider,
		SERVER_NAME,
		SERVER_VERSION,
		Callable(self, "add_interaction"),
	)
	_resource_provider.set_interaction_log_getter(Callable(self, "get_interaction_log"))


func start() -> Dictionary:
	if _is_running:
		return {"ok": true, "message": "Server is already running."}

	var configured_port: int = _settings.server_port if _settings.server_port > 0 else DEFAULT_PORT
	if not _is_port_available(configured_port):
		var probe: Dictionary = _probe_existing_server(configured_port)
		if _is_matching_project_server(probe):
			_is_running = true
			_attached_to_existing = true
			_port = configured_port
			add_interaction("server", "success", "Attached to existing MCP server on %s" % get_endpoint())
			return {"ok": true, "message": "Attached to existing MCP server on %s" % get_endpoint(), "attached": true}
		if not probe.is_empty() and str(probe.get("name", "")) == SERVER_NAME:
			add_interaction("server", "warning", "Port %d is used by a different Funplay Godot MCP project; selecting a fallback port." % configured_port)

	var resolved_port: int = _resolve_startup_port(configured_port)
	var err: int = _transport.listen(resolved_port)
	if err != OK:
		_is_running = false
		_attached_to_existing = false
		return {"ok": false, "message": "Failed to start MCP server on port %d." % resolved_port}

	_is_running = true
	_attached_to_existing = false
	_port = resolved_port
	if _settings.server_port != resolved_port:
		_settings.server_port = resolved_port
		_settings.save_settings()

	add_interaction("server", "success", "Started MCP server on %s" % get_endpoint())
	return {"ok": true, "message": "Started MCP server on %s" % get_endpoint()}


func stop() -> void:
	if not _is_running:
		return

	if _attached_to_existing:
		_attached_to_existing = false
	else:
		_transport.stop()
	_is_running = false
	add_interaction("server", "success", "Stopped MCP server.")


func restart() -> Dictionary:
	stop()
	return start()


func poll() -> void:
	if not _is_running or _attached_to_existing:
		return
	_transport.poll(Callable(self, "_handle_http_request"))


func is_running() -> bool:
	return _is_running


func get_port() -> int:
	return _port


func get_endpoint() -> String:
	return "http://127.0.0.1:%d/" % _port


func is_attached_to_existing() -> bool:
	return _attached_to_existing


func get_interaction_log() -> Array:
	return _interaction_log.duplicate(true)


func add_interaction(name: String, status: String, message: String) -> void:
	var entry = {
		"timestamp": Time.get_datetime_string_from_system(true, true),
		"name": name,
		"status": status,
		"message": message,
	}
	_interaction_log.push_front(entry)
	if _interaction_log.size() > MAX_LOG_ENTRIES:
		_interaction_log.resize(MAX_LOG_ENTRIES)
	if _settings != null and _settings.debug_logging_enabled:
		print("[Funplay MCP] [%s] %s: %s" % [status, name, message])


func _handle_http_request(method: String, path: String, body_text: String, headers: Dictionary = {}) -> Dictionary:
	if method == "GET":
		if path == "/" or path == "/health":
			return {
				"status": 200,
				"content_type": "application/json",
				"body": JSON.stringify({
					"name": SERVER_NAME,
					"version": SERVER_VERSION,
					"endpoint": get_endpoint(),
					"tool_profile": _settings.tool_profile,
					"debug_logging_enabled": _settings.debug_logging_enabled,
					"execute_code_safety_checks_enabled": _settings.execute_code_safety_checks_enabled,
					"auth_required": str(_settings.server_auth_token).strip_edges() != "",
					"protocol_version": _request_handler.get_default_protocol_version(),
					"project_name": str(ProjectSettings.get_setting("application/config/name", "")),
					"project_identity": _project_identity_hash(),
					"attached_to_existing": _attached_to_existing,
				}),
			}
		return {
			"status": 404,
			"content_type": "text/plain",
			"body": "Not Found",
		}

	if method != "POST":
		return {
			"status": 405,
			"content_type": "text/plain",
			"body": "Method Not Allowed",
		}

	var security_response: Dictionary = _validate_post_request_security(headers)
	if not security_response.is_empty():
		return security_response

	var protocol_version: String = str(headers.get("mcp-protocol-version", "")).strip_edges()
	if protocol_version != "" and not _request_handler.is_protocol_version_supported(protocol_version):
		return {
			"status": 400,
			"content_type": "application/json",
			"body": JSON.stringify({
				"jsonrpc": "2.0",
				"id": null,
				"error": {
					"code": -32600,
					"message": "Unsupported MCP-Protocol-Version: %s" % protocol_version,
				},
			}),
		}

	var request = JSON.parse_string(body_text)
	if not (request is Dictionary):
		return {
			"status": 400,
			"content_type": "application/json",
			"body": JSON.stringify({
				"jsonrpc": "2.0",
				"id": null,
				"error": {
					"code": -32700,
					"message": "Parse error",
				},
			}),
		}

	var response = _request_handler.handle_request(request)
	if response == null:
		return {
			"status": 204,
			"content_type": "application/json",
			"body": "",
		}

	return {
		"status": 200,
		"content_type": "application/json",
		"body": JSON.stringify(response),
	}


func _resolve_startup_port(configured_port: int) -> int:
	var normalized: int = configured_port if configured_port > 0 else DEFAULT_PORT
	if _is_port_available(normalized):
		return normalized

	var fallback: int = DEFAULT_PORT + 1
	while fallback < DEFAULT_PORT + 100:
		if _is_port_available(fallback):
			return fallback
		fallback += 1

	return normalized


func _is_port_available(port: int) -> bool:
	var probe: TCPServer = TCPServer.new()
	var err: int = probe.listen(port, "127.0.0.1")
	if err == OK:
		probe.stop()
		return true
	return false


func _probe_existing_server(port: int) -> Dictionary:
	var peer: StreamPeerTCP = StreamPeerTCP.new()
	var err: int = peer.connect_to_host("127.0.0.1", port)
	if err != OK:
		return {}

	var deadline: int = Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < deadline:
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break
		if peer.get_status() == StreamPeerTCP.STATUS_ERROR:
			peer.disconnect_from_host()
			return {}
		OS.delay_msec(10)

	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		peer.disconnect_from_host()
		return {}

	var request_text: String = "GET /health HTTP/1.1\r\nHost: 127.0.0.1:%d\r\nConnection: close\r\n\r\n" % port
	peer.put_data(request_text.to_utf8_buffer())
	var response_text: String = ""
	deadline = Time.get_ticks_msec() + 500
	while Time.get_ticks_msec() < deadline:
		peer.poll()
		var available: int = peer.get_available_bytes()
		if available > 0:
			response_text += peer.get_utf8_string(available)
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED and available == 0:
			break
		OS.delay_msec(10)
	peer.disconnect_from_host()

	var body_start: int = response_text.find("\r\n\r\n")
	if body_start == -1:
		return {}
	var body_text: String = response_text.substr(body_start + 4).strip_edges()
	var parsed = JSON.parse_string(body_text)
	if parsed is Dictionary:
		return parsed
	return {}


func _is_matching_project_server(probe: Dictionary) -> bool:
	return str(probe.get("name", "")) == SERVER_NAME and str(probe.get("project_identity", "")) == _project_identity_hash()


func _project_identity_hash() -> String:
	var root: String = ProjectSettings.globalize_path("res://")
	return root.sha256_text().substr(0, 16)


func _validate_post_request_security(headers: Dictionary) -> Dictionary:
	var origin: String = str(headers.get("origin", "")).strip_edges()
	if origin != "" and not _is_allowed_local_request_origin(origin):
		return _json_error_response(403, -32001, "Forbidden request origin.")

	var referer: String = str(headers.get("referer", "")).strip_edges()
	if referer != "" and not _is_allowed_local_request_origin(referer):
		return _json_error_response(403, -32001, "Forbidden request referer.")

	var expected_token: String = str(_settings.server_auth_token).strip_edges()
	if expected_token == "":
		return {}

	var provided_token: String = _extract_request_auth_token(headers)
	if provided_token == "" or provided_token != expected_token:
		return _json_error_response(401, -32001, "Missing or invalid Funplay MCP auth token.")

	return {}


func _extract_request_auth_token(headers: Dictionary) -> String:
	var token: String = str(headers.get("x-funplay-mcp-token", "")).strip_edges()
	if token != "":
		return token

	var authorization: String = str(headers.get("authorization", "")).strip_edges()
	if authorization.to_lower().begins_with("bearer "):
		return authorization.substr(7).strip_edges()
	return ""


func _is_allowed_local_request_origin(value: String) -> bool:
	var host: String = _extract_request_host(value)
	return host in ["127.0.0.1", "localhost", "::1"]


func _extract_request_host(value: String) -> String:
	var text: String = value.strip_edges()
	var scheme_index: int = text.find("://")
	if scheme_index != -1:
		text = text.substr(scheme_index + 3)

	var slash_index: int = text.find("/")
	if slash_index != -1:
		text = text.substr(0, slash_index)

	if text.contains("@"):
		var userinfo_parts: PackedStringArray = text.split("@", false)
		text = str(userinfo_parts[userinfo_parts.size() - 1])

	if text.begins_with("["):
		var close_index: int = text.find("]")
		if close_index != -1:
			return text.substr(1, close_index - 1).to_lower()

	var colon_index: int = text.find(":")
	if colon_index != -1:
		text = text.substr(0, colon_index)
	return text.to_lower()


func _json_error_response(status: int, code: int, message: String) -> Dictionary:
	return {
		"status": status,
		"content_type": "application/json",
		"body": JSON.stringify({
			"jsonrpc": "2.0",
			"id": null,
			"error": {
				"code": code,
				"message": message,
			},
		}),
	}
