extends Node

const INVENTORY_SIZE = 24
const HOTBAR_SIZE = 8

var inventory: Array = []
var equipped := {
	"head": null,
	"body": null,
	"accessory": null,
	"tool": null
}

var funds: int = 250
signal inventory_changed
signal inventory_toggled(is_open: bool)

var is_inventory_open: bool = false


	
func _ready():
	inventory.resize(INVENTORY_SIZE)

func add_item(item: ItemData) -> bool:
	print("[INVENTORY] add_item called:", item.item_id)

	for i in range(inventory.size()):
		if inventory[i] == null:
			inventory[i] = {
				"item": item,
				"count": 1
			}

			print("[INVENTORY] inserted at slot:", i)
			inventory_changed.emit()
			return true

	print("[INVENTORY] FAILED: inventory full")
	return false

func remove_item(index: int):

	inventory[index] = null

	inventory_changed.emit()

func sort_inventory():
	inventory.sort_custom(sort_items)

func sort_items(a, b):
	if a == null:
		return false
	if b == null:
		return true

	return a.category < b.category

func get_inventory_slot(index: int):
	return inventory[index]

func get_hotbar_slot(index: int):

	if index >= HOTBAR_SIZE:
		return null

	return inventory[index]

func toggle_inventory() -> void:

	is_inventory_open = !is_inventory_open

	print("Inventory state:", is_inventory_open)

	inventory_toggled.emit(is_inventory_open)
