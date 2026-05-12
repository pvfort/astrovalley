extends Interactable
class_name DoorInteractable

signal transition_requested(door_id: String, destination_scene: String, destination_marker: StringName, tile_position: Vector2i)

@export var door_id: String = ""
@export var destination_scene: String = ""
@export var destination_marker: StringName = &""
@export var door_tile_position: Vector2i = Vector2i.ZERO

func _ready() -> void:
	super._ready()
	interaction_name = &"Door"
	interaction_priority = max(interaction_priority, Interactable.PRIORITY_DOOR)

func interact(player: Node) -> void:
	if not can_interact(player):
		return

	var player_name := player.name if player != null else "Unknown"
	print("[Door] Interact: id=%s tile=%s player=%s destination_scene=%s destination_marker=%s" % [
		door_id,
		door_tile_position,
		player_name,
		destination_scene,
		destination_marker,
	])

	# Placeholder transition hook for future scene routing.
	transition_requested.emit(door_id, destination_scene, destination_marker, door_tile_position)
