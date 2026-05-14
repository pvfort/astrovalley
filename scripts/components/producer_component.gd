class_name ProducerComponent
extends Node

@export var required_item: ItemData
@export var produced_item: ItemData
@export var priority: int = 10
@export var allowed_mode := PlayerCharacter.InteractionMode.PRIMARY


func can_interact(_player) -> bool:
	return true


func interact(_player) -> void:
	print("[PRODUCER] interact called")
	if required_item == null:
		return

	if produced_item == null:
		return

	if not InventoryManager.has_item(required_item.item_id):

		print("[PRODUCER] missing:", required_item.item_id)
		return

	InventoryManager.remove_item_by_id(required_item.item_id)

	var ok := InventoryManager.add_item(produced_item)

	print("[PRODUCER] produced:", produced_item.item_id, " success=", ok)
