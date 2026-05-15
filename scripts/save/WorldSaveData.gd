class_name WorldSaveData
extends RefCounted

const CURRENT_SAVE_VERSION: int = 1

var save_version: int = CURRENT_SAVE_VERSION
var world_name: String = "default_world"
var seed: int = 0
var day: int = 1
var season: String = "spring"
var weather: String = "clear"
var saved_at: String = ""
var systems: Dictionary = {}
var entities: Array[Dictionary] = []
var placed_furniture: Array[Dictionary] = []
var machine_states: Array[Dictionary] = []
var room_states: Array[Dictionary] = []


func to_dictionary() -> Dictionary:
	return {
		"save_version": save_version,
		"world_name": world_name,
		"seed": seed,
		"day": day,
		"season": season,
		"weather": weather,
		"saved_at": saved_at,
		"systems": systems.duplicate(true),
		"entities": entities.duplicate(true),
		"placed_furniture": placed_furniture.duplicate(true),
		"machine_states": machine_states.duplicate(true),
		"room_states": room_states.duplicate(true),
	}


static func from_dictionary(data: Dictionary) -> WorldSaveData:
	var result := WorldSaveData.new()
	result.save_version = int(data.get("save_version", CURRENT_SAVE_VERSION))
	result.world_name = str(data.get("world_name", "default_world"))
	result.seed = int(data.get("seed", 0))
	result.day = int(data.get("day", 1))
	result.season = str(data.get("season", "spring"))
	result.weather = str(data.get("weather", "clear"))
	result.saved_at = str(data.get("saved_at", ""))
	result.systems = _as_dictionary(data.get("systems", {}))
	result.entities = _as_dictionary_array(data.get("entities", []))
	result.placed_furniture = _as_dictionary_array(data.get("placed_furniture", []))
	result.machine_states = _as_dictionary_array(data.get("machine_states", []))
	result.room_states = _as_dictionary_array(data.get("room_states", []))
	return result


static func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func _as_dictionary_array(value: Variant) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if not (value is Array):
		return output

	for element in value:
		if element is Dictionary:
			output.append((element as Dictionary).duplicate(true))
	return output
