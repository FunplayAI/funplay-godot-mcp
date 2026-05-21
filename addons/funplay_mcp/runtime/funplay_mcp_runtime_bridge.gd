extends Node

const STATE_PATH = "user://funplay_mcp_runtime_bridge.json"
const WRITE_INTERVAL_SEC = 0.5

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
	return {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"scene_file_path": node.scene_file_path,
	}


func _vector2_to_dict(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
	}
