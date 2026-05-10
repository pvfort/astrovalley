extends Node

@export var slot_type: String
# Called when the node enters the scene tree for the first time.
func can_accept(item):
	return item.category == slot_type
