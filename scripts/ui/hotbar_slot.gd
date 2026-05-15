extends PanelContainer

signal slot_clicked(slot_index: int)

@onready var icon_rect: TextureRect = $MarginContainer/Icon
@onready var stack_label: Label = $StackLabel
@onready var cooldown_overlay: ColorRect = $CooldownOverlay

var slot_index: int = -1
var _is_selected: bool = false


func _ready() -> void:
cooldown_overlay.visible = false
_set_selected_style()


func set_slot_data(slot_data: Variant) -> void:
if slot_data == null:
icon_rect.texture = null
stack_label.text = ""
tooltip_text = ""
return

if not (slot_data is Dictionary):
icon_rect.texture = null
stack_label.text = ""
tooltip_text = ""
return

var slot_dict := slot_data as Dictionary
var raw_item: Variant = slot_dict.get("item")
var item: ItemData = raw_item if raw_item is ItemData else null
var count: int = int(slot_dict.get("count", 1))

if item == null:
icon_rect.texture = null
stack_label.text = ""
tooltip_text = ""
return

icon_rect.texture = item.icon
stack_label.text = str(count) if count > 1 else ""
tooltip_text = "%s\n%s" % [item.display_name, item.description]


func set_selected(is_selected: bool) -> void:
if _is_selected == is_selected:
return
_is_selected = is_selected
_set_selected_style()


func _set_selected_style() -> void:
var style := StyleBoxFlat.new()
style.bg_color = Color(0.10, 0.10, 0.12, 0.85)
style.border_color = Color(1.0, 0.9, 0.45, 1.0) if _is_selected else Color(0.28, 0.28, 0.34, 1.0)
style.border_width_left = 2
style.border_width_top = 2
style.border_width_right = 2
style.border_width_bottom = 2
style.corner_radius_top_left = 1
style.corner_radius_top_right = 1
style.corner_radius_bottom_right = 1
style.corner_radius_bottom_left = 1
add_theme_stylebox_override("panel", style)


func _gui_input(event: InputEvent) -> void:
if event is InputEventMouseButton \
and event.pressed \
and event.button_index == MOUSE_BUTTON_LEFT:
slot_clicked.emit(slot_index)
