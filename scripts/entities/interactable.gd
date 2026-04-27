extends Area2D

# Interactable: Base class for interactable objects

signal player_nearby(is_near: bool)

@export var resource_name: String = ""
var interacting_player: int = -1

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D):
	if body is CharacterBody2D:
		var pid = body.get("player_id")
		if pid != null:
			interacting_player = pid
			if pid == multiplayer.get_unique_id():
				player_nearby.emit(true)

func _on_body_exited(body: Node2D):
	if body is CharacterBody2D:
		var pid = body.get("player_id")
		if pid != null and pid == interacting_player:
			if pid == multiplayer.get_unique_id():
				player_nearby.emit(false)
			interacting_player = -1

func interact():
	if interacting_player == -1:
		return
	if resource_name == "telescope":
		if multiplayer.is_server():
			ObservationSystem.start_observe(interacting_player)
		else:
			request_interact.rpc_id(1, interacting_player)

@rpc("any_peer")
func request_interact(player_id: int):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == player_id and interacting_player == player_id and resource_name == "telescope":
		ObservationSystem.start_observe(player_id)
