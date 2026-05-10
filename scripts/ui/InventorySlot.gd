extends PanelContainer

@onready var icon = $TextureRect
@onready var stack_label = $StackLabel

var item_data = null

func set_item(item):
	item_data = item

	if item != null:
		icon.texture = item.icon
