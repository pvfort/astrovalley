class_name ContainerUI
extends Control

@export var slot_scene: PackedScene = preload("res://scenes/ui/ContainerSlot.tscn")

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var player_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Storage/TransferContainer/PlayerColumn/PlayerGrid
@onready var container_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Storage/TransferContainer/ContainerColumn/ContainerGrid
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/BottomRow/CloseButton

var _container: ContainerComponent = null
var _player: PlayerCharacter = null


func _ready() -> void:
	visible = false
	add_to_group("container_ui")
	add_to_group("movement_blocking_ui")
	close_button.pressed.connect(close_container)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_container()
		get_viewport().set_input_as_handled()


func is_open_for(container: ContainerComponent) -> bool:
	return visible and _container == container


func open_container(container: ContainerComponent, player: PlayerCharacter) -> void:
	if container == null:
		return

	if _container != null and _container.container_changed.is_connected(_on_container_changed):
		_container.container_changed.disconnect(_on_container_changed)

	_container = container
	_player = player
	_container.container_changed.connect(_on_container_changed)

	_rebuild_slots()
	_refresh_all_slots()
	title_label.text = "Container: %s" % _container.container_id
	visible = true

	if _container != null:
		var player_id := _resolve_player_id()
		_container.notify_opened(player_id)


func close_container() -> void:
	if not visible:
		return

	if _container != null:
		var player_id := _resolve_player_id()
		_container.notify_closed(player_id)
		if _container.container_changed.is_connected(_on_container_changed):
			_container.container_changed.disconnect(_on_container_changed)

	_container = null
	_player = null
	visible = false


func can_drag_from(source: String, slot_index: int) -> bool:
	var slot_data := _get_slot_data(source, slot_index)
	return slot_data != null


func build_drag_data(source: String, slot_index: int) -> Dictionary:
	if not visible:
		return {}
	var slot_data := _get_slot_data(source, slot_index)
	if slot_data == null:
		return {}
	var item := slot_data.get("item", null) as ItemData
	if item == null:
		return {}
	return {
		"source": source,
		"source_index": slot_index
	}


func can_drop_on_slot(target_source: String, target_index: int, drag_data: Variant) -> bool:
	if not visible:
		return false
	if _container == null:
		return false
	if not (drag_data is Dictionary):
		return false
	var data := drag_data as Dictionary
	var source := str(data.get("source", ""))
	var source_index := int(data.get("source_index", -1))
	if source.is_empty() or source_index < 0:
		return false
	if source == target_source and source_index == target_index:
		return false

	var source_slot := _get_slot_data(source, source_index)
	if source_slot == null:
		return false

	var source_item := source_slot.get("item", null) as ItemData
	if source_item == null:
		return false

	var target_slot := _get_slot_data(target_source, target_index)
	if target_slot == null:
		return true

	var target_item := target_slot.get("item", null) as ItemData
	if target_item == null:
		return true

	return target_item.item_id == source_item.item_id


func drop_on_slot(target_source: String, target_index: int, drag_data: Variant) -> void:
	if not (drag_data is Dictionary):
		return
	var data := drag_data as Dictionary
	var source := str(data.get("source", ""))
	var source_index := int(data.get("source_index", -1))
	if source.is_empty() or source_index < 0:
		return

	_transfer_between_slots(source, source_index, target_source, target_index)


func _transfer_between_slots(source: String, source_index: int, target_source: String, target_index: int) -> void:
	var source_slot := _get_slot_data(source, source_index)
	if source_slot == null:
		return

	var source_item := source_slot.get("item", null) as ItemData
	if source_item == null:
		return
	var source_count := int(source_slot.get("count", 1))

	var target_slot := _get_slot_data(target_source, target_index)
	if target_slot == null:
		var remainder := _try_insert_into_slot(target_source, target_index, source_item, source_count)
		var moved_count := source_count - remainder
		if moved_count > 0:
			_remove_from_slot(source, source_index, moved_count)
		_refresh_all_slots()
		return

	var target_item := target_slot.get("item", null) as ItemData
	if target_item == null:
		return

	if target_item.item_id == source_item.item_id:
		var remainder := _try_insert_into_slot(target_source, target_index, source_item, source_count)
		var moved_count := source_count - remainder
		if moved_count > 0:
			_remove_from_slot(source, source_index, moved_count)
		_refresh_all_slots()
		return

	_set_slot(source, source_index, target_slot)
	_set_slot(target_source, target_index, source_slot)
	_refresh_all_slots()


func _rebuild_slots() -> void:
	var player_size := InventoryManager.get_inventory_size() if InventoryManager != null else 0
	_rebuild_grid(player_grid, player_size, "player")

	var container_size := _container.get_slot_size() if _container != null else 0
	_rebuild_grid(container_grid, container_size, "container")


func _rebuild_grid(grid: GridContainer, desired_count: int, source: String) -> void:
	while grid.get_child_count() > desired_count:
		var child := grid.get_child(grid.get_child_count() - 1)
		grid.remove_child(child)
		child.queue_free()

	while grid.get_child_count() < desired_count:
		var slot := slot_scene.instantiate()
		if slot.has_method("configure"):
			slot.configure(self, source, grid.get_child_count())
		grid.add_child(slot)

	for i in range(grid.get_child_count()):
		var child := grid.get_child(i)
		if child.has_method("configure"):
			child.configure(self, source, i)


func _refresh_all_slots() -> void:
	_refresh_grid_slots(player_grid, "player")
	_refresh_grid_slots(container_grid, "container")


func _refresh_grid_slots(grid: GridContainer, source: String) -> void:
	for i in range(grid.get_child_count()):
		var slot := grid.get_child(i)
		if slot.has_method("set_slot_data"):
			slot.set_slot_data(_get_slot_data(source, i))


func _get_slot_data(source: String, index: int) -> Variant:
	if source == "player":
		if InventoryManager == null:
			return null
		return InventoryManager.get_inventory_slot(index)
	if source == "container":
		if _container == null:
			return null
		return _container.get_slot(index)
	return null


func _set_slot(source: String, index: int, slot_data: Variant) -> void:
	if source == "player":
		if InventoryManager == null:
			return
		InventoryManager.set_inventory_slot(index, slot_data)
		return
	if source == "container" and _container != null:
		_container.set_slot(index, slot_data)


func _remove_from_slot(source: String, index: int, count: int) -> Dictionary:
	if source == "player":
		if InventoryManager == null:
			return {}
		return InventoryManager.remove_from_slot(index, count)
	if source == "container" and _container != null:
		return _container.remove_from_slot(index, count)
	return {}


func _try_insert_into_slot(source: String, index: int, item: ItemData, count: int) -> int:
	if source == "player":
		if InventoryManager == null:
			return max(count, 0)
		return InventoryManager.try_insert_into_slot(index, item, count)
	if source == "container" and _container != null:
		return _container.try_insert_into_slot(index, item, count)
	return max(count, 0)


func _on_container_changed() -> void:
	_refresh_all_slots()


func _resolve_player_id() -> int:
	if _player != null:
		return _player.player_id
	return multiplayer.get_unique_id()
