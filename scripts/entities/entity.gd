class_name Entity
extends Node2D

var components: Array = []


func _ready() -> void:
	_refresh_components()


func _refresh_components() -> void:
	components.clear()

	for child in get_children():
		if child.has_method("interact"):
			components.append(child)


func interact(player: PlayerCharacter) -> void:
	for c in components:
		c.interact(player)
