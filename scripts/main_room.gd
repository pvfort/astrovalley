extends Node2D

@export var room_path: String
@export var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")

@onready var level0 = $Level0
@onready var level1 = $Level1
@onready var player_spawn: Marker2D = get_node_or_null("PlayerSpawn")

@onready var levels = [
	$Level0,
	$Level1
]

var current_level: int = 0
var is_transitioning: bool = false
var player: CharacterBody2D = null

func _ready():
	add_to_group("main_room")

	if room_path == "":
		push_error("No room_path set for MainRoom")
		return

	var data = load_room(room_path)
	build_levels(data)
	_spawn_player()

	set_current_level(0)


# --------------------------------------------------
# Load JSON
# --------------------------------------------------
func load_room(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open room file: " + path)
		return {}

	return JSON.parse_string(file.get_as_text())


# --------------------------------------------------
# Build all levels
# --------------------------------------------------
func build_levels(data: Dictionary) -> void:
	if data.is_empty():
		return

	if not data.has("levels"):
		push_error("Main room JSON must contain 'levels'")
		return

	for i in range(data["levels"].size()):
		if i >= levels.size():
			push_warning("No scene for level index %d" % i)
			continue

		var level_data = data["levels"][i]

		var level_node = levels[i]
		level_node.level_index = i
		level_node.room_path = room_path

		level_node.build_level(level_data)

		# build stairs AFTER tiles
		if data.has("stairs"):
			level_node.build_stairs(data["stairs"], i)


# --------------------------------------------------
# Level switching (internal)
# --------------------------------------------------
func set_current_level(lvl: int) -> void:
	if lvl < 0 or lvl >= levels.size():
		return

	current_level = lvl

	if player != null:
		if player.has_method("set_current_level"):
			player.set_current_level(lvl)

	for i in range(levels.size()):
		var active = (i == lvl)
		levels[i].set_active(active)


# --------------------------------------------------
# Public API (used by stairs)
# --------------------------------------------------
func change_level(to_level: int, target_pos: Vector2i) -> void:
	if is_transitioning:
		return

	is_transitioning = true

	set_current_level(to_level)

	if player != null:
		var tilemap = levels[to_level].tilemap
		var world_pos = tilemap.to_global(tilemap.map_to_local(target_pos))
		player.global_position = world_pos
		player.target_position = world_pos
		player.is_moving = false

	# small delay before allowing next transition
	await get_tree().create_timer(0.2).timeout

	is_transitioning = false


func _spawn_player() -> void:
	if player != null:
		return
	if player_scene == null:
		push_error("No player scene configured on MainRoom")
		return

	var spawned_player = player_scene.instantiate()
	if not (spawned_player is CharacterBody2D):
		push_error("Configured player scene must inherit CharacterBody2D")
		spawned_player.queue_free()
		return

	player = spawned_player
	player.name = "Player"
	add_child(player)

	if player_spawn != null:
		player.global_position = player_spawn.global_position
