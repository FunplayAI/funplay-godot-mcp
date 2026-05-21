@tool
extends RefCounted

const FunplayCoreTools = preload("res://addons/funplay_mcp/core/funplay_core_tools.gd")

var _plugin
var _settings
var _core_tools


func _init(plugin, settings) -> void:
	_plugin = plugin
	_settings = settings
	_core_tools = FunplayCoreTools.new(plugin, settings)


func list_prompts() -> Array:
	return [
		{
			"name": "scene_review",
			"description": "Summarize the current Godot scene, identify missing pieces, and suggest next edits.",
			"arguments": [],
		},
		{
			"name": "feature_plan",
			"description": "Plan the next implementation steps for a Godot feature goal.",
			"arguments": [
				{
					"name": "goal",
					"description": "Feature or change request.",
					"required": true,
				},
			],
		},
		{
			"name": "runtime_debug",
			"description": "Debug a Godot runtime issue using play-state, performance, and scene context.",
			"arguments": [
				{
					"name": "issue",
					"description": "Observed runtime bug or symptom.",
					"required": true,
				},
			],
		},
		{
			"name": "script_patch",
			"description": "Plan a safe patch to an existing Godot script.",
			"arguments": [
				{
					"name": "path",
					"description": "Script path under res://.",
					"required": true,
				},
				{
					"name": "goal",
					"description": "Desired change.",
					"required": true,
				},
			],
		},
		{
			"name": "ui_layout_plan",
			"description": "Plan a Godot Control tree and layout strategy for a requested UI screen or HUD.",
			"arguments": [
				{
					"name": "goal",
					"description": "Desired HUD, menu, popup, or screen.",
					"required": true,
				},
			],
		},
		{
			"name": "architecture_advice",
			"description": "Review the project map and suggest scene, script, autoload, and resource architecture improvements.",
			"arguments": [
				{
					"name": "goal",
					"description": "Optional architecture goal or concern.",
					"required": false,
				},
			],
		},
		{
			"name": "performance_advice",
			"description": "Use project map, scene complexity, logs, and performance counters to suggest focused optimization work.",
			"arguments": [
				{
					"name": "issue",
					"description": "Optional performance symptom or target platform.",
					"required": false,
				},
			],
		},
		{
			"name": "network_template",
			"description": "Generate a Godot networking system template plan for multiplayer, WebSocket, HTTP, or relay-backed features.",
			"arguments": [
				{
					"name": "goal",
					"description": "Networking feature or gameplay requirement.",
					"required": true,
				},
			],
		},
		{
			"name": "template_generate",
			"description": "Generate an implementation template from the bundled UI, networking, performance, architecture, asset-pipeline, or update-safety template catalog.",
			"arguments": [
				{
					"name": "template",
					"description": "Template name: ui_screen, network_system, performance_review, architecture_review, asset_pipeline, or release_update_safety.",
					"required": true,
				},
				{
					"name": "goal",
					"description": "Optional project-specific goal.",
					"required": false,
				},
			],
		},
	]


func get_prompt(name: String, arguments: Dictionary) -> Dictionary:
	match name:
		"scene_review":
			return {
				"description": "Review the active Godot scene before making changes.",
				"messages": [{
					"role": "user",
					"content": {
						"type": "text",
						"text": "Review the current Godot scene, summarize its structure, identify obvious gaps, and suggest the safest next edits.\n\nScene snapshot:\n%s" % _core_tools.get_scene_tree({}),
					},
				}],
			}
		"feature_plan":
			var goal = str(arguments.get("goal", "")).strip_edges()
			return {
				"description": "Plan a Godot implementation in steps grounded in the current project context.",
				"messages": [{
					"role": "user",
					"content": {
						"type": "text",
						"text": "Goal: %s\n\nUse the current project context below, then produce a concrete Godot implementation plan with likely scene/script touch points.\n\nProject context:\n%s" % [goal, _core_tools.get_project_info({})],
					},
				}],
			}
		"runtime_debug":
			var issue = str(arguments.get("issue", "")).strip_edges()
			return {
				"description": "Debug a Godot runtime problem using current editor signals.",
				"messages": [{
					"role": "user",
					"content": {
						"type": "text",
						"text": "Issue: %s\n\nUse the current play-state, performance snapshot, recent logs, script error summary, scene structure, and selection context to propose a concrete debugging workflow and likely root causes.\n\nPlay state:\n%s\n\nPerformance:\n%s\n\nRecent logs:\n%s\n\nScript errors:\n%s\n\nScene:\n%s" % [
							issue,
							_core_tools.get_play_state({}),
							_core_tools.get_performance_snapshot({}),
							_core_tools.get_console_logs({"max_lines": 120}),
							_core_tools.get_script_errors({"max_files": 200}),
							_core_tools.get_scene_tree({}),
						],
					},
				}],
			}
		"script_patch":
			var path = str(arguments.get("path", "")).strip_edges()
			var goal_text = str(arguments.get("goal", "")).strip_edges()
			return {
				"description": "Patch a Godot script with current file context.",
				"messages": [{
					"role": "user",
					"content": {
						"type": "text",
						"text": "Patch the script at %s for this goal: %s\n\nCurrent file contents:\n%s" % [
							path,
							goal_text,
							_core_tools.read_file({"path": path, "max_chars": 30000}),
						],
					},
					}],
				}
		"ui_layout_plan":
			var ui_goal = str(arguments.get("goal", "")).strip_edges()
			return {
				"description": "Plan a Godot UI hierarchy and layout approach.",
				"messages": [{
					"role": "user",
					"content": {
						"type": "text",
						"text": "Goal: %s\n\nUsing the current scene context, propose a Godot UI hierarchy using CanvasLayer, Control, containers, labels, buttons, panels, and texture rects. Include anchor/layout suggestions and likely tool calls.\n\nScene snapshot:\n%s" % [
							ui_goal,
							_core_tools.get_scene_tree({}),
						],
					},
				}],
			}
		"architecture_advice":
			var architecture_goal = str(arguments.get("goal", "")).strip_edges()
			return {
				"description": "Review project architecture using the lightweight project map.",
				"messages": [{
					"role": "user",
					"content": {
						"type": "text",
						"text": "Architecture goal or concern: %s\n\nUse the project map below to identify high-impact architecture improvements. Focus on scene boundaries, script ownership, autoloads, resource dependencies, naming, and safe migration steps.\n\nProject map:\n%s\n\nProject features:\n%s" % [
							architecture_goal if architecture_goal != "" else "General architecture review",
							_core_tools.map_project({"format": "json", "max_files": 220, "max_script_members": 40}),
							_core_tools.list_project_features({}),
						],
					},
				}],
			}
		"performance_advice":
			var performance_issue = str(arguments.get("issue", "")).strip_edges()
			return {
				"description": "Suggest focused Godot performance improvements from current evidence.",
				"messages": [{
					"role": "user",
					"content": {
						"type": "text",
						"text": "Performance target or symptom: %s\n\nUse the current map, scene complexity, performance counters, logs, and script errors to propose prioritized optimizations. Separate confirmed evidence from hypotheses.\n\nProject map:\n%s\n\nScene complexity:\n%s\n\nPerformance:\n%s\n\nLogs:\n%s\n\nScript errors:\n%s" % [
							performance_issue if performance_issue != "" else "General performance review",
							_core_tools.map_project({"format": "json", "max_files": 160, "max_script_members": 30}),
							_core_tools.analyze_scene_complexity({}),
							_core_tools.get_performance_snapshot({}),
							_core_tools.get_console_logs({"max_lines": 120}),
							_core_tools.get_script_errors({"max_files": 200}),
						],
					},
				}],
			}
		"network_template":
			var network_goal = str(arguments.get("goal", "")).strip_edges()
			return {
				"description": "Generate a Godot networking implementation template.",
				"messages": [{
					"role": "user",
					"content": {
						"type": "text",
						"text": "Networking goal: %s\n\nGenerate a Godot-ready networking template plan. Include recommended nodes/autoloads, script responsibilities, message schemas, connection lifecycle, error handling, editor test steps, and minimal code skeletons when useful. Ground the plan in this project context:\n%s" % [
							network_goal,
							_core_tools.map_project({"format": "json", "max_files": 160, "max_script_members": 30}),
						],
					},
				}],
			}
		"template_generate":
			var template_name = str(arguments.get("template", "")).strip_edges().to_lower()
			var template_goal = str(arguments.get("goal", "")).strip_edges()
			return {
				"description": "Generate a project-specific implementation template.",
				"messages": [{
					"role": "user",
					"content": {
						"type": "text",
						"text": "Template: %s\nGoal: %s\n\nUse one of these template families: ui_screen, network_system, performance_review, architecture_review, asset_pipeline, release_update_safety. Generate a concrete Godot implementation template with files, scene nodes, tool calls, validation checks, and rollback notes.\n\nProject map:\n%s" % [
							template_name,
							template_goal if template_goal != "" else "No extra goal provided",
							_core_tools.map_project({"format": "json", "max_files": 180, "max_script_members": 30}),
						],
					},
				}],
			}
		_:
			return {
				"description": "Unknown prompt.",
				"messages": [{
					"role": "user",
					"content": {
						"type": "text",
						"text": "Unknown prompt: %s" % name,
					},
				}],
			}
