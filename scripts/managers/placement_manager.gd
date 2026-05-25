extends Node

const TILE_SIZE := 32
const VALID_PREVIEW_COLOR := Color(1.0, 1.0, 1.0, 0.65)
const INVALID_PREVIEW_COLOR := Color(1.0, 0.35, 0.35, 0.75)
const FLOOR_TILE_SOURCE_IDS := [0, 4]
const PERSISTENT_OBJECT_SCRIPT := preload("res://scripts/persistence/PersistentObject.gd")
const ZONE_DEFAULTS_PATH := "res://data/office_zone_defaults.json"
const ZONE_SAVE_FILE_NAME := "office_zones.json"
const MAX_PLAYERS_PER_OFFICE := 5

var _active_item: ItemData = null
var _source_slot_index: int = -1
var _preview_sprite: Sprite2D = null
var _placement_active: bool = false
var _snapped_position: Vector2 = Vector2.ZERO
var _is_valid_position: bool = false
var _zone_defaults_cache: Dictionary = {}


func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	_zone_defaults_cache = _load_zone_defaults()


func begin_placement(item_data: ItemData, source_slot_index: int = -1) -> bool:
	if item_data == null or not item_data.placeable or item_data.placed_scene == null:
		return false

	cancel_placement()

	var scene: Node = get_tree().current_scene
	if scene == null:
		return false

	if not _is_owned_office_room(_current_room_id()):
		return false

	_active_item = item_data
	_source_slot_index = source_slot_index
	_placement_active = true

	_preview_sprite = Sprite2D.new()
	_preview_sprite.texture = item_data.icon
	_preview_sprite.modulate = VALID_PREVIEW_COLOR
	_preview_sprite.z_index = 10_000
	scene.add_child(_preview_sprite)

	set_process(true)
	set_process_unhandled_input(true)
	_update_preview()
	return true


func is_placement_active() -> bool:
	return _placement_active


func cancel_placement() -> void:
	_placement_active = false
	_active_item = null
	_source_slot_index = -1
	_is_valid_position = false

	if _preview_sprite != null and is_instance_valid(_preview_sprite):
		_preview_sprite.queue_free()
	_preview_sprite = null

	set_process(false)
	set_process_unhandled_input(false)


func get_active_player_zone(room_id: String = "") -> Dictionary:
	var target_room: String = room_id
	if target_room.is_empty():
		target_room = _current_room_id()
	return _zone_entry_for_player(target_room, _active_character_id())


func set_active_player_zone(zone_id: String, rects: Array = [], room_id: String = "") -> bool:
	var target_room: String = room_id
	if target_room.is_empty():
		target_room = _current_room_id()
	if not _is_owned_office_room(target_room):
		return false

	var owner_id: String = _active_character_id()
	if owner_id.is_empty():
		return false

	var zone_data: Dictionary = _load_zone_state()
	var room_data: Dictionary = _room_zone_data(zone_data, target_room)
	var zones_by_owner: Dictionary = _dictionary(room_data.get("zones_by_owner", {}))

	if not zones_by_owner.has(owner_id) and zones_by_owner.size() >= _max_players_per_office():
		return false

	var resolved_rects: Array = _normalize_zone_rects(rects)
	if resolved_rects.is_empty():
		resolved_rects = _default_zone_rects_for_owner(owner_id)
	if resolved_rects.is_empty():
		return false

	zones_by_owner[owner_id] = {
		"zone_id": zone_id.strip_edges() if not zone_id.strip_edges().is_empty() else _default_zone_id_for_owner(owner_id),
		"rects": resolved_rects,
		"updated_at": Time.get_datetime_string_from_system(true),
	}
	room_data["zones_by_owner"] = zones_by_owner
	_set_room_zone_data(zone_data, target_room, room_data)
	_save_zone_state(zone_data)
	return true


func move_furniture(node: Node2D, target_world_position: Vector2) -> bool:
	if node == null:
		return false

	var owner_id: String = _owner_character_id_for_node(node)
	if owner_id.is_empty() or owner_id != _active_character_id():
		return false

	var main := _main_scene()
	if main == null or not main.has_method("get_room_tilemap"):
		return false
	var tilemap: TileMap = main.get_room_tilemap()
	if tilemap == null:
		return false

	var room_id := _current_room_id()
	var snapped := Vector2(
		round(target_world_position.x / TILE_SIZE) * TILE_SIZE,
		round(target_world_position.y / TILE_SIZE) * TILE_SIZE
	)
	if not _is_floor_footprint(tilemap, snapped, Vector2i.ONE):
		return false
	if not _is_position_inside_zone(room_id, owner_id, snapped, Vector2i.ONE, tilemap):
		return false
	if not _collect_overlapping_furniture(main, snapped, Vector2i.ONE, node).is_empty():
		return false

	node.global_position = snapped
	_persist_furniture_transform(node, room_id)
	return true


func _process(_delta: float) -> void:
	if not _placement_active:
		return
	_update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if not _placement_active:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			cancel_placement()
			get_viewport().set_input_as_handled()
			return

	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return

	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if _is_valid_position:
			_confirm_placement()
		get_viewport().set_input_as_handled()
		return

	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_placement()
		get_viewport().set_input_as_handled()


func _update_preview() -> void:
	if _preview_sprite == null or not is_instance_valid(_preview_sprite):
		return

	_snapped_position = _get_snapped_mouse_world_position()
	_is_valid_position = _validate_placement(_snapped_position)

	_preview_sprite.global_position = _snapped_position
	_preview_sprite.modulate = VALID_PREVIEW_COLOR if _is_valid_position else INVALID_PREVIEW_COLOR


func _confirm_placement() -> void:
	if _active_item == null or _active_item.placed_scene == null:
		cancel_placement()
		return

	var instance: Node = _active_item.placed_scene.instantiate()
	if not (instance is Node2D):
		cancel_placement()
		return

	var scene_path := _active_item.placed_scene.resource_path
	var room_id := _current_room_id()

	var persistent_object := _ensure_persistent_object(instance)
	persistent_object.scene_path = scene_path
	if persistent_object.owner_character_id.is_empty():
		persistent_object.owner_character_id = _active_character_id()
	if persistent_object.creation_timestamp.is_empty():
		persistent_object.creation_timestamp = Time.get_datetime_string_from_system(true)
	if persistent_object.persistent_id.is_empty() and PersistenceRegistry != null:
		persistent_object.persistent_id = PersistenceRegistry.create_runtime_id(persistent_object.owner_character_id)

	var parent := _resolve_furniture_parent()
	parent.add_child(instance)

	var furniture := instance as Node2D
	furniture.global_position = _snapped_position
	_attach_saveable_component(furniture, scene_path, room_id)

	var main := _main_scene()
	if not _resolve_conflicts_for_new_furniture(main, furniture, room_id, _placement_size()):
		furniture.queue_free()
		cancel_placement()
		return

	if InventoryManager != null:
		if _source_slot_index >= 0:
			InventoryManager.remove_item(_source_slot_index)
		else:
			InventoryManager.remove_item_by_id(_active_item.item_id)

	if FurnitureSaveManager != null:
		FurnitureSaveManager.add_furniture(
			scene_path,
			_snapped_position,
			furniture.rotation,
			room_id,
			persistent_object.persistent_id,
			persistent_object.owner_character_id,
			persistent_object.creation_timestamp
		)

	_persist_furniture_transform(furniture, room_id)
	cancel_placement()


func _resolve_conflicts_for_new_furniture(main: Node, furniture: Node2D, room_id: String, placement_size: Vector2i) -> bool:
	if main == null:
		return false

	var conflicts: Array[Node2D] = _collect_overlapping_furniture(main, furniture.global_position, placement_size, furniture)
	for conflicting_item in conflicts:
		if not _move_existing_item_to_valid_tile(conflicting_item, room_id):
			return false

	return _collect_overlapping_furniture(main, furniture.global_position, placement_size, furniture).is_empty()


func _move_existing_item_to_valid_tile(item: Node2D, room_id: String) -> bool:
	if item == null:
		return false

	var main := _main_scene()
	if main == null or not main.has_method("get_room_tilemap"):
		return false
	var tilemap: TileMap = main.get_room_tilemap()
	if tilemap == null:
		return false

	var owner_id: String = _owner_character_id_for_node(item)
	var origin_cell: Vector2i = tilemap.local_to_map(tilemap.to_local(item.global_position))

	for radius in range(0, 15):
		for y in range(origin_cell.y - radius, origin_cell.y + radius + 1):
			for x in range(origin_cell.x - radius, origin_cell.x + radius + 1):
				var candidate_cell := Vector2i(x, y)
				var candidate_world := tilemap.to_global(tilemap.map_to_local(candidate_cell))
				if not _is_floor_footprint(tilemap, candidate_world, Vector2i.ONE):
					continue
				if not _is_position_inside_zone(room_id, owner_id, candidate_world, Vector2i.ONE, tilemap):
					continue
				if not _collect_overlapping_furniture(main, candidate_world, Vector2i.ONE, item).is_empty():
					continue

				item.global_position = candidate_world
				_persist_furniture_transform(item, room_id)
				return true

	return false


func _collect_overlapping_furniture(main: Node, world_position: Vector2, placement_size: Vector2i, exclude_item: Node2D = null) -> Array[Node2D]:
	var output: Array[Node2D] = []
	if not (main is Node2D):
		return output

	var space := (main as Node2D).get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = Vector2(
		(max(placement_size.x, 1) * TILE_SIZE) - 2.0,
		(max(placement_size.y, 1) * TILE_SIZE) - 2.0
	)

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, world_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 4

	var results := space.intersect_shape(query, 32)
	var seen: Dictionary = {}
	for result_variant in results:
		if not (result_variant is Dictionary):
			continue
		var result := result_variant as Dictionary
		var collider_variant: Variant = result.get("collider", null)
		if not (collider_variant is Node):
			continue
		var resolved_item: Node2D = _resolve_furniture_node(collider_variant as Node)
		if resolved_item == null:
			continue
		if exclude_item != null and resolved_item == exclude_item:
			continue
		var key := str(resolved_item.get_instance_id())
		if seen.has(key):
			continue
		seen[key] = true
		output.append(resolved_item)

	return output


func _resolve_furniture_node(collider: Node) -> Node2D:
	var current: Node = collider
	while current != null:
		if current is Node2D and _is_placed_furniture_node(current as Node2D):
			return current as Node2D
		current = current.get_parent()
	return null


func _is_placed_furniture_node(node: Node2D) -> bool:
	var saveable: Node = node.get_node_or_null("SaveableComponent")
	return saveable is SaveableComponent and (saveable as SaveableComponent).category == "placed_furniture"


func _persist_furniture_transform(node: Node2D, room_id: String) -> void:
	if node == null or FurnitureSaveManager == null:
		return
	var persistent: PersistentObject = _persistent_object_for_node(node)
	if persistent == null or persistent.persistent_id.is_empty():
		return
	FurnitureSaveManager.update_furniture_transform(
		persistent.persistent_id,
		node.global_position,
		node.rotation,
		room_id,
		persistent.owner_character_id
	)
	if SaveManager != null:
		if SaveManager.has_method("request_autosave"):
			SaveManager.request_autosave()
		else:
			SaveManager.save_world()


func _persistent_object_for_node(node: Node) -> PersistentObject:
	if node == null:
		return null
	var persistent_node: Node = node.find_child("PersistentObject", true, false)
	if persistent_node is PersistentObject:
		return persistent_node as PersistentObject
	return null


func _owner_character_id_for_node(node: Node) -> String:
	var persistent: PersistentObject = _persistent_object_for_node(node)
	if persistent == null:
		return ""
	return persistent.owner_character_id


func _resolve_furniture_parent() -> Node:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("get_furniture_container"):
		var container = scene.get_furniture_container()
		if container != null:
			return container
	return scene


func _get_snapped_mouse_world_position() -> Vector2:
	var world_pos := _mouse_world_position()
	return Vector2(
		round(world_pos.x / TILE_SIZE) * TILE_SIZE,
		round(world_pos.y / TILE_SIZE) * TILE_SIZE
	)


func _mouse_world_position() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2.ZERO
	var camera := viewport.get_camera_2d()
	if camera != null:
		return camera.get_global_mouse_position()
	return viewport.get_mouse_position()


func _validate_placement(world_position: Vector2) -> bool:
	var main := _main_scene()
	if main == null:
		return false

	var room_id := _current_room_id()
	if not _is_owned_office_room(room_id):
		return false
	if not main.has_method("get_room_tilemap"):
		return false

	var tilemap: TileMap = main.get_room_tilemap()
	if tilemap == null:
		return false

	var placement_size := _placement_size()
	if not _is_floor_footprint(tilemap, world_position, placement_size):
		return false
	if not _is_position_inside_zone(room_id, _active_character_id(), world_position, placement_size, tilemap):
		return false
	return true


func _is_floor_footprint(tilemap: TileMap, world_position: Vector2, placement_size: Vector2i) -> bool:
	for y in range(placement_size.y):
		for x in range(placement_size.x):
			var sample_world := world_position + Vector2(x * TILE_SIZE, y * TILE_SIZE)
			var map_cell := tilemap.local_to_map(tilemap.to_local(sample_world))
			var source_id := tilemap.get_cell_source_id(0, map_cell)
			if not FLOOR_TILE_SOURCE_IDS.has(source_id):
				return false
	return true


func _is_position_inside_zone(room_id: String, owner_character_id: String, world_position: Vector2, placement_size: Vector2i, tilemap: TileMap) -> bool:
	var zone_entry: Dictionary = _zone_entry_for_player(room_id, owner_character_id)
	var rects_variant: Variant = zone_entry.get("rects", [])
	if not (rects_variant is Array):
		return false
	var rects: Array = rects_variant as Array
	if rects.is_empty():
		return false

	for y in range(placement_size.y):
		for x in range(placement_size.x):
			var sample_world := world_position + Vector2(x * TILE_SIZE, y * TILE_SIZE)
			var map_cell := tilemap.local_to_map(tilemap.to_local(sample_world))
			if not _cell_in_rect_set(map_cell, rects):
				return false
	return true


func _cell_in_rect_set(cell: Vector2i, rects: Array) -> bool:
	for rect_variant in rects:
		var rect_data: Dictionary = _dictionary(rect_variant)
		var rect := Rect2i(
			int(rect_data.get("x", 0)),
			int(rect_data.get("y", 0)),
			max(int(rect_data.get("w", 0)), 1),
			max(int(rect_data.get("h", 0)), 1)
		)
		if rect.has_point(cell):
			return true
	return false


func _zone_entry_for_player(room_id: String, owner_character_id: String) -> Dictionary:
	if room_id.is_empty():
		return {}
	if owner_character_id.is_empty():
		return {}

	var zone_data: Dictionary = _load_zone_state()
	var room_data: Dictionary = _room_zone_data(zone_data, room_id)
	var zones_by_owner: Dictionary = _dictionary(room_data.get("zones_by_owner", {}))
	var existing: Dictionary = _dictionary(zones_by_owner.get(owner_character_id, {}))
	if not existing.is_empty():
		return existing
	var max_players: int = _max_players_per_office()
	if zones_by_owner.size() >= max_players:
		return {}

	var default_entry := {
		"zone_id": _default_zone_id_for_owner(owner_character_id),
		"rects": _default_zone_rects_for_owner(owner_character_id),
		"updated_at": Time.get_datetime_string_from_system(true),
	}
	zones_by_owner[owner_character_id] = default_entry
	room_data["zones_by_owner"] = zones_by_owner
	_set_room_zone_data(zone_data, room_id, room_data)
	_save_zone_state(zone_data)
	return default_entry


func _default_zone_id_for_owner(owner_character_id: String) -> String:
	var templates: Array = _default_zone_templates()
	if templates.is_empty():
		return "zone_1"
	var index: int = abs(owner_character_id.hash()) % templates.size()
	var selected: Dictionary = _dictionary(templates[index])
	return str(selected.get("zone_id", "zone_%d" % (index + 1)))


func _default_zone_rects_for_owner(owner_character_id: String) -> Array:
	var templates: Array = _default_zone_templates()
	if templates.is_empty():
		return [{"x": 1, "y": 1, "w": 8, "h": 6}]
	var index: int = abs(owner_character_id.hash()) % templates.size()
	var selected: Dictionary = _dictionary(templates[index])
	var rects: Variant = selected.get("rects", [])
	if rects is Array:
		return _normalize_zone_rects(rects as Array)
	return [{"x": 1, "y": 1, "w": 8, "h": 6}]


func _default_zone_templates() -> Array:
	var root: Dictionary = _dictionary(_zone_defaults_cache.get("default", {}))
	var templates: Variant = root.get("zones", [])
	if templates is Array:
		return templates as Array
	return []


func _max_players_per_office() -> int:
	var root: Dictionary = _dictionary(_zone_defaults_cache.get("default", {}))
	return max(int(root.get("max_players", MAX_PLAYERS_PER_OFFICE)), 1)


func _normalize_zone_rects(rects: Array) -> Array:
	var normalized: Array = []
	for rect_variant in rects:
		if rect_variant is Array:
			var rect_array := rect_variant as Array
			if rect_array.size() >= 4:
				normalized.append({
					"x": int(rect_array[0]),
					"y": int(rect_array[1]),
					"w": max(int(rect_array[2]), 1),
					"h": max(int(rect_array[3]), 1),
				})
				continue
		var rect_dict: Dictionary = _dictionary(rect_variant)
		if rect_dict.is_empty():
			continue
		normalized.append({
			"x": int(rect_dict.get("x", 0)),
			"y": int(rect_dict.get("y", 0)),
			"w": max(int(rect_dict.get("w", 1)), 1),
			"h": max(int(rect_dict.get("h", 1)), 1),
		})
	return normalized


func _load_zone_defaults() -> Dictionary:
	var file := FileAccess.open(ZONE_DEFAULTS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = SaveSerializer.parse_save_data(file.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _load_zone_state() -> Dictionary:
	var path: String = _zone_save_path()
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"rooms": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"rooms": {}}
	var parsed: Variant = SaveSerializer.parse_save_data(file.get_as_text())
	if parsed is Dictionary:
		var parsed_dict := parsed as Dictionary
		if not parsed_dict.has("rooms"):
			parsed_dict["rooms"] = {}
		return parsed_dict
	return {"rooms": {}}


func _save_zone_state(data: Dictionary) -> void:
	var path: String = _zone_save_path()
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(SaveSerializer.serialize_save_data(data))


func _zone_save_path() -> String:
	var character_id := _active_character_id()
	if character_id.is_empty():
		return ""
	var character_dir: String = "user://characters/%s" % character_id
	DirAccess.make_dir_recursive_absolute(character_dir)
	return "%s/%s" % [character_dir, ZONE_SAVE_FILE_NAME]


func _room_zone_data(zone_data: Dictionary, room_id: String) -> Dictionary:
	var rooms: Dictionary = _dictionary(zone_data.get("rooms", {}))
	return _dictionary(rooms.get(room_id, {}))


func _set_room_zone_data(zone_data: Dictionary, room_id: String, room_data: Dictionary) -> void:
	var rooms: Dictionary = _dictionary(zone_data.get("rooms", {}))
	rooms[room_id] = room_data
	zone_data["rooms"] = rooms


func _placement_size() -> Vector2i:
	if _active_item == null:
		return Vector2i.ONE
	return Vector2i(max(_active_item.placement_size.x, 1), max(_active_item.placement_size.y, 1))


func _main_scene() -> Node:
	return get_tree().current_scene


func _current_room_id() -> String:
	var scene := _main_scene()
	if scene != null and scene.has_method("get_current_room_id"):
		return str(scene.get_current_room_id())
	return ""


func _is_owned_office_room(room_id: String) -> bool:
	if room_id.is_empty():
		return false
	return room_id == _active_office_room_id()


func _active_office_room_id() -> String:
	if CharacterSaveManager == null:
		return ""
	var profile: CharacterProfile = CharacterSaveManager.get_active_character()
	if profile == null:
		return ""
	var office_number := str(profile.office_number).strip_edges()
	if office_number.is_empty():
		return ""
	if office_number.begins_with("office_"):
		return office_number
	return "office_%s" % office_number


func _active_character_id() -> String:
	if CharacterSaveManager == null:
		return ""
	var profile := CharacterSaveManager.get_active_character()
	if profile == null:
		return ""
	return str(profile.character_id)


func _ensure_persistent_object(instance: Node) -> PersistentObject:
	var existing: Node = instance.find_child("PersistentObject", true, false)
	if existing is PersistentObject:
		return existing as PersistentObject

	var persistent_object := PERSISTENT_OBJECT_SCRIPT.new() as PersistentObject
	persistent_object.name = "PersistentObject"
	instance.add_child(persistent_object)
	return persistent_object


func _attach_saveable_component(node: Node2D, scene_path: String, room_id: String) -> void:
	var saveable: Node = node.get_node_or_null("SaveableComponent")
	if not (saveable is SaveableComponent):
		saveable = SaveableComponent.new()
		saveable.name = "SaveableComponent"
		node.add_child(saveable)

	var component := saveable as SaveableComponent
	component.category = "placed_furniture"
	component.scene_path_override = scene_path
	component.set_component_state_value("room_id", room_id)


func _dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
