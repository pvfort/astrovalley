class_name ContainerSlot
extends PanelContainer

@onready var icon_rect: TextureRect = $MarginContainer/VBoxContainer/Icon
@onready var item_name_label: Label = $MarginContainer/VBoxContainer/ItemName
@onready var stack_label: Label = $MarginContainer/VBoxContainer/Stack

var source_type: String = ""
var slot_index: int = -1
var _host_ui: ContainerUI = null


func configure(host_ui: ContainerUI, source: String, index: int) -> void:
	_host_ui = host_ui
	source_type = source
	slot_index = index


func set_slot_data(slot_data: Variant) -> void:
	if slot_data == null:
		icon_rect.texture = null
		item_name_label.text = ""
		stack_label.text = ""
		tooltip_text = ""
		return

	var item := slot_data.get("item", null) as ItemData
	if item == null:
		icon_rect.texture = null
		item_name_label.text = ""
		stack_label.text = ""
		tooltip_text = ""
		return

	var count := int(slot_data.get("count", 1))
	icon_rect.texture = item.icon
	item_name_label.text = item.display_name
	stack_label.text = str(count) if count > 1 else ""
	tooltip_text = "%s\n%s" % [item.display_name, item.description]


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _host_ui == null:
		return null
	if not _host_ui.can_drag_from(source_type, slot_index):
		return null

	var drag_data := _host_ui.build_drag_data(source_type, slot_index)
	if drag_data.is_empty():
		return null

	var preview := duplicate() as Control
	if preview != null:
		preview.modulate = Color(1.0, 1.0, 1.0, 0.85)
		set_drag_preview(preview)
	return drag_data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if _host_ui == null:
		return false
	return _host_ui.can_drop_on_slot(source_type, slot_index, data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _host_ui == null:
		return
	_host_ui.drop_on_slot(source_type, slot_index, data)
