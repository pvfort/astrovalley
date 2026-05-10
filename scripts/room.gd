extends Node2D

@export var room_path: String
@export var level_index: int = 0

@onready var tilemap = $TileMap

const FLOOR_LAYER      = 0
const WALL_BOTTOM_LAYER = 1
const WALL_TOP_LAYER    = 2
const DOOR_LAYER        = 3

const FLOOR_TERRAIN_SET = 0
const FLOOR_TERRAIN_ID  = 0

# Same terrain set, different tiles inside it
const WALL_TERRAIN_SET      = 1
const WALL_BOTTOM_TERRAIN_ID = 0
const WALL_TOP_TERRAIN_ID    = 1   # <-- your mirrored tiles

const DOOR_ATLAS_COORDS  = Vector2i(0, 2)
const STAIR_ATLAS_COORDS = Vector2i(2, 7)
const DOOR_INTERACTABLE_SCENE = preload("res://scenes/world/DoorInteractable.tscn")

const TILE_SIZE = 32


func set_active(active: bool):
	print("Level", level_index, "active:", active)
	visible = active
	set_process(active)
	set_physics_process(active)
	set_process_input(active)


# --------------------------------------------------
# Build tiles
# --------------------------------------------------
func build_level(data: Dictionary) -> void:
	if data.is_empty():
		print("Empty level data")
		return

	print("Building level:", level_index)

	tilemap.clear()
	_clear_door_interactables()

	var size = Vector2i(data["size"][0], data["size"][1])

	var wall_base_positions: Array[Vector2i] = []
	var wall_top_positions: Array[Vector2i]  = []
	var floor_positions: Array[Vector2i] = []
	var has_doors = data.has("doors")

	# --------------------------------------------------
	# PASS 1: classify
	# --------------------------------------------------
	for y in range(size.y):
		for x in range(size.x):
			var pos = Vector2i(x, y)

			# FLOOR
			if data["floor_grid"][y][x] == 1:
				floor_positions.append(pos)

			# WALL
			if data["wall_grid"][y][x] == 1:

				var is_wall_below = (y + 1 < size.y and data["wall_grid"][y + 1][x] == 1)

				# bottom-most wall tile
				if not is_wall_below:
					wall_base_positions.append(pos)

					# determine if this is horizontal (top/bottom/corner)
					var left  = (x > 0 and data["wall_grid"][y][x - 1] == 1)
					var right = (x + 1 < size.x and data["wall_grid"][y][x + 1] == 1)

					if left or right:
						wall_top_positions.append(pos + Vector2i(0, -1))

	print("Floor:", floor_positions.size())
	print("Wall bottom:", wall_base_positions.size())
	print("Wall top:", wall_top_positions.size())

	# --------------------------------------------------
	# FLOOR
	# --------------------------------------------------
	tilemap.set_cells_terrain_connect(
		FLOOR_LAYER,
		floor_positions,
		FLOOR_TERRAIN_SET,
		FLOOR_TERRAIN_ID
	)

	# --------------------------------------------------
	# WALL BOTTOM (real terrain)
	# --------------------------------------------------
	tilemap.set_cells_terrain_connect(
		WALL_BOTTOM_LAYER,
		wall_base_positions,
		WALL_TERRAIN_SET,
		WALL_BOTTOM_TERRAIN_ID
	)

	# --------------------------------------------------
	# WALL TOP (mirrored terrain, separate layer)
	# --------------------------------------------------
	tilemap.set_cells_terrain_connect(
		WALL_TOP_LAYER,
		wall_top_positions,
		WALL_TERRAIN_SET,
		WALL_TOP_TERRAIN_ID
	)

	# --------------------------------------------------
	# DOORS (2 tiles tall)
	# --------------------------------------------------
	if has_doors:
		for y in range(size.y):
			for x in range(size.x):
				if data["doors"][y][x] == 1:
					var pos = Vector2i(x, y)

					tilemap.set_cell(DOOR_LAYER, pos, 0, DOOR_ATLAS_COORDS)
					tilemap.set_cell(
						DOOR_LAYER,
						pos + Vector2i(0, -1),
						0,
						DOOR_ATLAS_COORDS + Vector2i(0, -1)
					)
					_create_door_interactable(pos)


func _clear_door_interactables() -> void:
	var container := get_node_or_null("Doors")
	if container == null:
		container = Node2D.new()
		container.name = "Doors"
		add_child(container)

	for child in container.get_children():
		child.queue_free()


func _create_door_interactable(pos: Vector2i) -> void:
	var container := get_node("Doors")
	var door := DOOR_INTERACTABLE_SCENE.instantiate()
	var world_pos := tilemap.to_global(tilemap.map_to_local(pos))
	door.global_position = world_pos
	door.door_tile_position = pos
	door.door_id = "level_%d_%d_%d" % [level_index, pos.x, pos.y]
	container.add_child(door)


# --------------------------------------------------
# Stairs (unchanged)
# --------------------------------------------------
func build_stairs(stairs: Array, current_level: int):
	for stair in stairs:
		var from = stair["from"]
		var to   = stair["to"]

		if from["level"] != current_level and to["level"] != current_level:
			continue

		var path = get_stair_path(from, to)

		for pos in path:
			draw_stair(pos)

		if from["level"] == current_level:
			create_stair_area(
				Vector2i(from["x"], from["y"]),
				to["level"],
				Vector2i(to["x"], to["y"])
			)

		if to["level"] == current_level:
			create_stair_area(
				Vector2i(to["x"], to["y"]),
				from["level"],
				Vector2i(from["x"], from["y"])
			)


func get_stair_path(from: Dictionary, to: Dictionary) -> Array[Vector2i]:
	var path: Array[Vector2i] = []

	var x1 = from["x"]
	var y1 = from["y"]
	var x2 = to["x"]
	var y2 = to["y"]

	if x1 == x2:
		for y in range(min(y1, y2), max(y1, y2) + 1):
			path.append(Vector2i(x1, y))
	elif y1 == y2:
		for x in range(min(x1, x2), max(x1, x2) + 1):
			path.append(Vector2i(x, y1))
	else:
		push_warning("Diagonal stairs not supported")

	return path


func draw_stair(pos: Vector2i):
	tilemap.set_cell(FLOOR_LAYER, pos, 0, STAIR_ATLAS_COORDS)


# --------------------------------------------------
# Stair trigger
# --------------------------------------------------
func create_stair_area(pos: Vector2i, target_level: int, target_pos: Vector2i):
	var area = Area2D.new()

	area.collision_layer = 2
	area.collision_mask = 1

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(TILE_SIZE, TILE_SIZE)
	collision.shape = shape
	area.add_child(collision)

	var global_pos = tilemap.to_global(tilemap.map_to_local(pos))
	area.global_position = global_pos

	area.set_meta("to_level", target_level)
	area.set_meta("target_pos", target_pos)

	add_child(area)

	area.body_entered.connect(_on_stair_entered.bind(area))


# --------------------------------------------------
# Interaction
# --------------------------------------------------
func _on_stair_entered(body, area):
	var main = get_tree().get_first_node_in_group("main_room")
	if main == null:
		return

	var to_level   = area.get_meta("to_level")
	var target_pos = area.get_meta("target_pos")

	main.change_level(to_level, target_pos)
