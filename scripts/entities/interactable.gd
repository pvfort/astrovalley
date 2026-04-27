extends Area2D

# Interactable: Base class for interactable objects

@export var resource_name: String = ""
var interacting_player: int = -1

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D):
	if body is CharacterBody2D and body.has_method("get_player_id"):
		interacting_player = body.player_id

func _on_body_exited(body: Node2D):
	if body is CharacterBody2D and body.player_id == interacting_player:
		interacting_player = -1

func interact():
	if interacting_player != -1:
		# Specific interaction, e.g., for telescope
		if resource_name == "telescope":
			ObservationSystem.start_observe(interacting_player)