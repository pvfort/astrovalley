extends Node2D

# Main scene script

@onready var phase_label: Label = $UI/PhaseLabel
@onready var player_label: Label = $UI/PlayerLabel
@onready var task_label: Label = $UI/TaskLabel
@onready var players_node: Node = $Players

func _ready():
	TimeManager.phase_changed.connect(_on_phase_changed)
	TaskManager.task_started.connect(_on_task_started)
	TaskManager.task_completed.connect(_on_task_completed)
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	
	# Set initial
	_on_phase_changed(TimeManager.get_current_phase())
	var local_id = multiplayer.get_unique_id()
	player_label.text = "Player: " + str(local_id)
	
	# Spawn local player
	spawn_player(local_id)

func spawn_player(id: int):
	var player_scene = load("res://scenes/player.tscn")
	var player = player_scene.instantiate()
	player.name = "Player" + str(id)
	player.player_id = id
	player.position = Vector2(100 + id * 50, 100)
	players_node.add_child(player)
	
	if id == multiplayer.get_unique_id():
		player.set_multiplayer_authority(id)

func _on_player_connected(id: int):
	spawn_player(id)

func _on_player_disconnected(id: int):
	var player = players_node.get_node("Player" + str(id))
	if player:
		player.queue_free()

func _on_phase_changed(phase: String):
	phase_label.text = "Phase: " + phase

func _on_task_started(player_id: int, task_id: String):
	if player_id == multiplayer.get_unique_id():
		task_label.text = "Task: " + task_id

func _on_task_completed(player_id: int, task_id: String):
	if player_id == multiplayer.get_unique_id():
		task_label.text = "Task: none"

# For interaction, perhaps on input
func _input(event):
	if event.is_action_pressed("ui_select"):  # Space
		var telescope = $Telescope
		if telescope.interacting_player == multiplayer.get_unique_id():
			telescope.interact()