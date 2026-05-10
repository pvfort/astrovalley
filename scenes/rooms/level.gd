extends Node2D

@onready var tilemap = $TileMap

const FLOOR_LAYER = 0
const WALL_LAYER  = 1

const FLOOR_SOURCE_ID = 0
const FLOOR_ATLAS_COORDS = Vector2i(1, 0)

const WALL_TERRAIN_SET = 0
const WALL_TERRAIN_ID  = 0

const DOOR_ATLAS_COORDS = Vector2i(0, 0)


func build(data: Dictionary) -> void:
	if data.is_empty():
		return

	tilemap.clear()

	var size = Vector2i(data["size"][0], data["size"][1])
	var wall_positions: Array[Vector2i] = []

	var has_doors = data.has("doors")

	for y in range(size.y):
		for x in range(size.x):
			var pos = Vector2i(x, y)

			# --- FLOOR ---
			if data["floor_grid"][y][x] == 1:
				tilemap.set_cell(FLOOR_LAYER, pos, FLOOR_SOURCE_ID, FLOOR_ATLAS_COORDS)

			# --- WALL TERRAIN INPUT ---
			var is_wall = data["wall_grid"][y][x] == 1
			var is_door = has_doors and data["doors"][y][x] == 1

			# IMPORTANT: exclude doors from terrain
			if is_wall and not is_door:
				wall_positions.append(pos)

	# --- TERRAIN FIRST ---
	tilemap.set_cells_terrain_connect(
		WALL_LAYER,
		wall_positions,
		WALL_TERRAIN_SET,
		WALL_TERRAIN_ID
	)

	# --- DOORS AFTER ---
	if has_doors:
		for y in range(size.y):
			for x in range(size.x):
				if data["doors"][y][x] == 1:
					var pos = Vector2i(x, y)
					tilemap.set_cell(WALL_LAYER, pos, 0, DOOR_ATLAS_COORDS)
