extends Control

@export var slot_scene: PackedScene = preload(
	"res://scenes/ui/InventorySlot.tscn"
)

@onready var grid: GridContainer = (
	$Panel/MarginContainer/VBoxContainer/GridContainer
)

var is_open := false


func _ready() -> void:

	visible = false

	_build_inventory()

	if InventoryManager != null:

		InventoryManager.inventory_changed.connect(
			refresh_inventory
		)

		InventoryManager.inventory_toggled.connect(
			_on_inventory_toggled
		)

	refresh_inventory()


func _on_inventory_toggled(open_state: bool) -> void:
	is_open = open_state

	visible = is_open


func _build_inventory() -> void:

	if grid.get_child_count() > 0:
		return

	for i in range(InventoryManager.get_inventory_size()):

		var slot = slot_scene.instantiate()
		slot.slot_index = i

		if slot.has_signal("slot_transfer_requested"):
			var transfer_callable := Callable(self, "_on_slot_transfer_requested")
			if not slot.is_connected("slot_transfer_requested", transfer_callable):
				slot.connect("slot_transfer_requested", transfer_callable)

		grid.add_child(slot)


func refresh_inventory() -> void:

	for i in range(grid.get_child_count()):

		var slot = grid.get_child(i)

		if slot.has_method("set_slot_data"):

			slot.set_slot_data(
				InventoryManager.get_inventory_slot(i)
			)


func _on_slot_transfer_requested(from_index: int, to_index: int) -> void:
	if InventoryManager == null:
		return

	InventoryManager.move_inventory_slot(from_index, to_index)
