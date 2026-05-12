class_name DoorComponent
extends Node

@export var destination_room: String

func interact(player: PlayerCharacter) -> void:
	if not player.is_multiplayer_authority():
		return

	get_tree().call_group("main_room", "change_room", destination_room)
