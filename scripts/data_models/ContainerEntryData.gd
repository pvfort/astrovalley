class_name ContainerEntryData
extends RefCounted

var container_id: String = ""
var slot_count: int = 0
var slots: Array[ContainerSlotData] = []


func to_dictionary() -> Dictionary:
	var serialized_slots: Array[Dictionary] = []
	for slot_data in slots:
		serialized_slots.append(slot_data.to_dictionary())

	return {
		"container_id": container_id,
		"slot_count": slot_count,
		"slots": serialized_slots,
	}


static func from_variant(value: Variant) -> ContainerEntryData:
	var entry_data: ContainerEntryData = ContainerEntryData.new()
	if not (value is Dictionary):
		return entry_data

	var entry: Dictionary = value as Dictionary
	entry_data.container_id = str(entry.get("container_id", ""))
	entry_data.slot_count = max(int(entry.get("slot_count", 0)), 0)

	var slots_variant: Variant = entry.get("slots", [])
	if slots_variant is Array:
		var slots_array: Array = slots_variant as Array
		for slot_variant in slots_array:
			entry_data.slots.append(ContainerSlotData.from_variant(slot_variant))

	return entry_data
