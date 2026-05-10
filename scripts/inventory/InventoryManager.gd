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

func _ready():
	inventory.resize(INVENTORY_SIZE)

func add_item(item):
	for i in range(inventory.size()):
		if inventory[i] == null:
			inventory[i] = item
			return true

	return false

func remove_item(index: int):
	inventory[index] = null

func sort_inventory():
	inventory.sort_custom(sort_items)

func sort_items(a, b):
	if a == null:
		return false
	if b == null:
		return true

	return a.category < b.category
