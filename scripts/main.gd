extends Node2D

const MapSystem = preload("res://scripts/map_system.gd")
const QUEST_NPC_SCENE = preload("res://scenes/resources/QuestNpcEntity.tscn")
const PROFESSORS_DATA_PATH := "res://data/professors.json"
const NPC_SPAWNS_DATA_PATH := "res://data/npc_spawns.json"
const ROOM_ENTITIES_DATA_PATH := "res://data/room_entities.json"
var map_system = MapSystem.new()

# Optional UI references


@onready var players_node: Node = $Players

var current_room_id: String = "institute"
var furniture_container: Node2D = null
var _furniture_containers_by_room: Dictionary = {}
var room_entities_container: Node2D = null
var _room_entities_containers_by_room: Dictionary = {}

func _ready():

	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.game_state_synced.connect(_on_game_state_synced)


	var local_id = multiplayer.get_unique_id()

	# Spawn local player
	spawn_player(local_id)

	_activate_furniture_container(current_room_id)

	# Build the TileMap room
	_create_room("institute")

func _create_room(room_id: String = "institute"):
	current_room_id = room_id

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
	_activate_furniture_container(current_room_id)
	_activate_room_entities_container(current_room_id)

	if SaveManager != null:
		SaveManager.restore_room_furniture(current_room_id, furniture_container)
	elif FurnitureSaveManager != null:
		FurnitureSaveManager.load_room_furniture(furniture_container, current_room_id)

	_populate_room_entities(current_room_id)
	_populate_room_npcs(current_room_id)
	_emit_room_entered(current_room_id)


func _activate_furniture_container(room_id: String) -> void:
	if furniture_container != null and is_instance_valid(furniture_container) and furniture_container.get_parent() == self:
		remove_child(furniture_container)

	var existing: Variant = _furniture_containers_by_room.get(room_id, null)
	if existing is Node2D and is_instance_valid(existing):
		furniture_container = existing as Node2D
	else:
		furniture_container = Node2D.new()
		furniture_container.name = "Furniture"
		_furniture_containers_by_room[room_id] = furniture_container

	if furniture_container.get_parent() == null:
		add_child(furniture_container)

	move_child(furniture_container, get_child_count() - 1)


func _activate_room_entities_container(room_id: String) -> void:
	if room_entities_container != null and is_instance_valid(room_entities_container) and room_entities_container.get_parent() == self:
		remove_child(room_entities_container)

	var existing: Variant = _room_entities_containers_by_room.get(room_id, null)
	if existing is Node2D and is_instance_valid(existing):
		room_entities_container = existing as Node2D
	else:
		room_entities_container = Node2D.new()
		room_entities_container.name = "RoomEntities"
		_room_entities_containers_by_room[room_id] = room_entities_container

	if room_entities_container.get_parent() == null:
		add_child(room_entities_container)

	if players_node != null and players_node.get_parent() == self:
		move_child(room_entities_container, players_node.get_index())
	else:
		move_child(room_entities_container, get_child_count() - 1)


func get_current_room_id() -> String:
	return current_room_id


func get_room_tilemap() -> TileMap:
	return get_node_or_null("Room")


func get_furniture_container() -> Node2D:
	_activate_furniture_container(current_room_id)
	return furniture_container


func _populate_room_npcs(room_id: String) -> void:
	if furniture_container == null:
		return

	if bool(furniture_container.get_meta("npcs_initialized", false)):
		return

	var entries := _build_npc_spawn_entries()
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant as Dictionary
		if str(entry.get("room_id", "")) != room_id:
			continue
		_spawn_quest_npc(entry)

	furniture_container.set_meta("npcs_initialized", true)


func _populate_room_entities(room_id: String) -> void:
	if room_entities_container == null:
		return

	if bool(room_entities_container.get_meta("entities_initialized", false)):
		return

	for entry_variant in _load_json_array(ROOM_ENTITIES_DATA_PATH):
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant as Dictionary
		if str(entry.get("room_id", "")) != room_id:
			continue
		_spawn_room_entity(entry)

	room_entities_container.set_meta("entities_initialized", true)


func _spawn_room_entity(entry: Dictionary) -> void:
	if room_entities_container == null:
		return

	var scene_path := str(entry.get("scene_path", ""))
	if scene_path.is_empty():
		return

	var packed := load(scene_path)
	if not (packed is PackedScene):
		return

	var instance: Node = (packed as PackedScene).instantiate()
	if instance == null:
		return

	var entry_name := str(entry.get("name", "")).strip_edges()
	if not entry_name.is_empty():
		instance.name = entry_name

	var position_variant: Variant = entry.get("position", [])
	if instance is Node2D and position_variant is Array and (position_variant as Array).size() >= 2:
		var position_values := position_variant as Array
		(instance as Node2D).position = Vector2(float(position_values[0]), float(position_values[1]))

	room_entities_container.add_child(instance)


func _spawn_quest_npc(entry: Dictionary) -> void:
	if QUEST_NPC_SCENE == null or furniture_container == null:
		return

	var npc := QUEST_NPC_SCENE.instantiate()
	if npc == null:
		return

	var component: Node = npc.get_node_or_null("QuestNpcComponent")
	if component != null:
		component.set("npc_id", str(entry.get("npc_id", "")))
		component.set("npc_name", str(entry.get("name", "Professor")))
		component.set("npc_role", str(entry.get("role", "professor")))
		component.set("dialogue_line", str(entry.get("dialogue_line", "")))

	var position_variant: Variant = entry.get("position", [])
	if position_variant is Array and (position_variant as Array).size() >= 2:
		var position_values := position_variant as Array
		npc.position = Vector2(float(position_values[0]), float(position_values[1]))

	npc.name = str(entry.get("npc_id", "QuestNpc"))
	furniture_container.add_child(npc)


func _build_npc_spawn_entries() -> Array:
	var entries: Array = []
	entries.append_array(_load_json_array(NPC_SPAWNS_DATA_PATH))

	for professor_entry_variant in _load_json_array(PROFESSORS_DATA_PATH):
		if not (professor_entry_variant is Dictionary):
			continue
		var professor_entry: Dictionary = professor_entry_variant as Dictionary
		var office_number := str(professor_entry.get("office_number", "")).strip_edges()
		var office_room := office_number if office_number.begins_with("office_") else "office_%s" % office_number
		entries.append({
			"npc_id": str(professor_entry.get("npc_id", "")),
			"name": str(professor_entry.get("name", "Professor")),
			"role": "professor",
			"room_id": office_room,
			"position": [320, 224],
			"dialogue_line": "I have teaching and research tasks posted on the task board.",
		})

	return entries


func _load_json_array(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = SaveSerializer.parse_save_data(file.get_as_text())
	if parsed is Array:
		return parsed as Array
	return []


func _emit_room_entered(room_id: String) -> void:
	if EventBus == null or not EventBus.has_signal("location_entered"):
		return
	var player_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	EventBus.location_entered.emit(player_id, room_id)

func _on_door_entered(body: Node2D, dest: String):
	if body is CharacterBody2D and body.is_multiplayer_authority():
		rpc("change_room", dest)

@rpc("call_local", "reliable")
func change_room(dest: String):
	_create_room(dest)
	# Center players slightly
	for player in players_node.get_children():
		if player is CharacterBody2D:
			var spawn_position := Vector2(100 + player.player_id * 50, 100)
			player.position = spawn_position
			if "target_position" in player:
				player.target_position = spawn_position
			if "is_moving" in player:
				player.is_moving = false
			if "velocity" in player:
				player.velocity = Vector2.ZERO


func spawn_player(id: int):

	var player_scene = preload(
		"res://scenes/player/Player.tscn"
	)

	var player = player_scene.instantiate()

	player.name = "Player" + str(id)

	player.player_id = id

	player.set_multiplayer_authority(id)

	player.position = Vector2(
		100 + id * 50,
		100
	)

	if GameManager != null and GameManager.has_method("add_player"):
		GameManager.add_player(id, "Player" + str(id))

	players_node.add_child(player)

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


func spawn_room_entities(room_id: String):
	_activate_room_entities_container(room_id)
	_populate_room_entities(room_id)

func spawn_item(item_data: ItemData, position: Vector2):
	var scene = load("res://scenes/items/ItemEntity.tscn")
	var item = scene.instantiate()

	item.set_item_data(item_data)
	item.global_position = position

	add_child(item)


func save_state() -> Dictionary:
	return {
		"current_room_id": current_room_id,
	}


func load_state(data: Dictionary) -> void:
	var room_id: String = str(data.get("current_room_id", current_room_id))
	if room_id.is_empty() or room_id == current_room_id:
		return
	_create_room(room_id)
