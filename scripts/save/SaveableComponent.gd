class_name SaveableComponent
extends Node

@export var unique_id: String = ""
@export var category: String = "entities"
@export var include_transform: bool = true
@export var scene_path_override: String = ""

var _component_state: Dictionary = {}


func _ready() -> void:
	if unique_id.is_empty():
		unique_id = _generate_default_id()
	if SaveManager != null:
		SaveManager.register_saveable(self)


func _exit_tree() -> void:
	if SaveManager != null:
		SaveManager.unregister_saveable(self)


func set_component_state_value(key: String, value: Variant) -> void:
	_component_state[key] = value


func get_save_entry() -> Dictionary:
	var target := _target_node()
	if target == null:
		return {}

	var entry: Dictionary = {
		"unique_id": unique_id,
		"category": category,
		"scene_path": _resolve_scene_path(target),
		"node_path": str(target.get_path()),
		"parent_path": str(target.get_parent().get_path()) if target.get_parent() != null else "",
		"state": _collect_state(target),
	}

	if include_transform:
		entry["transform"] = _serialize_transform(target)

	return entry


func load_from_entry(entry: Dictionary) -> void:
	var target := _target_node()
	if target == null:
		return

	if include_transform and entry.has("transform"):
		_apply_transform(target, _as_dictionary(entry.get("transform", {})))

	var state := _as_dictionary(entry.get("state", {}))
	_component_state = _as_dictionary(state.get("__component", {}))
	state.erase("__component")
	_apply_state(target, state)


func _target_node() -> Node:
	return get_parent()


func _collect_state(target: Node) -> Dictionary:
	var state: Dictionary = {}
	if target.has_method("save_state"):
		var output := target.call("save_state")
		if output is Dictionary:
			state = (output as Dictionary).duplicate(true)
	else:
		state = _collect_child_states(target)

	if not _component_state.is_empty():
		state["__component"] = _component_state.duplicate(true)

	return state


func _apply_state(target: Node, state: Dictionary) -> void:
	if target.has_method("load_state"):
		target.call("load_state", state)
		return

	_apply_child_states(target, state)


func _collect_child_states(target: Node) -> Dictionary:
	var child_states: Dictionary = {}
	for child in target.get_children():
		if not child.has_method("save_state"):
			continue
		var child_state := child.call("save_state")
		if child_state is Dictionary:
			child_states[str(child.name)] = (child_state as Dictionary).duplicate(true)
	return child_states


func _apply_child_states(target: Node, state: Dictionary) -> void:
	for key in state.keys():
		var child_name := str(key)
		var child := target.get_node_or_null(NodePath(child_name))
		if child == null:
			continue
		if not child.has_method("load_state"):
			continue
		var child_state := state.get(key, {})
		if child_state is Dictionary:
			child.call("load_state", child_state)


func _resolve_scene_path(target: Node) -> String:
	if not scene_path_override.is_empty():
		return scene_path_override
	return target.scene_file_path


func _serialize_transform(target: Node) -> Dictionary:
	if target is Node2D:
		var node2d := target as Node2D
		return {
			"type": "node2d",
			"position": {"x": node2d.global_position.x, "y": node2d.global_position.y},
			"rotation": node2d.rotation,
			"scale": {"x": node2d.scale.x, "y": node2d.scale.y},
		}

	return {}


func _apply_transform(target: Node, transform_data: Dictionary) -> void:
	if target is Node2D:
		var node2d := target as Node2D
		var position_data := _as_dictionary(transform_data.get("position", {}))
		var scale_data := _as_dictionary(transform_data.get("scale", {}))
		var loaded_position := Vector2(
			float(position_data.get("x", node2d.global_position.x)),
			float(position_data.get("y", node2d.global_position.y))
		)
		var loaded_scale := Vector2(
			float(scale_data.get("x", node2d.scale.x)),
			float(scale_data.get("y", node2d.scale.y))
		)
		node2d.global_position = loaded_position
		node2d.rotation = float(transform_data.get("rotation", node2d.rotation))
		node2d.scale = loaded_scale


func _generate_default_id() -> String:
	var target := _target_node()
	if target == null:
		return "saveable_%s" % str(get_instance_id())

	if target.has_method("get_saveable_id"):
		var target_id := str(target.call("get_saveable_id"))
		if not target_id.is_empty():
			return target_id

	var stable_path := str(target.get_path())
	if not stable_path.is_empty():
		return "%s::%s" % [str(target.name).to_snake_case(), stable_path]

	return "%s::unknown" % str(target.name).to_snake_case()


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
