extends Control

@export var slot_scene: PackedScene = preload("res://scenes/ui/InventorySlot.tscn")

@onready var slots_container: HBoxContainer = $PanelContainer/MarginContainer/Slots

func _ready() -> void:
    _build_slots()
    if InventoryManager != null:
        InventoryManager.inventory_changed.connect(_refresh_hotbar)
    _refresh_hotbar()

func _build_slots() -> void:
    if slots_container.get_child_count() > 0:
        return

    for _i in range(InventoryManager.HOTBAR_SIZE):
        var slot = slot_scene.instantiate()
        slot.custom_minimum_size = Vector2(72, 92)
        slots_container.add_child(slot)

func _refresh_hotbar() -> void:
    for i in range(slots_container.get_child_count()):
        var slot = slots_container.get_child(i)
        if slot.has_method("set_slot_data"):
            slot.set_slot_data(InventoryManager.get_hotbar_slot(i))
