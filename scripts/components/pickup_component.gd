class_name PickupComponent
extends Node

@export var item: ItemData
@export var allowed_mode := PlayerCharacter.InteractionMode.PICKUP
@export var priority := 999

func can_interact(_player) -> bool:
	return item != null

func interact(player: PlayerCharacter) -> void:
	if item == null:
		return

	var ok := InventoryManager.add_item(item)

	if ok:
		if EventBus != null and player != null:
			EventBus.item_collected.emit(player.player_id, item.item_id, 1)
		get_parent().queue_free()
