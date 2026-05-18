class_name FurnitureEntryData
extends RefCounted

var scene_path: String = ""
var position: Vector2 = Vector2.ZERO
var rotation: float = 0.0
var room_id: String = ""
var persistent_id: String = ""
var owner_character_id: String = ""
var creation_timestamp: String = ""


func to_dictionary() -> Dictionary:
	return {
		"scene": scene_path,
		"position": position,
		"rotation": rotation,
		"room_id": room_id,
		"persistent_id": persistent_id,
		"owner_character_id": owner_character_id,
		"creation_timestamp": creation_timestamp,
	}


static func from_variant(value: Variant) -> FurnitureEntryData:
	var entry_data: FurnitureEntryData = FurnitureEntryData.new()
	if not (value is Dictionary):
		return entry_data

	var entry: Dictionary = value as Dictionary
	entry_data.scene_path = str(entry.get("scene", ""))
	entry_data.position = _to_vector2(entry.get("position", Vector2.ZERO))
	entry_data.rotation = float(entry.get("rotation", 0.0))
	entry_data.room_id = str(entry.get("room_id", ""))
	entry_data.persistent_id = str(entry.get("persistent_id", ""))
	entry_data.owner_character_id = str(entry.get("owner_character_id", ""))
	entry_data.creation_timestamp = str(entry.get("creation_timestamp", ""))
	return entry_data


static func _to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		var vector_dict: Dictionary = value as Dictionary
		return Vector2(float(vector_dict.get("x", 0.0)), float(vector_dict.get("y", 0.0)))
	if value is Array:
		var vector_array: Array = value as Array
		if vector_array.size() >= 2:
			return Vector2(float(vector_array[0]), float(vector_array[1]))
	return Vector2.ZERO
