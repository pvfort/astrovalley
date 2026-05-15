extends Node

const INVENTORY_SIZE = 24
const HOTBAR_SIZE = 8
const ITEM_RESOURCES_ROOT := "res://resources/items"

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
var _item_cache: Dictionary = {}
var _item_cache_built: bool = false


	
func _ready():
	inventory.resize(INVENTORY_SIZE)
	_rebuild_item_cache()

func add_item(item: ItemData) -> bool:
	if item == null:
		return false
	return add_item_stack(item, 1) == 0


func add_item_stack(item: ItemData, count: int) -> int:
	if item == null:
		return max(count, 0)
	var remaining := max(count, 0)
	if remaining == 0:
		return 0

	var changed := false
	var max_stack := get_max_stack_for_item(item)
	for i in range(inventory.size()):
		if remaining == 0:
			break
		var slot_data := inventory[i]
		if slot_data == null:
			continue
		var slot_item := slot_data.get("item", null) as ItemData
		if slot_item == null or slot_item.item_id != item.item_id:
			continue
		var slot_count := int(slot_data.get("count", 1))
		if slot_count >= max_stack:
			continue
		var can_add := min(max_stack - slot_count, remaining)
		slot_data["count"] = slot_count + can_add
		remaining -= can_add
		changed = true

	for i in range(inventory.size()):
		if remaining == 0:
			break
		if inventory[i] != null:
			continue
		var add_count := min(max_stack, remaining)
		inventory[i] = {
			"item": item,
			"count": add_count
		}
		remaining -= add_count
		changed = true

	if changed:
		inventory_changed.emit()
	return remaining


func purchase_item(item: ItemData, cost: int) -> bool:
	if item == null:
		return false

	var final_cost: int = max(cost, 0)

	if funds < final_cost:
		return false

	var added: bool = add_item(item)

	if not added:
		return false

	funds -= final_cost

	return true

func remove_item(index: int):
	if not _is_valid_inventory_index(index):
		return
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
	if not _is_valid_inventory_index(index):
		return null
	return inventory[index]


func get_inventory_size() -> int:
	return INVENTORY_SIZE


func get_max_stack_for_item(item: ItemData) -> int:
	if item == null:
		return 1
	return max(1, item.stack_size)


func set_inventory_slot(index: int, slot_data: Variant) -> void:
	if not _is_valid_inventory_index(index):
		return
	if slot_data == null:
		inventory[index] = null
		inventory_changed.emit()
		return
	if not (slot_data is Dictionary):
		return

	var slot_dict := slot_data as Dictionary
	var item := slot_dict.get("item", null) as ItemData
	if item == null:
		return
	var count := clampi(int(slot_dict.get("count", 1)), 1, get_max_stack_for_item(item))
	inventory[index] = {
		"item": item,
		"count": count
	}
	inventory_changed.emit()


func remove_from_slot(index: int, count: int = 1) -> Dictionary:
	if not _is_valid_inventory_index(index):
		return {}
	var slot_data := inventory[index]
	if slot_data == null:
		return {}
	var item := slot_data.get("item", null) as ItemData
	if item == null:
		return {}
	var slot_count := int(slot_data.get("count", 1))
	var remove_count := clampi(count, 1, slot_count)
	slot_count -= remove_count
	if slot_count <= 0:
		inventory[index] = null
	else:
		slot_data["count"] = slot_count
	inventory_changed.emit()
	return {
		"item": item,
		"count": remove_count
	}


func try_insert_into_slot(index: int, item: ItemData, count: int) -> int:
	if not _is_valid_inventory_index(index):
		return max(count, 0)
	if item == null:
		return max(count, 0)
	var remaining := max(count, 0)
	if remaining == 0:
		return 0

	var slot_data := inventory[index]
	var max_stack := get_max_stack_for_item(item)
	if slot_data == null:
		var put_count := min(remaining, max_stack)
		inventory[index] = {
			"item": item,
			"count": put_count
		}
		inventory_changed.emit()
		return remaining - put_count

	var slot_item := slot_data.get("item", null) as ItemData
	if slot_item == null or slot_item.item_id != item.item_id:
		return remaining

	var slot_count := int(slot_data.get("count", 1))
	var can_add := min(max_stack - slot_count, remaining)
	if can_add <= 0:
		return remaining
	slot_data["count"] = slot_count + can_add
	inventory_changed.emit()
	return remaining - can_add

func get_hotbar_slot(index: int):

	if index >= HOTBAR_SIZE:
		return null

	return inventory[index]

func toggle_inventory() -> void:

	is_inventory_open = !is_inventory_open

	print("Inventory state:", is_inventory_open)

	inventory_toggled.emit(is_inventory_open)

func has_item(item_id: String) -> bool:

	for slot in inventory:

		if slot == null:
			continue

		var item: ItemData = slot["item"]

		if item.item_id == item_id:
			return true

	return false

func has_free_slot() -> bool:
	for slot in inventory:
		if slot == null:
			return true

	return false


func remove_item_by_id(item_id: String) -> bool:

	for i in range(inventory.size()):

		var slot = inventory[i]

		if slot == null:
			continue

		var item: ItemData = slot["item"]

		if item.item_id == item_id:

			inventory[i] = null
			inventory_changed.emit()

			return true

	return false


func use_item(index: int, player: PlayerCharacter) -> void:

	var slot = inventory[index]

	if slot == null:
		return

	var item: ItemData = slot["item"]

	if item == null:
		return

	if not item.consumable:
		print("[ITEM USE] item not consumable")
		return

	print("[ITEM USE] consuming:", item.item_id)

	var status = player.get_status_effect_component()

	if status != null and item.status_effect_id != "":
		status.apply(
			item.status_effect_id,
			item.status_effect_duration
		)

	remove_item(index)

	if item.replacement_item != null:
		add_item(item.replacement_item)


func save_state() -> Dictionary:
	var serialized_inventory: Array[Dictionary] = []
	for slot_variant in inventory:
		if slot_variant == null:
			serialized_inventory.append({})
			continue

		var slot := slot_variant as Dictionary
		var item := slot.get("item", null) as ItemData
		serialized_inventory.append({
			"item_id": item.item_id if item != null else "",
			"count": int(slot.get("count", 1)),
		})

	var equipped_state: Dictionary = {}
	for key_variant in equipped.keys():
		var key := str(key_variant)
		var equipped_item := equipped.get(key_variant, null) as ItemData
		equipped_state[key] = equipped_item.item_id if equipped_item != null else ""

	return {
		"inventory": serialized_inventory,
		"equipped": equipped_state,
		"funds": funds,
	}


func load_state(data: Dictionary) -> void:
	var saved_inventory := data.get("inventory", [])
	var inventory_entries: Array = []
	if saved_inventory is Array:
		inventory_entries = saved_inventory as Array
	inventory.resize(INVENTORY_SIZE)

	for i in range(INVENTORY_SIZE):
		inventory[i] = null
		if i >= inventory_entries.size():
			continue

		var entry_variant := inventory_entries[i]
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var item_id := str(entry.get("item_id", ""))
		var item := _item_by_id(item_id)
		if item == null:
			continue

		inventory[i] = {
			"item": item,
			"count": int(entry.get("count", 1)),
		}

	var saved_equipped := data.get("equipped", {})
	if saved_equipped is Dictionary:
		var equipped_dict := saved_equipped as Dictionary
		for key_variant in equipped.keys():
			var key := str(key_variant)
			var item_id := str(equipped_dict.get(key, ""))
			equipped[key_variant] = _item_by_id(item_id)

	funds = int(data.get("funds", funds))
	inventory_changed.emit()


func _item_by_id(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null

	if _item_cache.has(item_id):
		return _item_cache[item_id] as ItemData

	if not _item_cache_built:
		_rebuild_item_cache()
	if _item_cache.has(item_id):
		return _item_cache[item_id] as ItemData

	push_warning("[InventoryManager] Could not resolve saved item_id: %s" % item_id)
	return null


func _rebuild_item_cache() -> void:
	_item_cache.clear()
	_item_cache_built = true
	if not DirAccess.dir_exists_absolute(ITEM_RESOURCES_ROOT):
		return

	var dir := DirAccess.open(ITEM_RESOURCES_ROOT)
	if dir == null:
		return

	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var resource_path := "%s/%s" % [ITEM_RESOURCES_ROOT, file_name]
		var loaded := load(resource_path)
		if loaded is ItemData:
			var item := loaded as ItemData
			if not item.item_id.is_empty():
				_item_cache[item.item_id] = item


func _is_valid_inventory_index(index: int) -> bool:
	return index >= 0 and index < inventory.size()
