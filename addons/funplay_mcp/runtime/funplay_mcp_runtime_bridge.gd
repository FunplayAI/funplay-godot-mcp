extends Node

const STATE_PATH = "user://funplay_mcp_runtime_bridge.json"
const WRITE_INTERVAL_SEC = 0.5
const MAX_TREE_DEPTH = 6
const MAX_TREE_NODES = 200

var _elapsed: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_write_state("ready")


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < WRITE_INTERVAL_SEC:
		return
	_elapsed = 0.0
	_write_state("running")


func _exit_tree() -> void:
	_write_state("exit")


func _write_state(status: String) -> void:
	var tree: SceneTree = get_tree()
	var viewport: Viewport = get_viewport()
	var current_scene: Node = tree.current_scene if tree != null else null
	var tree_budget: Dictionary = {
		"remaining": MAX_TREE_NODES,
		"truncated": false,
	}
	var state: Dictionary = {
		"status": status,
		"timestamp": Time.get_datetime_string_from_system(true, true),
		"fps": Engine.get_frames_per_second(),
		"time_scale": Engine.time_scale,
		"paused": tree.paused if tree != null else false,
		"current_scene": _node_summary(current_scene),
		"node_count": _count_nodes(current_scene),
		"root_child_count": tree.root.get_child_count() if tree != null and tree.root != null else 0,
		"viewport_size": _vector2_to_dict(viewport.get_visible_rect().size) if viewport != null else null,
		"scene_tree": _serialize_node_tree(current_scene, 0, tree_budget),
		"scene_tree_truncated": bool(tree_budget.get("truncated", false)),
		"scene_tree_max_depth": MAX_TREE_DEPTH,
		"scene_tree_max_nodes": MAX_TREE_NODES,
	}

	var file: FileAccess = FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(state, "\t") + "\n")


func _count_nodes(node: Node) -> int:
	if node == null:
		return 0
	var total: int = 1
	for child in node.get_children():
		if child is Node:
			total += _count_nodes(child)
	return total


func _node_summary(node: Node):
	if node == null:
		return null
	var summary: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"scene_file_path": node.scene_file_path,
	}
	var script = node.get_script()
	if script is Resource:
		summary["script_path"] = script.resource_path
	var groups: Array = []
	for group_name in node.get_groups():
		groups.append(str(group_name))
	if groups.size() > 0:
		summary["groups"] = groups
	return summary


func _serialize_node_tree(node: Node, depth: int, budget: Dictionary):
	if node == null:
		return null
	if int(budget.get("remaining", 0)) <= 0:
		budget["truncated"] = true
		return null
	budget["remaining"] = int(budget.get("remaining", 0)) - 1

	var summary: Dictionary = _node_summary(node)
	summary["properties"] = _runtime_properties(node)
	summary["children"] = []
	if depth >= MAX_TREE_DEPTH:
		summary["children_truncated"] = node.get_child_count() > 0
		if node.get_child_count() > 0:
			budget["truncated"] = true
		return summary

	for child in node.get_children():
		if not (child is Node):
			continue
		if int(budget.get("remaining", 0)) <= 0:
			budget["truncated"] = true
			break
		var child_summary = _serialize_node_tree(child, depth + 1, budget)
		if child_summary != null:
			summary["children"].append(child_summary)
	return summary


func _runtime_properties(node: Node) -> Dictionary:
	var properties: Dictionary = {
		"process_mode": node.process_mode,
	}
	if node is CanvasItem:
		properties["visible"] = node.visible
	if node is Node2D:
		properties["position"] = _vector2_to_dict(node.position)
		properties["rotation_degrees"] = node.rotation_degrees
		properties["scale"] = _vector2_to_dict(node.scale)
	if node is Control:
		properties["size"] = _vector2_to_dict(node.size)
		properties["global_position"] = _vector2_to_dict(node.global_position)
		if node is Label:
			properties["text"] = node.text
		elif node is Button:
			properties["text"] = node.text
	if node is Node3D:
		properties["position"] = _vector3_to_dict(node.position)
		properties["rotation_degrees"] = _vector3_to_dict(node.rotation_degrees)
		properties["scale"] = _vector3_to_dict(node.scale)
	return properties


func _vector2_to_dict(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
	}


func _vector3_to_dict(value: Vector3) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
		"z": value.z,
	}
