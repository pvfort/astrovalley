extends CharacterBody2D

# Player: Handles player movement and interaction

@export var speed: float = 200.0
var player_id: int
var player_name: String = "Player"

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready():
	player_id = multiplayer.get_unique_id()
	player_name = "Player" + str(player_id)
	label.text = player_name

func _physics_process(delta: float):
	if not is_multiplayer_authority():
		return  # Only local player controls
	
	var direction = Vector2.ZERO
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1
	
	velocity = direction.normalized() * speed
	move_and_slide()
	
	# Sync position
	if multiplayer.is_server():
		rpc("sync_position", position)
	else:
		rpc_id(1, "request_sync")

@rpc("authority", "call_local")
func sync_position(pos: Vector2):
	position = pos

@rpc("any_peer", "call_local")
func request_sync():
	if multiplayer.is_server():
		rpc_id(multiplayer.get_remote_sender_id(), "sync_position", position)