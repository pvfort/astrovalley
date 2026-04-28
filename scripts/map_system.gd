extends Node

const TILE_FLOOR = 0
const TILE_WALL = 1
const TILE_DOOR = 2
const TILE_WINDOW = 3
const TILE_WOOD = 4

var room_defs = {
	"institute_f1": {
		"width": 16, "height": 12, "wood_floor": false,
		"doors": [{"pos": Vector2i(8, 11), "dest": "outside"}, {"pos": Vector2i(1, 1), "dest": "office_1"}, {"pos": Vector2i(14, 1), "dest": "institute_f2"}]
	},
	"institute_f2": {
		"width": 16, "height": 12, "wood_floor": false,
		"doors": [{"pos": Vector2i(14, 11), "dest": "institute_f1"}, {"pos": Vector2i(1, 1), "dest": "office_2"}, {"pos": Vector2i(8, 1), "dest": "cafe"}]
	},
	"office_1": {
		"width": 8, "height": 6, "wood_floor": true,
		"doors": [{"pos": Vector2i(4, 5), "dest": "institute_f1"}]
	},
	"office_2": {
		"width": 8, "height": 6, "wood_floor": true,
		"doors": [{"pos": Vector2i(4, 5), "dest": "institute_f2"}]
	},
	"cafe": {
		"width": 10, "height": 8, "wood_floor": true,
		"doors": [{"pos": Vector2i(5, 7), "dest": "institute_f2"}]
	},
	"outside": {
		"width": 20, "height": 15, "wood_floor": false,
		"doors": [{"pos": Vector2i(10, 1), "dest": "institute_f1"}, {"pos": Vector2i(18, 5), "dest": "observatory"}]
	},
	"observatory": {
		"width": 10, "height": 10, "wood_floor": false,
		"doors": [{"pos": Vector2i(5, 9), "dest": "outside"}]
	}
}

func load_room(room_id_str):
	return room_defs.get(room_id_str, room_defs["institute_f1"])
