class_name PersistentObject
extends Node

@export var persistent_id: String = ""
@export var scene_path: String = ""
@export var owner_character_id: String = ""
@export var creation_timestamp: String = ""

var _is_registered: bool = false


func _ready() -> void:
	_refresh_scene_path()

	if owner_character_id.is_empty() and PersistenceRegistry != null:
		owner_character_id = PersistenceRegistry.get_default_owner_character_id()

	if creation_timestamp.is_empty():
		creation_timestamp = Time.get_datetime_string_from_system(true)

	if PersistenceRegistry != null:
		PersistenceRegistry.register_object(self)
		_is_registered = true


func _exit_tree() -> void:
	if _is_registered and PersistenceRegistry != null:
		PersistenceRegistry.unregister_object(self)
	_is_registered = false


func get_persistent_owner() -> Node:
	return get_parent()


func apply_persistence_data(data: Dictionary) -> void:
	persistent_id = str(data.get("persistent_id", persistent_id))
	scene_path = str(data.get("scene_path", scene_path))
	owner_character_id = str(data.get("owner_character_id", owner_character_id))
	creation_timestamp = str(data.get("creation_timestamp", creation_timestamp))
	_refresh_scene_path()


func to_persistence_data() -> Dictionary:
	_refresh_scene_path()
	return {
		"persistent_id": persistent_id,
		"scene_path": scene_path,
		"owner_character_id": owner_character_id,
		"creation_timestamp": creation_timestamp
	}


func _refresh_scene_path() -> void:
	if not scene_path.is_empty():
		return

	var owner_node := get_persistent_owner()
	if owner_node != null and not owner_node.scene_file_path.is_empty():
		scene_path = owner_node.scene_file_path
		return

	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		scene_path = tree.current_scene.scene_file_path
