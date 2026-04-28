extends Node2D

const MapSystem = preload("res://scripts/map_system.gd")
var map_system = MapSystem.new()

# Main scene script

@onready var phase_label: Label = $UI/PhaseLabel
@onready var player_label: Label = $UI/PlayerLabel
@onready var task_label: Label = $UI/TaskLabel
@onready var interaction_prompt: Label = $UI/InteractionPrompt
@onready var players_node: Node = $Players
@onready var telescope: Area2D = $Telescope

func _ready():
	TimeManager.phase_changed.connect(_on_phase_changed)
	TaskManager.task_started.connect(_on_task_started)
	TaskManager.task_completed.connect(_on_task_completed)
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.game_state_synced.connect(_on_game_state_synced)
	telescope.player_nearby.connect(_on_player_nearby)

	# Set initial UI state
	_on_phase_changed(TimeManager.get_current_phase())
	var local_id = multiplayer.get_unique_id()
	player_label.text = "Player: " + str(local_id)

	# Spawn local player
	spawn_player(local_id)

	# Build the TileMap room
	_create_room("outside")

func _create_room(room_id: String = "outside"):
	# Remove old room elements
	for child in get_children():
		if child.name == "Room" or child.name.begins_with("DoorZone_"):
			child.queue_free()

	# Create TileSet
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(64, 64)

	var textures = [
		load("res://assets/tilesets/floor_tile.png"),
		load("res://assets/tilesets/wall.png"),
		load("res://assets/tilesets/door.png"),
		load("res://assets/tilesets/window.png"),
		load("res://assets/tilesets/wood_floor.png")
	]
	for i in textures.size():
		var src = TileSetAtlasSource.new()
		src.texture = textures[i]
		src.texture_region_size = Vector2i(64, 64)
		src.create_tile(Vector2i(0, 0))
		tileset.add_source(src, i)

	var tilemap = TileMap.new()
	tilemap.name = "Room"
	tilemap.tile_set = tileset

	var room_def = map_system.load_room(room_id)
	var W = room_def["width"]
	var H = room_def["height"]
	var is_wood = room_def["wood_floor"]
	
	var floor_id = 4 if is_wood else 0

	# Floor tiles (interior)
	for x in range(1, W - 1):
		for y in range(1, H - 1):
			tilemap.set_cell(0, Vector2i(x, y), floor_id, Vector2i(0, 0))

	# Wall tiles (perimeter)
	for x in range(W):
		tilemap.set_cell(0, Vector2i(x, 0), 1, Vector2i(0, 0))
		tilemap.set_cell(0, Vector2i(x, H - 1), 1, Vector2i(0, 0))
	for y in range(1, H - 1):
		tilemap.set_cell(0, Vector2i(0, y), 1, Vector2i(0, 0))
		tilemap.set_cell(0, Vector2i(W - 1, y), 1, Vector2i(0, 0))

	# Door tiles
	for door in room_def["doors"]:
		var pos = door["pos"]
		tilemap.set_cell(0, pos, 2, Vector2i(0, 0))
		# Create an area2D for the door trigger
		var door_area = Area2D.new()
		door_area.name = "DoorZone_" + door["dest"]
		
		# Allow player to collide with door area
		door_area.collision_layer = 1
		door_area.collision_mask = 1 
		
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(60, 60)
		shape.shape = rect
		door_area.position = Vector2(pos.x * 64 + 32, pos.y * 64 + 32)
		door_area.add_child(shape)
		
		door_area.body_entered.connect(_on_door_entered.bind(door["dest"]))
		add_child(door_area)

	add_child(tilemap)
	move_child(tilemap, 0)

func _on_door_entered(body: Node2D, dest: String):
	if body is CharacterBody2D and body.is_multiplayer_authority():
		rpc("change_room", dest)

@rpc("call_local", "reliable")
func change_room(dest: String):
	_create_room(dest)
	# Center players slightly
	for player in players_node.get_children():
		if player is CharacterBody2D:
			player.position = Vector2(100 + player.player_id * 50, 100)


func spawn_player(id: int):
	var player_scene = load("res://scenes/player.tscn")
	var player = player_scene.instantiate()
	player.name = "Player" + str(id)
	player.player_id = id
	player.position = Vector2(100 + id * 50, 100)
	players_node.add_child(player)
	player.set_multiplayer_authority(id)

func _on_player_connected(id: int):
	spawn_player(id)

func _on_player_disconnected(id: int):
	var player = players_node.get_node_or_null("Player" + str(id))
	if player:
		player.queue_free()

func _on_game_state_synced(state: Dictionary):
	# Spawn already-connected players sent by the server on late join
	for id in state["players"]:
		if not players_node.has_node("Player" + str(id)):
			spawn_player(id)

func _on_phase_changed(phase: String):
	phase_label.text = "Phase: " + phase

func _on_player_nearby(is_near: bool):
	interaction_prompt.visible = is_near

func _on_task_started(player_id: int, task_id: String):
	if player_id == multiplayer.get_unique_id():
		if task_id == "observe":
			task_label.text = "Task: Observing..."
		else:
			task_label.text = "Task: " + task_id

func _on_task_completed(player_id: int, _task_id: String):
	if player_id == multiplayer.get_unique_id():
		task_label.text = "Task: Done"
		await get_tree().create_timer(2.0).timeout
		if TaskManager.get_active_task(player_id) == "":
			task_label.text = "Task: none"

func _input(event):
	if event.is_action_pressed("interact"):
		if telescope.interacting_player == multiplayer.get_unique_id():
			telescope.interact()
