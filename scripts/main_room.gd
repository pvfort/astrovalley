extends Node2D

@export var room_path: String
@export var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")

@onready var level0: Node = $Level0
@onready var level1: Node = $Level1
@onready var player_spawn: Marker2D = get_node_or_null("PlayerSpawn")

@onready var levels: Array[Node] = [
$Level0,
$Level1,
]

var current_level: int = 0
var is_transitioning: bool = false
var player: CharacterBody2D = null


func _ready() -> void:
add_to_group("main_room")

if room_path.is_empty():
push_error("No room_path set for MainRoom")
return

var data: Dictionary = load_room(room_path)
build_levels(data)
_spawn_player()
set_current_level(0)


func load_room(path: String) -> Dictionary:
var file: FileAccess = FileAccess.open(path, FileAccess.READ)
if file == null:
push_error("Could not open room file: %s" % path)
return {}

var parsed: Variant = SaveSerializer.parse_save_data(file.get_as_text())
if parsed is Dictionary:
return parsed as Dictionary

push_error("Room JSON must parse to Dictionary: %s" % path)
return {}


func build_levels(data: Dictionary) -> void:
if data.is_empty():
return

var levels_variant: Variant = data.get("levels", null)
if not (levels_variant is Array):
push_error("Main room JSON must contain 'levels' array")
return

var level_entries: Array = levels_variant as Array
for i in range(level_entries.size()):
if i >= levels.size():
push_warning("No scene for level index %d" % i)
continue

var level_node: Node = levels[i]
var level_data: Variant = level_entries[i]
level_node.level_index = i
level_node.room_path = room_path
level_node.build_level(level_data)

var stairs_variant: Variant = data.get("stairs", null)
if stairs_variant is Array:
level_node.build_stairs(stairs_variant, i)


func set_current_level(lvl: int) -> void:
if lvl < 0 or lvl >= levels.size():
return

current_level = lvl

if player != null and player.has_method("set_current_level"):
player.set_current_level(lvl)

for i in range(levels.size()):
var active: bool = i == lvl
levels[i].set_active(active)


func change_level(to_level: int, target_pos: Vector2i) -> void:
if is_transitioning:
return

is_transitioning = true
set_current_level(to_level)

if player != null:
var level_node: Node = levels[to_level]
var tilemap: TileMap = level_node.tilemap
var world_pos: Vector2 = tilemap.to_global(tilemap.map_to_local(target_pos))
player.global_position = world_pos
player.target_position = world_pos
player.is_moving = false

await get_tree().create_timer(0.2).timeout
is_transitioning = false


func _spawn_player() -> void:
if player != null:
return
if player_scene == null:
push_error("No player scene configured on MainRoom")
return

var spawned_player: Node = player_scene.instantiate()
if not (spawned_player is CharacterBody2D):
push_error("Configured player scene must inherit CharacterBody2D")
spawned_player.queue_free()
return

player = spawned_player as CharacterBody2D
player.name = "Player"
add_child(player)

if player_spawn != null:
player.global_position = player_spawn.global_position
