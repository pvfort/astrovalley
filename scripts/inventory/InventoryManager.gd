extends Node

const INVENTORY_SIZE: int = 24
const HOTBAR_SIZE: int = 8
const ITEM_RESOURCES_ROOT: String = "res://resources/items"

var inventory: Array[Variant] = []
var equipped: Dictionary = {
	"head": null,
	"body": null,
	"accessory": null,
	"tool": null,
}

var funds: int = 250
signal inventory_changed
signal inventory_toggled(is_open: bool)

var is_inventory_open: bool = false
var _item_cache: Dictionary = {}
var _item_cache_built: bool = false


func _ready() -> void:
	inventory.resize(INVENTORY_SIZE)
	_rebuild_item_cache()


func add_item(item: ItemData) -> bool:
	if item == null:
		return false

	var remaining: int = max(item.stack_size, 1)
	remaining = try_insert_item_id(item.item_id, 1)
	if remaining == 0:
		inventory_changed.emit()
		return true

	return false


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


func remove_item(index: int) -> void:
	if index < 0 or index >= inventory.size():
		return

	inventory[index] = null
	inventory_changed.emit()


func sort_inventory() -> void:
	inventory.sort_custom(sort_items)
	inventory_changed.emit()


func sort_items(a: Variant, b: Variant) -> bool:
	if a == null:
		return false
	if b == null:
		return true

	var a_item: ItemData = _slot_item(a)
	var b_item: ItemData = _slot_item(b)
	if a_item == null:
		return false
	if b_item == null:
		return true

	return a_item.display_name < b_item.display_name


func get_inventory_slot(index: int) -> Variant:
	if index < 0 or index >= inventory.size():
		return null
	return inventory[index]


func get_hotbar_slot(index: int) -> Variant:
	if index < 0 or index >= HOTBAR_SIZE:
		return null
	return get_inventory_slot(index)


func toggle_inventory() -> void:
	is_inventory_open = not is_inventory_open
	inventory_toggled.emit(is_inventory_open)


func set_inventory_open(open_state: bool) -> void:
	if is_inventory_open == open_state:
		return

	is_inventory_open = open_state
	inventory_toggled.emit(is_inventory_open)


func has_item(item_id: String) -> bool:
	for slot_variant in inventory:
		var item: ItemData = _slot_item(slot_variant)
		if item != null and item.item_id == item_id:
			return true

	return false


func has_free_slot() -> bool:
	for slot_variant in inventory:
		if slot_variant == null:
			return true

	return false


func remove_item_by_id(item_id: String) -> bool:
	for i in range(inventory.size()):
		var slot_variant: Variant = inventory[i]
		var item: ItemData = _slot_item(slot_variant)
		if item == null:
			continue
		if item.item_id != item_id:
			continue

		inventory[i] = null
		inventory_changed.emit()
		return true

	return false


func use_item(index: int, player: PlayerCharacter) -> void:
	if index < 0 or index >= inventory.size():
		return

	var slot_variant: Variant = inventory[index]
	var item: ItemData = _slot_item(slot_variant)
	if item == null:
		return
	if not item.consumable:
		return

	var status: StatusEffectComponent = player.get_status_effect_component()
	if status != null and not item.status_effect_id.is_empty():
		status.apply(item.status_effect_id, item.status_effect_duration)

	var removed: InventorySlotData = take_from_slot(index, 1)
	if removed.count > 0 and item.replacement_item != null:
		add_item(item.replacement_item)


func save_state() -> Dictionary:
	var serialized_inventory: Array[Dictionary] = []
	for slot_variant in inventory:
		if slot_variant == null:
			serialized_inventory.append({})
			continue

		var slot_data: InventorySlotData = InventorySlotData.from_runtime_slot(slot_variant)
		serialized_inventory.append(slot_data.to_save_dictionary())

	var equipped_state: Dictionary = {}
	for key_variant in equipped.keys():
		var key: String = str(key_variant)
		var equipped_variant: Variant = equipped.get(key, null)
		var equipped_item: ItemData = equipped_variant as ItemData if equipped_variant is ItemData else null
		equipped_state[key] = equipped_item.item_id if equipped_item != null else ""

	return {
		"inventory": serialized_inventory,
		"equipped": equipped_state,
		"funds": funds,
	}


func load_state(data: Dictionary) -> void:
	inventory.resize(INVENTORY_SIZE)
	for i in range(INVENTORY_SIZE):
		inventory[i] = null

	var saved_inventory_variant: Variant = data.get("inventory", [])
	if saved_inventory_variant is Array:
		var saved_inventory: Array = saved_inventory_variant as Array
		for i in range(min(INVENTORY_SIZE, saved_inventory.size())):
			var slot_model: InventorySlotData = InventorySlotData.from_variant(saved_inventory[i])
			inventory[i] = slot_model.to_runtime_slot(_item_cache)

	var saved_equipped_variant: Variant = data.get("equipped", {})
	if saved_equipped_variant is Dictionary:
		var saved_equipped: Dictionary = saved_equipped_variant as Dictionary
		for key_variant in equipped.keys():
			var key: String = str(key_variant)
			var item_id: String = str(saved_equipped.get(key, ""))
			equipped[key] = _item_by_id(item_id)

	funds = int(data.get("funds", funds))
	inventory_changed.emit()


func try_insert_item_id(item_id: String, count: int) -> int:
	if item_id.is_empty() or count <= 0:
		return count

	var item: ItemData = _item_by_id(item_id)
	if item == null:
		return count

	var stack_limit: int = max(item.stack_size, 1)
	var remaining: int = count

	for i in range(inventory.size()):
		if remaining <= 0:
			break
		var slot_variant: Variant = inventory[i]
		if not (slot_variant is Dictionary):
			continue
		var slot_dict: Dictionary = slot_variant as Dictionary
		var slot_item: ItemData = _slot_item(slot_dict)
		if slot_item == null or slot_item.item_id != item_id:
			continue

		var current_count: int = int(slot_dict.get("count", 0))
		if current_count >= stack_limit:
			continue

		var add_amount: int = min(stack_limit - current_count, remaining)
		slot_dict["count"] = current_count + add_amount
		inventory[i] = slot_dict
		remaining -= add_amount

	for i in range(inventory.size()):
		if remaining <= 0:
			break
		if inventory[i] != null:
			continue

		var add_amount: int = min(stack_limit, remaining)
		inventory[i] = {
			"item": item,
			"count": add_amount,
		}
		remaining -= add_amount

	if remaining != count:
		inventory_changed.emit()

	return remaining


func take_from_slot(index: int, amount: int) -> InventorySlotData:
	var removed: InventorySlotData = InventorySlotData.new()
	if index < 0 or index >= inventory.size() or amount <= 0:
		return removed

	var slot_variant: Variant = inventory[index]
	if not (slot_variant is Dictionary):
		return removed

	var slot_dict: Dictionary = slot_variant as Dictionary
	var slot_item: ItemData = _slot_item(slot_dict)
	if slot_item == null:
		return removed

	var current_count: int = max(int(slot_dict.get("count", 0)), 0)
	if current_count <= 0:
		inventory[index] = null
		inventory_changed.emit()
		return removed

	var remove_count: int = min(current_count, amount)
	removed.item_id = slot_item.item_id
	removed.count = remove_count

	var next_count: int = current_count - remove_count
	if next_count <= 0:
		inventory[index] = null
	else:
		slot_dict["count"] = next_count
		inventory[index] = slot_dict

	inventory_changed.emit()
	return removed


func _slot_item(slot_variant: Variant) -> ItemData:
	if not (slot_variant is Dictionary):
		return null

	var slot_dict: Dictionary = slot_variant as Dictionary
	var item_variant: Variant = slot_dict.get("item", null)
	if item_variant is ItemData:
		return item_variant as ItemData
	return null


func _item_by_id(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null

	if _item_cache.has(item_id):
		var cached_item: Variant = _item_cache.get(item_id, null)
		if cached_item is ItemData:
			return cached_item as ItemData

	if not _item_cache_built:
		_rebuild_item_cache()

	if _item_cache.has(item_id):
		var rebuilt_item: Variant = _item_cache.get(item_id, null)
		if rebuilt_item is ItemData:
			return rebuilt_item as ItemData

	push_warning("[InventoryManager] Could not resolve saved item_id: %s" % item_id)
	return null


func _rebuild_item_cache() -> void:
	_item_cache.clear()
	_item_cache_built = true
	if not DirAccess.dir_exists_absolute(ITEM_RESOURCES_ROOT):
		return

	var dir: DirAccess = DirAccess.open(ITEM_RESOURCES_ROOT)
	if dir == null:
		return

	var files: PackedStringArray = dir.get_files()
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var resource_path: String = "%s/%s" % [ITEM_RESOURCES_ROOT, file_name]
		var loaded: Variant = load(resource_path)
		if loaded is ItemData:
			var item: ItemData = loaded as ItemData
			if not item.item_id.is_empty():
				_item_cache[item.item_id] = item
