class_name ProducerComponent
extends Node

@export var input_item_id: String
@export var output_item: ItemData

func can_produce(item: ItemData) -> bool:
	return item != null and item.item_id == input_item_id

func produce(player: PlayerCharacter, inventory: Array) -> void:
	for i in range(inventory.size()):
		var slot = inventory[i]
		if slot == null:
			continue

		var item: ItemData = slot["item"]

		if item.item_id == input_item_id:

			print("[PRODUCER] converting", input_item_id, "→", output_item.item_id)

			slot["item"] = output_item

			InventoryManager.inventory_changed.emit()
			return
