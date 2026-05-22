extends Area2D

func interact(player: PlayerCharacter) -> void:
	for child in get_children():
		if child.has_method("interact"):
			child.interact(player)
