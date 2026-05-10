extends Control

@onready var inventory_grid = $Background/MainContent/RightPanel/InventoryGrid

var is_open := false

func _ready():
	visible = false

func _unhandled_input(event):
	if event.is_action_pressed("inventory"):
		toggle_inventory()

func toggle_inventory():
	is_open = !is_open
	visible = is_open

	if is_open:
		refresh_inventory()

func refresh_inventory():
	for child in inventory_grid.get_children():
		child.queue_free()

	for item in InventoryManager.inventory:
		var slot = preload("res://scenes/ui/InventorySlot.tscn").instantiate()

		if item != null:
			slot.set_item(item)

		inventory_grid.add_child(slot)
