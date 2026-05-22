extends Area2D
class_name MugEntity

@export var item_data: ItemData

func interact(player: PlayerCharacter) -> void:
	for child in get_children():
		if child.has_method("interact"):
			child.interact(player)
