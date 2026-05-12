extends Area2D
class_name CoffeeEntity

@export var item_data: ItemData

func interact(player: PlayerCharacter) -> void:
	print("[COFFEE] interact called by:", player.player_id)

	for child in get_children():
		if child.has_method("interact"):
			child.interact(player)
