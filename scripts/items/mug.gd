extends Area2D
class_name MugEntity

@export var item_data: ItemData

func interact(player: PlayerCharacter) -> void:
	print("[MUG] interact called by:", player.player_id)

	for child in get_children():
		if child.has_method("interact"):
			child.interact(player)
