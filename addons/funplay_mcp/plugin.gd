@tool
extends EditorPlugin

const FunplayMcpSettings = preload("res://addons/funplay_mcp/core/funplay_mcp_settings.gd")
const FunplayToolRegistry = preload("res://addons/funplay_mcp/core/funplay_tool_registry.gd")
const FunplayResourceProvider = preload("res://addons/funplay_mcp/core/funplay_resource_provider.gd")
const FunplayPromptProvider = preload("res://addons/funplay_mcp/core/funplay_prompt_provider.gd")
const FunplayMcpServer = preload("res://addons/funplay_mcp/core/funplay_mcp_server.gd")
const FunplayClientConfigWriter = preload("res://addons/funplay_mcp/core/funplay_client_config_writer.gd")
const FunplayMcpDock = preload("res://addons/funplay_mcp/ui/funplay_mcp_dock.gd")

var _settings
var _tool_registry
var _resource_provider
var _prompt_provider
var _server
var _dock
var _client_config_writer


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		return

	_settings = FunplayMcpSettings.new()
	_tool_registry = FunplayToolRegistry.new(self, _settings)
	_resource_provider = FunplayResourceProvider.new(self, _settings)
	_prompt_provider = FunplayPromptProvider.new(self, _settings)
	_server = FunplayMcpServer.new(self, _settings, _tool_registry, _resource_provider, _prompt_provider)
	_client_config_writer = FunplayClientConfigWriter.new()
	_dock = FunplayMcpDock.new()
	_dock.setup(_server, _settings, _client_config_writer)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)

	if _settings.server_enabled:
		_server.start()

	set_process(true)


func _exit_tree() -> void:
	set_process(false)

	if _server != null:
		_server.stop()

	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null

	_server = null
	_prompt_provider = null
	_resource_provider = null
	_tool_registry = null
	_client_config_writer = null
	_settings = null


func _process(_delta: float) -> void:
	if _server != null:
		_server.poll()

	if _dock != null:
		_dock.refresh_live_state()
