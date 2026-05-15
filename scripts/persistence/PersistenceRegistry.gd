extends Node

signal object_registered(persistent_id: String, persistent_object: PersistentObject)
signal object_unregistered(persistent_id: String)

var _objects_by_id: Dictionary[String, WeakRef] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _runtime_id_counter: int = 0


func _ready() -> void:
	_rng.randomize()


func register_object(persistent_object: PersistentObject) -> void:
	if persistent_object == null:
		return

	_cleanup_invalid_entries()
	var resolved_id := ensure_persistent_id(persistent_object)
	var current_ref := _objects_by_id.get(resolved_id, null)
	var current_object := _resolve_ref(current_ref)

	if current_object != null and current_object != persistent_object:
		resolved_id = create_runtime_id(persistent_object.owner_character_id)
		persistent_object.persistent_id = resolved_id

	_objects_by_id[resolved_id] = weakref(persistent_object)
	object_registered.emit(resolved_id, persistent_object)


func unregister_object(persistent_object: PersistentObject) -> void:
	if persistent_object == null:
		return

	var persistent_id := persistent_object.persistent_id
	if persistent_id.is_empty():
		return

	var stored_object := get_persistent_object(persistent_id)
	if stored_object != null and stored_object != persistent_object:
		return

	_objects_by_id.erase(persistent_id)
	object_unregistered.emit(persistent_id)


func ensure_persistent_id(persistent_object: PersistentObject) -> String:
	if persistent_object == null:
		return ""

	if not persistent_object.persistent_id.is_empty():
		return persistent_object.persistent_id

	var scene_stable_id := _build_scene_stable_id(persistent_object)
	if not scene_stable_id.is_empty():
		persistent_object.persistent_id = scene_stable_id
		return scene_stable_id

	var runtime_id := create_runtime_id(persistent_object.owner_character_id)
	persistent_object.persistent_id = runtime_id
	return runtime_id


func create_runtime_id(owner_character_id: String = "") -> String:
	_runtime_id_counter += 1

	var owner_part := owner_character_id
	if owner_part.is_empty():
		owner_part = get_default_owner_character_id()
	if owner_part.is_empty():
		owner_part = "world"

	var timestamp := Time.get_ticks_usec()
	var random_value := _rng.randi()
	return "po_%s_%s_%s_%s" % [owner_part, str(timestamp), str(_runtime_id_counter), str(random_value)]


func get_persistent_object(persistent_id: String) -> PersistentObject:
	if persistent_id.is_empty():
		return null

	var ref := _objects_by_id.get(persistent_id, null)
	return _resolve_ref(ref)


func get_object_by_id(persistent_id: String) -> Node:
	var persistent_object := get_persistent_object(persistent_id)
	if persistent_object == null:
		return null
	return persistent_object.get_persistent_owner()


func has_persistent_id(persistent_id: String) -> bool:
	return get_persistent_object(persistent_id) != null


func export_registry_snapshot() -> Dictionary:
	_cleanup_invalid_entries()
	var snapshot: Dictionary = {}

	for persistent_id in _objects_by_id.keys():
		var persistent_object := get_persistent_object(persistent_id)
		if persistent_object == null:
			continue
		snapshot[persistent_id] = persistent_object.to_persistence_data()

	return snapshot


func get_default_owner_character_id() -> String:
	if CharacterSaveManager == null:
		return ""

	var profile := CharacterSaveManager.get_active_character()
	if profile == null:
		return ""

	return str(profile.character_id)


func _build_scene_stable_id(persistent_object: PersistentObject) -> String:
	var owner_node := persistent_object.get_persistent_owner()
	if owner_node == null:
		return ""

	var resolved_scene_path := persistent_object.scene_path
	if resolved_scene_path.is_empty():
		resolved_scene_path = owner_node.scene_file_path
	if resolved_scene_path.is_empty():
		var tree := owner_node.get_tree()
		if tree != null and tree.current_scene != null:
			resolved_scene_path = tree.current_scene.scene_file_path

	if resolved_scene_path.is_empty():
		return ""

	var owner_path := str(owner_node.get_path())
	if owner_path.is_empty():
		return ""

	return "scene_%s" % _hash_text("%s|%s" % [resolved_scene_path, owner_path])


func _hash_text(value: String) -> String:
	var hasher := HashingContext.new()
	var start_error := hasher.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return str(value.hash())

	hasher.update(value.to_utf8_buffer())
	return hasher.finish().hex_encode()


func _cleanup_invalid_entries() -> void:
	var stale_ids: Array[String] = []

	for persistent_id in _objects_by_id.keys():
		var ref := _objects_by_id[persistent_id]
		if _resolve_ref(ref) == null:
			stale_ids.append(persistent_id)

	for stale_id in stale_ids:
		_objects_by_id.erase(stale_id)


func _resolve_ref(ref: Variant) -> PersistentObject:
	if ref is WeakRef:
		var target := (ref as WeakRef).get_ref()
		if target is PersistentObject and is_instance_valid(target):
			return target
	return null
