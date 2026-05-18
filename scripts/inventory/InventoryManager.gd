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
signal active_tool_changed(tool_data: ToolData)

var is_inventory_open: bool = false
var selected_hotbar_index: int = 0
var _item_cache: Dictionary = {}
var _item_cache_built: bool = false


	
func _ready():
	inventory.resize(INVENTORY_SIZE)
	_rebuild_item_cache()

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
			_emit_active_tool_changed()
			return true

	print("[INVENTORY] FAILED: inventory full")
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

func remove_item(index: int):

	inventory[index] = null

	inventory_changed.emit()
	_emit_active_tool_changed()

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

	if index < 0 or index >= HOTBAR_SIZE:
		return null

	return inventory[index]

func set_selected_hotbar_index(index: int) -> void:
	var clamped_index := clampi(index, 0, HOTBAR_SIZE - 1)
	if selected_hotbar_index == clamped_index:
		return

	selected_hotbar_index = clamped_index
	_emit_active_tool_changed()

func get_selected_hotbar_index() -> int:
	return selected_hotbar_index

func get_active_hotbar_item() -> ItemData:
	var slot_data := get_hotbar_slot(selected_hotbar_index)
	if slot_data is Dictionary:
		var item_variant := (slot_data as Dictionary).get("item")
		if item_variant is ItemData:
			return item_variant as ItemData
	return null

func get_active_tool_data() -> ToolData:
	var active_hotbar_item := get_active_hotbar_item()
	if active_hotbar_item != null and active_hotbar_item.tool_data != null:
		return active_hotbar_item.tool_data

	var equipped_tool := equipped.get("tool", null)
	if equipped_tool is ItemData:
		var equipped_item := equipped_tool as ItemData
		if equipped_item.tool_data != null:
			return equipped_item.tool_data

	return null

func get_tool_interaction_modifiers(context: StringName) -> Dictionary:
	var active_tool := get_active_tool_data()
	if active_tool == null:
		return {}
	return active_tool.get_context_modifiers(context)

func get_tool_interaction_multiplier(context: StringName, key: StringName, default_value: float = 1.0) -> float:
	var active_tool := get_active_tool_data()
	if active_tool == null:
		return default_value
	return active_tool.get_modifier(context, key, default_value)

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
			_emit_active_tool_changed()

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
		"selected_hotbar_index": selected_hotbar_index,
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
	selected_hotbar_index = clampi(int(data.get("selected_hotbar_index", selected_hotbar_index)), 0, HOTBAR_SIZE - 1)
	inventory_changed.emit()
	_emit_active_tool_changed()


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

func _emit_active_tool_changed() -> void:
	active_tool_changed.emit(get_active_tool_data())
