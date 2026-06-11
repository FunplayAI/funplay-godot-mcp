@tool
extends RefCounted

const SUPPORTED_PROTOCOL_VERSIONS = [
	"2025-11-25",
	"2025-06-18",
	"2025-03-26",
	"2024-11-05",
]
const IMAGE_DATA_URI_PREFIX = "data:image/png;base64,"

var _settings
var _tool_registry
var _resource_provider
var _prompt_provider
var _server_name: String
var _server_version: String
var _interaction_logger: Callable


func _init(settings, tool_registry, resource_provider, prompt_provider, server_name: String, server_version: String, interaction_logger: Callable) -> void:
	_settings = settings
	_tool_registry = tool_registry
	_resource_provider = resource_provider
	_prompt_provider = prompt_provider
	_server_name = server_name
	_server_version = server_version
	_interaction_logger = interaction_logger


func handle_request(request: Dictionary) -> Variant:
	if request.is_empty():
		return _error_response(null, -32600, "Invalid Request")
	if str(request.get("jsonrpc", "")) != "2.0":
		return _error_response(request.get("id"), -32600, "Invalid Request: jsonrpc must be '2.0'")

	var method = str(request.get("method", ""))
	if method.strip_edges() == "":
		return _error_response(request.get("id"), -32600, "Invalid Request: method is required")

	var params = request.get("params", {})
	if not (params is Dictionary):
		params = {}

	match method:
		"initialize":
			return _handle_initialize(request, params)
		"notifications/initialized", "notifications/cancelled":
			return null
		"tools/list":
			return {
				"id": request.get("id"),
				"jsonrpc": "2.0",
				"result": {
					"tools": _tool_registry.list_tools(_settings.tool_profile),
				},
			}
		"tools/call":
			return _handle_tool_call(request, params)
		"resources/list":
			return {
				"id": request.get("id"),
				"jsonrpc": "2.0",
				"result": {
					"resources": _resource_provider.list_resources(),
				},
			}
		"resources/read":
			if str(params.get("uri", "")).strip_edges() == "":
				return _error_response(request.get("id"), -32602, "Invalid params: 'uri' is required")
			return {
				"id": request.get("id"),
				"jsonrpc": "2.0",
				"result": _resource_provider.read_resource(str(params.get("uri"))),
			}
		"resources/templates/list":
			return {
				"id": request.get("id"),
				"jsonrpc": "2.0",
				"result": {
					"resourceTemplates": _resource_provider.list_resource_templates(),
				},
			}
		"prompts/list":
			return {
				"id": request.get("id"),
				"jsonrpc": "2.0",
				"result": {
					"prompts": _prompt_provider.list_prompts(),
				},
			}
		"prompts/get":
			if str(params.get("name", "")).strip_edges() == "":
				return _error_response(request.get("id"), -32602, "Invalid params: 'name' is required")
			return {
				"id": request.get("id"),
				"jsonrpc": "2.0",
				"result": _prompt_provider.get_prompt(str(params.get("name")), params.get("arguments", {})),
			}
		_:
			if method.begins_with("notifications/"):
				return null
			return _error_response(request.get("id"), -32601, "Method not found: %s" % method)


func _handle_initialize(request: Dictionary, params: Dictionary) -> Dictionary:
	var requested = str(params.get("protocolVersion", "")).strip_edges()
	var negotiated = requested if requested in SUPPORTED_PROTOCOL_VERSIONS else SUPPORTED_PROTOCOL_VERSIONS[0]
	return {
		"id": request.get("id"),
		"jsonrpc": "2.0",
		"result": {
			"protocolVersion": negotiated,
			"serverInfo": {
				"name": _server_name,
				"version": _server_version,
				"projectName": str(ProjectSettings.get_setting("application/config/name", "")),
				"projectIdentity": _project_identity_hash(),
			},
			"capabilities": {
				"tools": {},
				"resources": {},
				"prompts": {},
			},
		},
	}


func _handle_tool_call(request: Dictionary, params: Dictionary) -> Dictionary:
	var tool_name = str(params.get("name", "")).strip_edges()
	if tool_name == "":
		return _error_response(request.get("id"), -32602, "Invalid params: 'name' is required")
	if not _tool_registry.has_tool(tool_name):
		return _error_response(request.get("id"), -32602, "Invalid params: unknown tool '%s'" % tool_name)
	if not _tool_registry.is_tool_allowed(tool_name, _settings.tool_profile):
		return _error_response(request.get("id"), -32602, "Invalid params: tool '%s' is not exposed by profile '%s'" % [tool_name, _settings.tool_profile])

	var arguments = params.get("arguments", {})
	if not (arguments is Dictionary):
		arguments = {}

	var result_text = _tool_registry.call_tool(tool_name, arguments)
	var structured_content: Dictionary = _build_structured_content(result_text)
	var status = "error" if _is_tool_error(result_text, structured_content) else "success"

	if _interaction_logger.is_valid():
		_interaction_logger.call(tool_name, status, result_text)

	var tool_result: Dictionary = {
		"id": request.get("id"),
		"jsonrpc": "2.0",
		"result": {
			"content": _build_content(result_text),
			"isError": status == "error",
		},
	}
	if not structured_content.is_empty():
		tool_result["result"]["structuredContent"] = structured_content
	return tool_result


func is_protocol_version_supported(version: String) -> bool:
	return version.strip_edges() in SUPPORTED_PROTOCOL_VERSIONS


func get_default_protocol_version() -> String:
	return SUPPORTED_PROTOCOL_VERSIONS[0]


func _project_identity_hash() -> String:
	var root: String = ProjectSettings.globalize_path("res://")
	return root.sha256_text().substr(0, 16)


func _error_response(request_id, code: int, message: String) -> Dictionary:
	return {
		"id": request_id,
		"jsonrpc": "2.0",
		"error": {
			"code": code,
			"message": message,
		},
	}


func _build_content(result_text: String) -> Array:
	if result_text.begins_with(IMAGE_DATA_URI_PREFIX):
		return [
			{
				"type": "image",
				"data": result_text.trim_prefix(IMAGE_DATA_URI_PREFIX),
				"mimeType": "image/png",
			},
			{
				"type": "text",
				"text": "Screenshot captured successfully.",
			},
		]

	return [{
		"type": "text",
		"text": result_text,
	}]


func _build_structured_content(result_text: String) -> Dictionary:
	if result_text.begins_with(IMAGE_DATA_URI_PREFIX):
		return {}
	var trimmed: String = result_text.strip_edges()
	if trimmed.begins_with("Error:"):
		return _legacy_error_structured_content(trimmed)
	if not (trimmed.begins_with("{") or trimmed.begins_with("[")):
		return {}
	var parsed = JSON.parse_string(trimmed)
	if parsed is Dictionary:
		return parsed
	if parsed is Array:
		return {"items": parsed}
	return {}


func _is_tool_error(result_text: String, structured_content: Dictionary) -> bool:
	if result_text.begins_with("Error:"):
		return true
	if structured_content.has("success") and not bool(structured_content.get("success")):
		return true
	if structured_content.has("isError") and bool(structured_content.get("isError")):
		return true
	return false


func _legacy_error_structured_content(message: String) -> Dictionary:
	return {
		"success": false,
		"code": "TOOL_ERROR",
		"error": message.trim_prefix("Error:").strip_edges(),
	}
