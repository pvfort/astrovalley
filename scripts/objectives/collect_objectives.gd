class_name CollectItemObjective
extends Objective

@export var target_item: String
@export var required_amount := 1

var current_amount := 0

func activate():
	EventBus.item_collected.connect(_on_item_collected)

func cleanup():
	if EventBus.item_collected.is_connected(_on_item_collected):
		EventBus.item_collected.disconnect(_on_item_collected)

func _on_item_collected(player_id, item_id, amount):
	if item_id != target_item:
		return

	current_amount += amount

	if current_amount >= required_amount:
		completed = true
