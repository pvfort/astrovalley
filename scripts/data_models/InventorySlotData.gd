class_name InventorySlotData
extends RefCounted

var item_id: String = ""
var count: int = 0


func _init(initial_item_id: String = "", initial_count: int = 0) -> void:
	item_id = initial_item_id
	count = max(initial_count, 0)


func is_empty() -> bool:
	return item_id.is_empty() or count <= 0


func to_save_dictionary() -> Dictionary:
	return {
		"item_id": item_id,
		"count": count,
	}


func to_runtime_slot(item_cache: Dictionary) -> Variant:
	if is_empty():
		return null

	var item_variant: Variant = item_cache.get(item_id, null)
	if not (item_variant is ItemData):
		return null

	return {
		"item": item_variant as ItemData,
		"count": count,
	}


static func from_variant(value: Variant) -> InventorySlotData:
	var model: InventorySlotData = InventorySlotData.new()
	if not (value is Dictionary):
		return model

	var entry: Dictionary = value as Dictionary
	model.item_id = str(entry.get("item_id", ""))
	model.count = max(int(entry.get("count", 0)), 0)
	return model


static func from_runtime_slot(value: Variant) -> InventorySlotData:
	var model: InventorySlotData = InventorySlotData.new()
	if not (value is Dictionary):
		return model

	var slot: Dictionary = value as Dictionary
	var raw_item: Variant = slot.get("item", null)
	var item: ItemData = raw_item as ItemData if raw_item is ItemData else null
	if item == null:
		return model

	model.item_id = item.item_id
	model.count = max(int(slot.get("count", 1)), 0)
	return model
