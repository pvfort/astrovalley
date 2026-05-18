class_name ContainerSlotData
extends RefCounted

var item_id: String = ""
var count: int = 0


func _init(initial_item_id: String = "", initial_count: int = 0) -> void:
	item_id = initial_item_id
	count = max(initial_count, 0)


func is_empty() -> bool:
	return item_id.is_empty() or count <= 0


func to_dictionary() -> Dictionary:
	return {
		"item_id": item_id,
		"count": count,
	}


static func from_variant(value: Variant) -> ContainerSlotData:
	var slot_data: ContainerSlotData = ContainerSlotData.new()
	if not (value is Dictionary):
		return slot_data

	var slot: Dictionary = value as Dictionary
	slot_data.item_id = str(slot.get("item_id", ""))
	slot_data.count = max(int(slot.get("count", 0)), 0)
	return slot_data
