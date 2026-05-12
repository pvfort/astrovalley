class_name PickupComponent
extends Node

@export var item: ItemData
@export var allowed_mode := PlayerCharacter.InteractionMode.PICKUP
@export var priority := 999

func can_interact(_player) -> bool:
	return item != null

func interact(player: PlayerCharacter) -> void:
	print("[PICKUP] interact CALLED on:", get_parent().name)

	if item == null:
		print("[PICKUP] item is NULL")
		return

	print("[PICKUP] item =", item.item_id)

	var ok := InventoryManager.add_item(item)

	print("[PICKUP] inventory result =", ok)

	if ok:
		print("[PICKUP] removing entity")
		get_parent().queue_free()
