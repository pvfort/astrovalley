extends PanelContainer

@export var slot_type: StringName = &"tool"

@onready var slot_name_label: Label = $MarginContainer/VBoxContainer/SlotName
@onready var icon_rect: TextureRect = $MarginContainer/VBoxContainer/Icon

func _ready() -> void:
    slot_name_label.text = String(slot_type).capitalize()

func set_slot_data(slot_data: Variant) -> void:
    if slot_data == null:
        icon_rect.texture = null
        return

    var raw_item: Variant = slot_data.get("item")
    var item: ItemData = raw_item if raw_item is ItemData else null
    icon_rect.texture = item.icon if item != null else null
