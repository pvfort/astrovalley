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

    var item: ItemData = slot_data.get("item")
    var count: int = int(slot_data.get("count", 1))

    if item == null:
        icon_rect.texture = null
        item_name_label.text = ""
        stack_label.text = ""
        tooltip_text = ""
        return

    icon_rect.texture = item.icon
    item_name_label.text = item.name
    stack_label.text = str(count) if count > 1 else ""
    tooltip_text = "%s\n%s" % [item.name, item.description]
