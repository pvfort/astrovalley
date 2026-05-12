extends Area2D

func interact(player: PlayerCharacter) -> void:
	var inv = InventoryManager.inventory

	for i in range(inv.size()):
		var slot = inv[i]
		if slot == null:
			continue

		var item: ItemData = slot["item"]

		if item.item_id == "empty_mug":
			print("[COFFEE MACHINE] filling mug")

			slot["item"] = preload("res://resources/items/coffee_machine.tres")

			InventoryManager.inventory_changed.emit()
			return

	print("[COFFEE MACHINE] no empty mug found")
