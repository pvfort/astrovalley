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
const CLASSROOM_ROOM_ID := "classroom"
const COLLOQUIUM_ROOM_ID := "colloquium_room"
const IT_OFFICE_ROOM_ID := "it_office"
const LIBRARY_ROOM_ID := "library"
const CAFE_ROOM_ID := "coffee_shop"
const OBSERVATORY_ROOM_ID := "observatory_annex"

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

	institute_doors.append_array([
		{"pos": Vector2i(1, 0), "dest": CLASSROOM_ROOM_ID},
		{"pos": Vector2i(22, 0), "dest": COLLOQUIUM_ROOM_ID},
		{"pos": Vector2i(21, 0), "dest": CAFE_ROOM_ID},
		{"pos": Vector2i(1, institute_height - 1), "dest": IT_OFFICE_ROOM_ID},
		{"pos": Vector2i(22, institute_height - 1), "dest": LIBRARY_ROOM_ID},
		{"pos": Vector2i(21, institute_height - 1), "dest": OBSERVATORY_ROOM_ID},
	])

	room_defs[CLASSROOM_ROOM_ID] = _room_with_return_door(16, 12, true, Vector2i(8, 11))
	room_defs[COLLOQUIUM_ROOM_ID] = _room_with_return_door(20, 14, false, Vector2i(10, 13))
	room_defs[IT_OFFICE_ROOM_ID] = _room_with_return_door(12, 10, true, Vector2i(6, 9))
	room_defs[LIBRARY_ROOM_ID] = _room_with_return_door(18, 12, true, Vector2i(9, 11))
	room_defs[CAFE_ROOM_ID] = _room_with_return_door(14, 10, true, Vector2i(7, 9))
	room_defs[OBSERVATORY_ROOM_ID] = _room_with_return_door(16, 12, false, Vector2i(8, 11))

	room_defs[INSTITUTE_ROOM_ID] = {
		"width": institute_width,
		"height": institute_height,
		"wood_floor": false,
		"doors": institute_doors
	}

func load_room(room_id_str):
	return room_defs.get(room_id_str, room_defs[INSTITUTE_ROOM_ID])


func _room_with_return_door(width: int, height: int, wood_floor: bool, door_pos: Vector2i) -> Dictionary:
	return {
		"width": width,
		"height": height,
		"wood_floor": wood_floor,
		"doors": [{
			"pos": door_pos,
			"dest": INSTITUTE_ROOM_ID
		}]
	}
