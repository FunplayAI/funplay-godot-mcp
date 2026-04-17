@tool
extends RefCounted

const FunplayHttpTransport = preload("res://addons/funplay_mcp/core/funplay_http_transport.gd")
const FunplayMcpRequestHandler = preload("res://addons/funplay_mcp/core/funplay_mcp_request_handler.gd")

const SERVER_NAME := "Funplay MCP Server - Godot"
const SERVER_VERSION := "0.4.0"
const DEFAULT_PORT := 8765
const MAX_LOG_ENTRIES := 50

var _plugin
var _settings
var _tool_registry
var _resource_provider
var _prompt_provider
var _transport
var _request_handler
var _interaction_log: Array = []
var _is_running := false
var _port := DEFAULT_PORT


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

	var resolved_port := _resolve_startup_port(_settings.server_port)
	var err := _transport.listen(resolved_port)
	if err != OK:
		_is_running = false
		return {"ok": false, "message": "Failed to start MCP server on port %d." % resolved_port}

	_is_running = true
	_port = resolved_port
	if _settings.server_port != resolved_port:
		_settings.server_port = resolved_port
		_settings.save_settings()

	add_interaction("server", "success", "Started MCP server on %s" % get_endpoint())
	return {"ok": true, "message": "Started MCP server on %s" % get_endpoint()}


func stop() -> void:
	if not _is_running:
		return

	_transport.stop()
	_is_running = false
	add_interaction("server", "success", "Stopped MCP server.")


func restart() -> Dictionary:
	stop()
	return start()


func poll() -> void:
	if not _is_running:
		return
	_transport.poll(Callable(self, "_handle_http_request"))


func is_running() -> bool:
	return _is_running


func get_port() -> int:
	return _port


func get_endpoint() -> String:
	return "http://127.0.0.1:%d/" % _port


func get_interaction_log() -> Array:
	return _interaction_log.duplicate(true)


func add_interaction(name: String, status: String, message: String) -> void:
	_interaction_log.push_front({
		"timestamp": Time.get_datetime_string_from_system(true, true),
		"name": name,
		"status": status,
		"message": message,
	})
	if _interaction_log.size() > MAX_LOG_ENTRIES:
		_interaction_log.resize(MAX_LOG_ENTRIES)


func _handle_http_request(method: String, path: String, body_text: String) -> Dictionary:
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
	var normalized := configured_port if configured_port > 0 else DEFAULT_PORT
	if _is_port_available(normalized):
		return normalized

	var fallback := DEFAULT_PORT + 1
	while fallback < DEFAULT_PORT + 100:
		if _is_port_available(fallback):
			return fallback
		fallback += 1

	return normalized


func _is_port_available(port: int) -> bool:
	var probe := TCPServer.new()
	var err := probe.listen(port, "127.0.0.1")
	if err == OK:
		probe.stop()
		return true
	return false
