extends Node

const TILE_SIZE := 32
const VALID_PREVIEW_COLOR := Color(1.0, 1.0, 1.0, 0.65)
const INVALID_PREVIEW_COLOR := Color(1.0, 0.35, 0.35, 0.75)
const FLOOR_TILE_SOURCE_IDS := [0, 4]
const PERSISTENT_OBJECT_SCRIPT := preload("res://scripts/persistence/PersistentObject.gd")

var _active_item: ItemData = null
var _source_slot_index: int = -1
var _preview_sprite: Sprite2D = null
var _placement_active: bool = false
var _snapped_position: Vector2 = Vector2.ZERO
var _is_valid_position: bool = false


func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)


func begin_placement(item_data: ItemData, source_slot_index: int = -1) -> bool:
	if item_data == null or not item_data.placeable or item_data.placed_scene == null:
		return false

	cancel_placement()

	var scene := get_tree().current_scene
	if scene == null:
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


func _process(_delta: float) -> void:
	if not _placement_active:
		return
	_update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if not _placement_active:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		cancel_placement()
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventMouseButton) or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if _is_valid_position:
			_confirm_placement()
		get_viewport().set_input_as_handled()
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
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

	var instance := _active_item.placed_scene.instantiate()
	if not (instance is Node2D):
		cancel_placement()
		return

	var scene_path := _active_item.placed_scene.resource_path
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

	if InventoryManager != null:
		if _source_slot_index >= 0:
			InventoryManager.remove_item(_source_slot_index)
		else:
			InventoryManager.remove_item_by_id(_active_item.item_id)

	if FurnitureSaveManager != null:
		var room_id := _current_room_id()
		FurnitureSaveManager.add_furniture(
			scene_path,
			_snapped_position,
			furniture.rotation,
			room_id,
			persistent_object.persistent_id,
			persistent_object.owner_character_id,
			persistent_object.creation_timestamp
		)
	var scene_path := _active_item.placed_scene.resource_path
	var room_id := _current_room_id()
	_attach_saveable_component(furniture, scene_path, room_id)

	if SaveManager != null:
		if SaveManager.has_method("request_autosave"):
			SaveManager.request_autosave()
		else:
			SaveManager.save_world()
	elif FurnitureSaveManager != null:
		FurnitureSaveManager.add_furniture(scene_path, _snapped_position, furniture.rotation, room_id)

	cancel_placement()


func _resolve_furniture_parent() -> Node:
	var scene := get_tree().current_scene
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
	if not room_id.begins_with("office_"):
		return false

	if not main.has_method("get_room_tilemap"):
		return false
	var tilemap: TileMap = main.get_room_tilemap()
	if tilemap == null:
		return false

	var placement_size := _placement_size()
	for y in range(placement_size.y):
		for x in range(placement_size.x):
			var sample_world := world_position + Vector2(x * TILE_SIZE, y * TILE_SIZE)
			var map_cell := tilemap.local_to_map(tilemap.to_local(sample_world))
			var source_id := tilemap.get_cell_source_id(0, map_cell)
			if not FLOOR_TILE_SOURCE_IDS.has(source_id):
				return false

	if _has_furniture_overlap(main, world_position, placement_size):
		return false

	return true


func _has_furniture_overlap(main: Node, world_position: Vector2, placement_size: Vector2i) -> bool:
	if not (main is Node2D):
		return true

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

	var results := space.intersect_shape(query, 16)
	return not results.is_empty()


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


func _active_character_id() -> String:
	if CharacterSaveManager == null:
		return ""

	var profile := CharacterSaveManager.get_active_character()
	if profile == null:
		return ""

	return str(profile.character_id)


func _ensure_persistent_object(instance: Node) -> PersistentObject:
	var existing := instance.find_child("PersistentObject", true, false)
	if existing is PersistentObject:
		return existing as PersistentObject

	var persistent_object := PERSISTENT_OBJECT_SCRIPT.new() as PersistentObject
	persistent_object.name = "PersistentObject"
	instance.add_child(persistent_object)
	return persistent_object
func _attach_saveable_component(node: Node2D, scene_path: String, room_id: String) -> void:
	var saveable := node.get_node_or_null("SaveableComponent")
	if not (saveable is SaveableComponent):
		saveable = SaveableComponent.new()
		saveable.name = "SaveableComponent"
		node.add_child(saveable)

	var component := saveable as SaveableComponent
	component.category = "placed_furniture"
	component.scene_path_override = scene_path
	component.set_component_state_value("room_id", room_id)
