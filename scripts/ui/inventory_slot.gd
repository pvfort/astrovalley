extends PanelContainer

@onready var icon_rect: TextureRect = $MarginContainer/VBoxContainer/Icon
@onready var item_name_label: Label = $MarginContainer/VBoxContainer/ItemName
@onready var stack_label: Label = $MarginContainer/VBoxContainer/Stack

func set_slot_data(slot_data: Variant) -> void:
    if slot_data == null:
        icon_rect.texture = null
        item_name_label.text = ""
        stack_label.text = ""
        tooltip_text = ""
        return

    var raw_item: Variant = slot_data.get("item")
    var item: ItemData = raw_item if raw_item is ItemData else null
    var count: int = int(slot_data.get("count", 1))

    if item == null:
        icon_rect.texture = null
        item_name_label.text = ""
        stack_label.text = ""
        tooltip_text = ""
        return

    icon_rect.texture = item.icon
    item_name_label.text = item.display_name
    stack_label.text = str(count) if count > 1 else ""
    tooltip_text = "%s\n%s" % [item.display_name, item.description]
