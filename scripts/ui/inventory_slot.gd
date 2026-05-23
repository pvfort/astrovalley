extends PanelContainer

signal slot_transfer_requested(from_index: int, to_index: int)

@onready var icon_rect: TextureRect = $MarginContainer/VBoxContainer/Icon
@onready var item_name_label: Label = $MarginContainer/VBoxContainer/ItemName
@onready var stack_label: Label = $MarginContainer/VBoxContainer/Stack

var slot_index: int = -1
var _pending_left_click: bool = false
var _is_dragging: bool = false


func set_slot_data(slot_data: Variant) -> void:

	if slot_data == null:
		icon_rect.texture = null
		item_name_label.text = ""
		stack_label.text = ""
		tooltip_text = ""
		_pending_left_click = false
		return

	var raw_item: Variant = slot_data.get("item")
	var item: ItemData = raw_item if raw_item is ItemData else null
	var count: int = int(slot_data.get("count", 1))

	if item == null:
		icon_rect.texture = null
		item_name_label.text = ""
		stack_label.text = ""
		tooltip_text = ""
		_pending_left_click = false
		return

	icon_rect.texture = item.icon
	item_name_label.text = item.display_name
	stack_label.text = str(count) if count > 1 else ""
	tooltip_text = "%s\n%s" % [item.display_name, item.description]


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not InventoryManager.is_inventory_open:
		return null

	var slot_data: Variant = InventoryManager.get_inventory_slot(slot_index)

	if not (slot_data is Dictionary):
		return null

	var slot_dict: Dictionary = slot_data as Dictionary
	var raw_item: Variant = slot_dict.get("item", null)
	if not (raw_item is ItemData):
		return null

	_pending_left_click = false
	_is_dragging = true

	var item: ItemData = raw_item as ItemData
	var preview_label: Label = Label.new()
	preview_label.text = item.display_name
	set_drag_preview(preview_label)

	return {
		"source_type": "inventory",
		"slot_index": slot_index,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not InventoryManager.is_inventory_open:
		return false
	if not (data is Dictionary):
		return false

	var payload: Dictionary = data as Dictionary
	if str(payload.get("source_type", "")) != "inventory":
		return false

	var from_index: int = int(payload.get("slot_index", -1))
	return from_index >= 0


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return

	var payload: Dictionary = data as Dictionary
	var from_index: int = int(payload.get("slot_index", -1))
	if from_index < 0:
		return

	slot_transfer_requested.emit(from_index, slot_index)


func _gui_input(event: InputEvent) -> void:

	if not InventoryManager.is_inventory_open:
		return

	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		_pending_left_click = true
		return

	if not _pending_left_click:
		return

	_pending_left_click = false

	if _is_dragging:
		_is_dragging = false
		return

	_handle_primary_click()


func _handle_primary_click() -> void:
	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		return

	var slot_data: Variant = InventoryManager.get_inventory_slot(slot_index)
	if slot_data != null:
		var raw_item: Variant = slot_data.get("item")
		var item: ItemData = raw_item if raw_item is ItemData else null
		if item != null and item.placeable and PlacementManager != null:
			var started := PlacementManager.begin_placement(item, slot_index)
			if started:
				return

	InventoryManager.use_item(slot_index, player)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_is_dragging = false
		_pending_left_click = false
