extends Node

const TILE_SIZE: int = 32
const ROTATION_INCREMENT: float = PI * 0.5
const COLLISION_MARGIN: float = 2.0
const MAX_COLLISION_CHECKS: int = 16
const WALKABLE_FLOOR_SOURCE_IDS: Array[int] = [0, 4]

signal build_mode_started
signal build_mode_ended
signal preview_updated(world_position: Vector2, is_valid: bool)
signal furniture_placed(entity: Node2D, item_data: ItemData, world_position: Vector2)

var _build_mode_active: bool = false
var _selected_item: ItemData = null
var _selected_slot_index: int = -1
var _preview: BuildPreview = null
var _last_preview_position: Vector2 = Vector2.ZERO
var _last_preview_valid: bool = false
var _current_rotation: float = 0.0


func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)


func is_build_mode_active() -> bool:
	return _build_mode_active


func has_selected_placeable() -> bool:
	return _selected_item != null and _selected_item.placeable and _selected_item.get_active_placeable_scene() != null


func toggle_build_mode() -> bool:
	if _build_mode_active:
		exit_build_mode()
		return false
	return enter_build_mode()


func enter_build_mode() -> bool:
	if _build_mode_active:
		return true
	_build_mode_active = true
	set_process(true)
	set_process_unhandled_input(true)
	_refresh_preview()
	build_mode_started.emit()
	return true


func exit_build_mode() -> void:
	if not _build_mode_active:
		return
	_build_mode_active = false
	set_process(false)
	set_process_unhandled_input(false)
	_clear_preview()
	build_mode_ended.emit()


func set_selected_item(item_data: ItemData, source_slot_index: int = -1) -> void:
	_selected_item = item_data
	_selected_slot_index = source_slot_index
	_current_rotation = 0.0
	_refresh_preview()


func cancel_placement() -> void:
	_selected_item = null
	_selected_slot_index = -1
	_current_rotation = 0.0
	_refresh_preview()


func rotate_preview() -> void:
	if _preview == null:
		return
	_current_rotation += ROTATION_INCREMENT
	_preview.rotation = _current_rotation
	preview_updated.emit(_last_preview_position, _last_preview_valid)


func _process(_delta: float) -> void:
	if not _build_mode_active:
		return
	_update_preview_state()


func _unhandled_input(event: InputEvent) -> void:
	if not _build_mode_active:
		return

	if event.is_action_pressed("placement_cancel"):
		cancel_placement()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("placement_rotate"):
		rotate_preview()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("placement_confirm"):
		if _last_preview_valid:
			_place_selected_item()
		get_viewport().set_input_as_handled()


func _refresh_preview() -> void:
	if not _build_mode_active:
		return

	if not has_selected_placeable():
		_clear_preview()
		return

	if _preview == null or not is_instance_valid(_preview):
		_preview = BuildPreview.new()
		_preview.grid_size = TILE_SIZE
		var scene := _main_scene()
		if scene != null:
			scene.add_child(_preview)

	var preview_texture: Texture2D = _resolve_preview_texture(_selected_item)
	_preview.configure(preview_texture, _selected_item.placement_offset)
	_preview.rotation = _current_rotation
	_update_preview_state()


func _clear_preview() -> void:
	_last_preview_valid = false
	if _preview != null and is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null
	preview_updated.emit(_last_preview_position, false)


func _update_preview_state() -> void:
	if _preview == null or not is_instance_valid(_preview):
		return
	_last_preview_position = _get_snapped_mouse_world_position()
	_last_preview_valid = _validate_placement(_last_preview_position)
	_preview.set_world_position(_last_preview_position)
	_preview.set_validity(_last_preview_valid)
	preview_updated.emit(_last_preview_position, _last_preview_valid)


func _place_selected_item() -> void:
	if _selected_item == null:
		return

	var placeable_scene: PackedScene = _selected_item.get_active_placeable_scene()
	if placeable_scene == null:
		return

	var instance: Node = placeable_scene.instantiate()
	if not (instance is Node2D):
		return

	if not _consume_selected_item():
		if instance != null and is_instance_valid(instance):
			instance.queue_free()
		return

	var parent: Node = _resolve_furniture_parent()
	parent.add_child(instance)

	var furniture: Node2D = instance as Node2D
	furniture.global_position = _last_preview_position + _selected_item.placement_offset
	furniture.rotation = _current_rotation

	if FurnitureSaveManager != null:
		var room_id: String = _current_room_id()
		FurnitureSaveManager.add_furniture(placeable_scene.resource_path, furniture.global_position, furniture.rotation, room_id)

	furniture_placed.emit(furniture, _selected_item, _last_preview_position)
	cancel_placement()


func _consume_selected_item() -> bool:
	if InventoryManager == null or _selected_item == null:
		return false

	if _selected_slot_index >= 0:
		var slot_data: Variant = InventoryManager.get_inventory_slot(_selected_slot_index)
		if slot_data != null:
			var raw_item: Variant = slot_data.get("item")
			var slot_item: ItemData = raw_item if raw_item is ItemData else null
			if slot_item != null and slot_item.item_id == _selected_item.item_id:
				InventoryManager.remove_item(_selected_slot_index)
				return true

	return InventoryManager.remove_item_by_id(_selected_item.item_id)


func _resolve_preview_texture(item_data: ItemData) -> Texture2D:
	if item_data == null:
		return null

	var scene: PackedScene = item_data.get_active_placeable_scene()
	if scene != null:
		var instance: Node = scene.instantiate()
		var texture: Texture2D = _find_sprite_texture(instance)
		instance.queue_free()
		if texture != null:
			return texture

	return item_data.icon


func _find_sprite_texture(root: Node) -> Texture2D:
	if root is Sprite2D:
		return (root as Sprite2D).texture

	for child in root.get_children():
		var child_texture: Texture2D = _find_sprite_texture(child)
		if child_texture != null:
			return child_texture

	return null


func _validate_placement(world_position: Vector2) -> bool:
	var tilemap: TileMap = _room_tilemap()
	if tilemap == null:
		return false

	var footprint: Vector2i = _selected_item.get_active_footprint_size() if _selected_item != null else Vector2i.ONE
	for y in range(footprint.y):
		for x in range(footprint.x):
			var sample_world := world_position + Vector2(float(x * TILE_SIZE), float(y * TILE_SIZE))
			var map_cell: Vector2i = tilemap.local_to_map(tilemap.to_local(sample_world))
			if not _is_inside_room_bounds(tilemap, map_cell):
				return false
			if not _is_walkable_floor(tilemap, map_cell):
				return false

	if _has_collision_overlap(world_position, footprint):
		return false

	return true


func _is_inside_room_bounds(tilemap: TileMap, map_cell: Vector2i) -> bool:
	var used_rect: Rect2i = tilemap.get_used_rect()
	return used_rect.has_point(map_cell)


func _is_walkable_floor(tilemap: TileMap, map_cell: Vector2i) -> bool:
	var source_id: int = tilemap.get_cell_source_id(0, map_cell)
	return WALKABLE_FLOOR_SOURCE_IDS.has(source_id)


func _has_collision_overlap(world_position: Vector2, footprint: Vector2i) -> bool:
	var scene: Node = _main_scene()
	if not (scene is Node2D):
		return true

	var space_state: PhysicsDirectSpaceState2D = (scene as Node2D).get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = Vector2(
		float(max(footprint.x, 1) * TILE_SIZE) - COLLISION_MARGIN,
		float(max(footprint.y, 1) * TILE_SIZE) - COLLISION_MARGIN
	)

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D.IDENTITY.translated(world_position + _selected_item.placement_offset)
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var results: Array[Dictionary] = space_state.intersect_shape(query, MAX_COLLISION_CHECKS)
	return not results.is_empty()


func _get_snapped_mouse_world_position() -> Vector2:
	var mouse_world: Vector2 = _mouse_world_position()
	return Vector2(
		round(mouse_world.x / float(TILE_SIZE)) * float(TILE_SIZE),
		round(mouse_world.y / float(TILE_SIZE)) * float(TILE_SIZE)
	)


func _mouse_world_position() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO

	var camera: Camera2D = viewport.get_camera_2d()
	if camera != null:
		return camera.get_global_mouse_position()

	return viewport.get_mouse_position()


func _room_tilemap() -> TileMap:
	var scene: Node = _main_scene()
	if scene != null and scene.has_method("get_room_tilemap"):
		return scene.get_room_tilemap()
	return null


func _resolve_furniture_parent() -> Node:
	var scene: Node = _main_scene()
	if scene != null and scene.has_method("get_furniture_container"):
		var container: Node = scene.get_furniture_container()
		if container != null:
			return container
	return scene


func _main_scene() -> Node:
	return get_tree().current_scene


func _current_room_id() -> String:
	var scene: Node = _main_scene()
	if scene != null and scene.has_method("get_current_room_id"):
		return str(scene.get_current_room_id())
	return ""
