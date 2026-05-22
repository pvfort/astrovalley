class_name ContainerUI
extends Control

const SLOT_SCENE := preload("res://scenes/ui/ContainerSlot.tscn")

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/Title
@onready var player_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/Content/PlayerColumn/PlayerSlots
@onready var container_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/Content/ContainerColumn/ContainerSlots
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/CloseButton

var _active_container: ContainerComponent = null
var _active_player: PlayerCharacter = null


func _ready() -> void:
	
	add_to_group("container_ui")
	visible = false

	if close_button != null and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

	if InventoryManager != null and not InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
		InventoryManager.inventory_changed.connect(_on_inventory_changed)


func open_container(container: ContainerComponent, player: PlayerCharacter) -> void:

	print("[UI] open_container called")

	if container == null:
		print("[UI] container null")
		return

	visible = true

	print("[UI] visible set true")

	_close_current_container_binding()

	_active_container = container
	_active_player = player

	title_label.text = "Container: %s" % container.container_id

	if not container.container_changed.is_connected(_on_container_changed):
		container.container_changed.connect(_on_container_changed)

	if InventoryManager != null:
		InventoryManager.set_inventory_open(true)

	refresh()


func close_container() -> void:
	_close_current_container_binding()
	_active_player = null
	visible = false

	if InventoryManager != null:
		InventoryManager.set_inventory_open(false)


func refresh() -> void:
	if _active_container == null:
		return

	_rebuild_player_grid()
	_rebuild_container_grid()


func _rebuild_player_grid() -> void:
	
	_clear_children(player_grid)
	print("REBUILD PLAYER GRID")

	for i in range(InventoryManager.get_inventory_size()):
		var slot_node: Node = SLOT_SCENE.instantiate()
		print(slot_node)
		print(slot_node.get_class())
		print(slot_node.get_script())
		print("creating slot")
		print("instantiated:", slot_node)


		if not (slot_node is ContainerSlotUI):
			print("NOT SLOT UI")
			continue

		var slot_ui: ContainerSlotUI = slot_node as ContainerSlotUI
		slot_ui.configure_source("player", i)
		if not slot_ui.transfer_requested.is_connected(_on_slot_transfer_requested):
			slot_ui.transfer_requested.connect(_on_slot_transfer_requested)

		var slot_data: Variant = InventoryManager.get_inventory_slot(i)
		var slot_item_id: String = ""
		var slot_count: int = 0

		if slot_data is Dictionary:
			var slot_dict: Dictionary = slot_data as Dictionary
			var raw_item: Variant = slot_dict.get("item", null)

			if raw_item is ItemData:
				slot_item_id = (raw_item as ItemData).item_id
				slot_count = int(slot_dict.get("count", 0))

		player_grid.add_child(slot_ui)
		slot_ui.set_slot_data(slot_item_id, slot_count)
		print("ADDING CHILD")
		print("CHILD ADDED")
	print("DONE")


func _rebuild_container_grid() -> void:
	_clear_children(container_grid)

	for i in range(_active_container.get_slot_count()):
		var slot_node: Node = SLOT_SCENE.instantiate()
		if not (slot_node is ContainerSlotUI):
			continue

		var slot_ui: ContainerSlotUI = slot_node as ContainerSlotUI
		slot_ui.configure_source("container", i)

		if not slot_ui.transfer_requested.is_connected(_on_slot_transfer_requested):
			slot_ui.transfer_requested.connect(_on_slot_transfer_requested)

		var slot_dict: Dictionary = _active_container.get_slot_view(i)
		var slot_item_id: String = str(slot_dict.get("item_id", ""))
		var slot_count: int = int(slot_dict.get("count", 0))

		container_grid.add_child(slot_ui)
		slot_ui.set_slot_data(slot_item_id, slot_count)


func _on_slot_transfer_requested(from_type: String, from_index: int, to_type: String, to_index: int, amount: int) -> void:
	if _active_container == null:
		return
	if amount <= 0:
		return

	var moved: bool = false

	if from_type == "player" and to_type == "container":
		moved = _active_container.transfer_from_player(from_index, to_index, amount)
	elif from_type == "container" and to_type == "player":
		moved = _active_container.transfer_to_player(from_index, amount)

	if moved:
		refresh()


func _on_inventory_changed() -> void:
	if visible:
		refresh()


func _on_container_changed() -> void:
	if visible:
		refresh()


func _on_close_pressed() -> void:
	close_container()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey

		if key_event.pressed \
		and not key_event.echo \
		and key_event.keycode == KEY_ESCAPE:

			close_container()
			get_viewport().set_input_as_handled()


func _close_current_container_binding() -> void:
	if _active_container != null and _active_container.container_changed.is_connected(_on_container_changed):
		_active_container.container_changed.disconnect(_on_container_changed)

	_active_container = null


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
