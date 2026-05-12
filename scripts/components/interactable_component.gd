class_name InteractableComponent
extends Node

enum InteractionMode { PRIMARY, PICKUP }

@export var priority := 0
@export var allowed_mode := InteractionMode.PRIMARY



func can_interact(_player: PlayerCharacter) -> bool:
	return true

func interact(_player: PlayerCharacter) -> void:
	pass
