@tool
extends RefCounted

const SKILL_DIR = "res://.funplay/skills"
const PROJECT_SKILL_PATH = "res://.funplay/skills/funplay-godot-project.md"
const MANIFEST_PATH = "res://.funplay/skills/manifest.json"
const AGENTS_PATH = "res://AGENTS.md"
const AGENTS_BLOCK_BEGIN = "<!-- FUNPLAY_MCP_SKILL_BEGIN -->"
const AGENTS_BLOCK_END = "<!-- FUNPLAY_MCP_SKILL_END -->"


func get_status() -> Dictionary:
	return {
		"skill_exists": FileAccess.file_exists(PROJECT_SKILL_PATH),
		"skill_path": PROJECT_SKILL_PATH,
		"manifest_exists": FileAccess.file_exists(MANIFEST_PATH),
		"manifest_path": MANIFEST_PATH,
		"agents_bridge_exists": _agents_bridge_exists(),
		"agents_path": AGENTS_PATH,
	}


func generate_project_skills(endpoint: String, settings, tool_registry = null, include_agents_bridge: bool = true) -> Dictionary:
	var ensure_err: int = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SKILL_DIR))
	if ensure_err != OK:
		return {
			"ok": false,
			"message": "Failed to create project skills directory: %s" % SKILL_DIR,
			"error": ensure_err,
		}

	var skill_text: String = build_project_skill_markdown(endpoint, settings, tool_registry)
	var skill_err: int = _write_text(PROJECT_SKILL_PATH, skill_text)
	if skill_err != OK:
		return {
			"ok": false,
			"message": "Failed to write project skill: %s" % PROJECT_SKILL_PATH,
			"error": skill_err,
		}

	var manifest_err: int = _write_text(MANIFEST_PATH, JSON.stringify(_build_manifest(endpoint, settings, tool_registry), "\t") + "\n")
	if manifest_err != OK:
		return {
			"ok": false,
			"message": "Failed to write project skill manifest: %s" % MANIFEST_PATH,
			"error": manifest_err,
		}

	var touched_paths: Array[String] = [PROJECT_SKILL_PATH, MANIFEST_PATH]
	if include_agents_bridge:
		var bridge_err: int = _write_agents_bridge(endpoint)
		if bridge_err != OK:
			return {
				"ok": false,
				"message": "Generated project skill, but failed to update %s." % AGENTS_PATH,
				"error": bridge_err,
				"paths": touched_paths,
			}
		touched_paths.append(AGENTS_PATH)

	return {
		"ok": true,
		"message": "Project skills generated.",
		"paths": touched_paths,
	}


func build_project_skill_markdown(endpoint: String, settings, tool_registry = null) -> String:
	var project_name: String = str(ProjectSettings.get_setting("application/config/name", ""))
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var profile: String = settings.tool_profile if settings != null else "core"
	var debug_logging: bool = bool(settings.debug_logging_enabled) if settings != null else false
	var core_count: int = _tool_count(tool_registry, "core")
	var full_count: int = _tool_count(tool_registry, "full")

	var lines: Array[String] = []
	lines.append("# Funplay MCP for Godot Project Skill")
	lines.append("")
	lines.append("Use this project through the local Funplay MCP for Godot editor server.")
	lines.append("")
	lines.append("## Connection")
	lines.append("")
	lines.append("- Endpoint: `%s`" % endpoint)
	lines.append("- Active tool profile: `%s`" % profile)
	lines.append("- Debug logging: `%s`" % str(debug_logging))
	if core_count > 0 or full_count > 0:
		lines.append("- Tool counts: `%d` core, `%d` full" % [core_count, full_count])
	lines.append("")
	lines.append("## Project Context")
	lines.append("")
	lines.append("- Project name: `%s`" % project_name)
	lines.append("- Main scene: `%s`" % main_scene)
	lines.append("- Project root: `%s`" % ProjectSettings.globalize_path("res://"))
	lines.append("")
	lines.append("## Operating Rules")
	lines.append("")
	lines.append("- Start by reading `godot://project/context` or calling `get_project_info` before broad edits.")
	lines.append("- Prefer `execute_code` for multi-step editor orchestration, then use focused helper tools for common Godot operations.")
	lines.append("- Use returned `instance_id` values as short-lived node identifiers during one editor session; paths are better for persistent references.")
	lines.append("- Call `save_scene` after scene mutations that should persist.")
	lines.append("- Use `get_script_errors`, `validate_script`, logs, and play-mode tools before considering a task complete.")
	lines.append("- Keep generated project files under `res://` and avoid touching `res://addons/funplay_mcp/` unless updating the addon itself.")
	lines.append("")
	lines.append("## High-Value Resources")
	lines.append("")
	lines.append("- `godot://scene/current`")
	lines.append("- `godot://selection/current`")
	lines.append("- `godot://scripts/errors`")
	lines.append("- `godot://logs/recent`")
	lines.append("- `godot://interaction/history`")
	lines.append("")
	return "\n".join(lines)


func _build_manifest(endpoint: String, settings, tool_registry = null) -> Dictionary:
	return {
		"name": "funplay-godot-project",
		"version": 1,
		"endpoint": endpoint,
		"tool_profile": settings.tool_profile if settings != null else "core",
		"skill_path": PROJECT_SKILL_PATH,
		"agents_path": AGENTS_PATH,
		"core_tool_count": _tool_count(tool_registry, "core"),
		"full_tool_count": _tool_count(tool_registry, "full"),
		"generated_at": Time.get_datetime_string_from_system(true, true),
	}


func _write_agents_bridge(endpoint: String) -> int:
	var existing: String = FileAccess.get_file_as_string(AGENTS_PATH) if FileAccess.file_exists(AGENTS_PATH) else ""
	var block: String = "\n".join([
		AGENTS_BLOCK_BEGIN,
		"# Funplay MCP for Godot",
		"",
		"- Local MCP endpoint: `%s`" % endpoint,
		"- Project skill: `%s`" % PROJECT_SKILL_PATH,
		"- Start Godot editor with the Funplay MCP addon enabled before using these tools.",
		AGENTS_BLOCK_END,
	])

	var updated: String = existing
	var begin_idx: int = updated.find(AGENTS_BLOCK_BEGIN)
	var end_idx: int = updated.find(AGENTS_BLOCK_END)
	if begin_idx >= 0 and end_idx >= begin_idx:
		end_idx += AGENTS_BLOCK_END.length()
		updated = updated.substr(0, begin_idx) + block + updated.substr(end_idx)
	else:
		if updated.strip_edges() != "":
			updated = updated.rstrip("\n") + "\n\n"
		updated += block + "\n"

	return _write_text(AGENTS_PATH, updated)


func _write_text(path: String, content: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(content)
	return OK


func _tool_count(tool_registry, profile: String) -> int:
	if tool_registry == null or not tool_registry.has_method("get_tool_names"):
		return 0
	return tool_registry.get_tool_names(profile).size()


func _agents_bridge_exists() -> bool:
	if not FileAccess.file_exists(AGENTS_PATH):
		return false
	var text: String = FileAccess.get_file_as_string(AGENTS_PATH)
	return text.find(AGENTS_BLOCK_BEGIN) >= 0 and text.find(AGENTS_BLOCK_END) >= 0
