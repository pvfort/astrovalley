extends Node

const CHARACTERS_ROOT := "user://characters"
const SAVE_FILE_NAME := "furniture.json"


func serialize_furniture(scene_path: String, position: Vector2, rotation: float, room_id: String) -> Dictionary:
	return {
		"scene": scene_path,
		"position": position,
		"rotation": rotation,
		"room_id": room_id
	}


func add_furniture(scene_path: String, position: Vector2, rotation: float = 0.0, room_id: String = "") -> void:
	if scene_path.is_empty():
		return

	var entries := load_furniture_state()
	entries.append(serialize_furniture(scene_path, position, rotation, room_id))
	save_furniture_state(entries)


func remove_furniture(scene_path: String, position: Vector2, room_id: String = "") -> void:
	var entries := load_furniture_state()
	for i in range(entries.size() - 1, -1, -1):
		var entry = entries[i]
		if str(entry.get("scene", "")) != scene_path:
			continue
		if room_id != "" and str(entry.get("room_id", "")) != room_id:
			continue

		var stored_position := _to_vector2(entry.get("position", Vector2.ZERO))
		if stored_position.distance_to(position) <= 0.1:
			entries.remove_at(i)
			break

	save_furniture_state(entries)


func load_room_furniture(parent: Node, room_id: String) -> void:
	if parent == null:
		return

	for child in parent.get_children():
		child.queue_free()

	var entries := load_furniture_state()
	for entry in entries:
		var entry_room_id := str(entry.get("room_id", ""))
		if room_id != "" and entry_room_id != room_id:
			continue

		var scene_path := str(entry.get("scene", ""))
		if scene_path.is_empty():
			continue

		var packed := load(scene_path)
		if not (packed is PackedScene):
			continue

		var instance := (packed as PackedScene).instantiate()
		parent.add_child(instance)

		if instance is Node2D:
			var node_2d := instance as Node2D
			node_2d.global_position = _to_vector2(entry.get("position", Vector2.ZERO))
			node_2d.rotation = float(entry.get("rotation", 0.0))


func load_furniture_state() -> Array:
	var save_path := _save_path()
	if save_path.is_empty():
		return []
	if not FileAccess.file_exists(save_path):
		return []

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("[FurnitureSaveManager] Failed to open save file: %s" % save_path)
		return []

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		return parsed
	return []


func save_furniture_state(entries: Array) -> void:
	var save_path := _save_path()
	if save_path.is_empty():
		return

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("[FurnitureSaveManager] Failed to open save file for write: %s" % save_path)
		return

	file.store_string(JSON.stringify(entries))


func _active_character_id() -> String:
	if CharacterSaveManager == null:
		return ""

	var profile := CharacterSaveManager.get_active_character()
	if profile == null:
		return ""

	return str(profile.character_id)


func _save_path() -> String:
	var character_id := _active_character_id()
	if character_id.is_empty():
		return ""

	var character_dir := "%s/%s" % [CHARACTERS_ROOT, character_id]
	DirAccess.make_dir_recursive_absolute(character_dir)
	return "%s/%s" % [character_dir, SAVE_FILE_NAME]


func _to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
