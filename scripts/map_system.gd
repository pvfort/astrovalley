extends Node

const TILE_FLOOR = 0
const TILE_WALL = 1
const TILE_DOOR = 2
const TILE_WINDOW = 3
const TILE_WOOD = 4

var room_defs: Dictionary = {}

const INSTITUTE_ROOM_ID := "institute"
const FIRST_OFFICE_NUMBER := 101
const LAST_OFFICE_NUMBER := 118
const OFFICES_PER_ROW := 9
const OFFICE_WIDTH := 10
const OFFICE_HEIGHT := 8
const INSTITUTE_DOOR_X_OFFSET := 3
const INSTITUTE_DOOR_X_SPACING := 2

func _init() -> void:
	_build_room_defs()

func _build_room_defs() -> void:
	room_defs.clear()

	var institute_width := 24
	var institute_height := 16
	var institute_doors: Array = []

	var office_numbers: Array[int] = []
	for office_number in range(FIRST_OFFICE_NUMBER, LAST_OFFICE_NUMBER + 1):
		office_numbers.append(office_number)

	var max_offices_supported := OFFICES_PER_ROW * 2
	if office_numbers.size() > max_offices_supported:
		push_error("Institute supports up to %d office doors, requested %d" % [max_offices_supported, office_numbers.size()])
		return

	for i in range(office_numbers.size()):
		var office_number = office_numbers[i]
		var office_id = "office_%d" % office_number
		var door_x = INSTITUTE_DOOR_X_OFFSET + (i % OFFICES_PER_ROW) * INSTITUTE_DOOR_X_SPACING
		var door_y = 0 if i < OFFICES_PER_ROW else institute_height - 1

		institute_doors.append({
			"pos": Vector2i(door_x, door_y),
			"dest": office_id
		})

		room_defs[office_id] = {
			"width": OFFICE_WIDTH,
			"height": OFFICE_HEIGHT,
			"wood_floor": true,
			"doors": [{
				"pos": Vector2i(OFFICE_WIDTH / 2, OFFICE_HEIGHT - 1),
				"dest": INSTITUTE_ROOM_ID
			}]
		}

	room_defs[INSTITUTE_ROOM_ID] = {
		"width": institute_width,
		"height": institute_height,
		"wood_floor": false,
		"doors": institute_doors
	}

func load_room(room_id_str):
	return room_defs.get(room_id_str, room_defs[INSTITUTE_ROOM_ID])
