extends Node

signal inventory_changed
signal inventory_open_changed(is_open: bool)
signal funds_changed(value: int)

const INVENTORY_SIZE: int = 24
const HOTBAR_SIZE: int = 8
const EQUIPMENT_SLOT_ORDER: Array[StringName] = [&"head", &"body", &"accessory", &"tool"]

var inventory: Array[Variant] = []
var hotbar: Array[Variant] = []
var equipped: Dictionary = {
    &"head": null,
    &"body": null,
    &"accessory": null,
    &"tool": null,
}

var funds: int = 250:
    set(value):
        funds = max(value, 0)
        funds_changed.emit(funds)

var inventory_open: bool = false

func _ready() -> void:
    inventory.resize(INVENTORY_SIZE)
    hotbar.resize(HOTBAR_SIZE)
    _load_placeholder_items()
    inventory_changed.emit()
    funds_changed.emit(funds)

func _load_placeholder_items() -> void:
    var starter_items: Array[String] = [
        "res://resources/items/coffee.tres",
        "res://resources/items/notebook.tres",
        "res://resources/items/star_chart.tres",
        "res://resources/items/hard_drive.tres",
        "res://resources/items/observatory_keycard.tres",
    ]

    for i in range(min(starter_items.size(), inventory.size())):
        var item := load(starter_items[i])
        if item != null:
            inventory[i] = {"item": item, "count": 1}

    # Mirror the first inventory slots into the hotbar at startup.
    for i in range(hotbar.size()):
        hotbar[i] = inventory[i].duplicate(true) if i < inventory.size() and inventory[i] != null else null

func toggle_inventory() -> void:
    set_inventory_open(not inventory_open)

func set_inventory_open(is_open: bool) -> void:
    if inventory_open == is_open:
        return
    inventory_open = is_open
    inventory_open_changed.emit(inventory_open)

func add_item(item: Resource, count: int = 1) -> bool:
    if item == null or count <= 0:
        return false

    for i in range(inventory.size()):
        if inventory[i] == null:
            inventory[i] = {"item": item, "count": count}
            inventory_changed.emit()
            return true

    return false

func remove_item(index: int) -> void:
    if index < 0 or index >= inventory.size():
        return
    inventory[index] = null
    inventory_changed.emit()

func sort_inventory() -> void:
    var filled: Array[Variant] = []
    for slot in inventory:
        if slot != null:
            filled.append(slot)

    filled.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var raw_item_a: Variant = a.get("item")
        var raw_item_b: Variant = b.get("item")
        var item_a: ItemData = raw_item_a if raw_item_a is ItemData else null
        var item_b: ItemData = raw_item_b if raw_item_b is ItemData else null
        var category_a: String = item_a.item_category if item_a != null else ""
        var category_b: String = item_b.item_category if item_b != null else ""
        if category_a == category_b:
            var name_a: String = item_a.display_name if item_a != null else ""
            var name_b: String = item_b.display_name if item_b != null else ""
            return name_a < name_b
        return category_a < category_b
    )

    inventory.fill(null)
    for i in range(min(filled.size(), inventory.size())):
        inventory[i] = filled[i]

    inventory_changed.emit()

func get_inventory_slot(index: int) -> Variant:
    if index < 0 or index >= inventory.size():
        return null
    return inventory[index]

func get_hotbar_slot(index: int) -> Variant:
    if index < 0 or index >= hotbar.size():
        return null
    return hotbar[index]

func set_equipped(slot_type: StringName, slot_value: Variant) -> void:
    if not equipped.has(slot_type):
        return
    equipped[slot_type] = slot_value
    inventory_changed.emit()
