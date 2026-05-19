class_name ContainerSlotUI
extends PanelContainer

signal transfer_requested(from_type: String, from_index: int, to_type: String, to_index: int, amount: int)

@onready var icon_rect: TextureRect = $MarginContainer/VBoxContainer/Icon
@onready var item_name_label: Label = $MarginContainer/VBoxContainer/ItemName
@onready var stack_label: Label = $MarginContainer/VBoxContainer/Stack

var source_type: String = ""
var slot_index: int = -1
var item_id: String = ""
var count: int = 0


func configure_source(next_source_type: String, next_slot_index: int) -> void:
	source_type = next_source_type
	slot_index = next_slot_index


func set_slot_data(next_item_id: String, next_count: int) -> void:
	item_id = next_item_id
	count = max(next_count, 0)

	if item_id.is_empty() or count <= 0:
		icon_rect.texture = null
		item_name_label.text = ""
		stack_label.text = ""
		tooltip_text = ""
		return

	var item: ItemData = null

	if InventoryManager != null and InventoryManager.has_method("_item_by_id"):
		item = InventoryManager._item_by_id(item_id)

	if item != null:
		icon_rect.texture = item.icon
		item_name_label.text = item.display_name
		tooltip_text = "%s\n%s" % [item.display_name, item.description]
	else:
		icon_rect.texture = null
		item_name_label.text = item_id
		tooltip_text = item_id

	stack_label.text = str(count) if count > 1 else ""


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id.is_empty() or count <= 0:
		return null

	var payload: Dictionary = {
		"source_type": source_type,
		"slot_index": slot_index,
		"item_id": item_id,
		"count": count,
	}

	var preview_label: Label = Label.new()
	preview_label.text = item_id
	set_drag_preview(preview_label)

	return payload


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false

	var payload: Dictionary = data as Dictionary

	if not payload.has("source_type"):
		return false
	if not payload.has("slot_index"):
		return false

	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return

	var payload: Dictionary = data as Dictionary
	var from_type: String = str(payload.get("source_type", ""))
	var from_index: int = int(payload.get("slot_index", -1))

	if from_type.is_empty() or from_index < 0:
		return

	transfer_requested.emit(from_type, from_index, source_type, slot_index, 1)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton

	if not mouse_event.pressed:
		return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if item_id.is_empty() or count <= 0:
		return

	var target_type: String = "container" if source_type == "player" else "player"

	transfer_requested.emit(source_type, slot_index, target_type, -1, 1)
