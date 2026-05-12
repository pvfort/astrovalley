extends Area2D
class_name Interactable

signal interaction_available_changed(is_available: bool)

@export var interaction_name: StringName = &"Interact"
@export var interaction_priority: int = 0
@export var interaction_enabled: bool = true : set = set_interaction_enabled

var current_player: Node = null

func _ready() -> void:
	monitoring = true
	monitorable = true

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
	var player := area.get_parent()
	if player and player.has_method("get_input_direction"):
		current_player = player
		print("[INTERACTABLE] player in range:", player.name)

func _on_area_exited(area: Area2D) -> void:
	var player := area.get_parent()
	if player == current_player:
		current_player = null
		print("[INTERACTABLE] player left:", player.name)

func set_interaction_enabled(value: bool) -> void:
	interaction_enabled = value
	interaction_available_changed.emit(interaction_enabled)

func can_interact(player: Node) -> bool:
	return interaction_enabled and player == current_player

func interact(player: Node) -> void:
	# IMPORTANT: delegate to components
	for child in get_children():
		if child.has_method("interact"):
			child.interact(player)
