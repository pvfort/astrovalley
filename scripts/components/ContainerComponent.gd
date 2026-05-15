class_name ContainerComponent
extends Node

const DEFAULT_UI_SCENE := preload("res://scenes/ui/ContainerUI.tscn")
const ITEM_RESOURCES_ROOT := "res://resources/items"

@export var container_id: String = ""
@export_range(1, 128, 1) var slot_count: int = 24:
	set(value):
		_set_slot_count(value)
	get:
		return _slot_count
@export var priority: int = 20
@export var allowed_mode := PlayerCharacter.InteractionMode.PRIMARY
@export var locked: bool = false
@export var shared_multiplayer: bool = true
@export var ui_scene: PackedScene

signal container_changed
signal container_opened(container: ContainerComponent, player_id: int)
signal container_closed(container: ContainerComponent, player_id: int)

var slots: Array = []
var _item_cache: Dictionary = {}
var _item_cache_built: bool = false
var _slot_count: int = 24


func _ready() -> void:
	if container_id.is_empty():
		container_id = str(get_parent().get_path()) if get_parent() != null else str(get_path())
	_set_slot_count(slot_count)
	_rebuild_item_cache()


func can_interact(_player: PlayerCharacter) -> bool:
	return not locked


func interact(player: PlayerCharacter) -> void:
	if not can_interact(player):
		return

	var ui := _resolve_container_ui()
	if ui == null:
		return

	if ui.has_method("is_open_for") and ui.call("is_open_for", self):
		ui.call("close_container")
		return

	if ui.has_method("open_container"):
		ui.call("open_container", self, player)


func get_slot(index: int) -> Variant:
	if not _is_valid_slot_index(index):
		return null
	return slots[index]


func get_slot_size() -> int:
	return slot_count


func get_max_stack_for_item(item: ItemData) -> int:
	if item == null:
		return 1
	return max(1, item.stack_size)


func set_slot(index: int, slot_data: Variant) -> void:
	if not _is_valid_slot_index(index):
		return
	if slot_data == null:
		slots[index] = null
		_emit_state_changed()
		return
	if not (slot_data is Dictionary):
		return

	var slot_dict := slot_data as Dictionary
	var item := slot_dict.get("item", null) as ItemData
	if item == null:
		return
	var count := clampi(int(slot_dict.get("count", 1)), 1, get_max_stack_for_item(item))
	slots[index] = {
		"item": item,
		"count": count
	}
	_emit_state_changed()


func remove_from_slot(index: int, count: int = 1) -> Dictionary:
	if not _is_valid_slot_index(index):
		return {}
	var slot_data := slots[index]
	if slot_data == null:
		return {}
	var item := slot_data.get("item", null) as ItemData
	if item == null:
		return {}

	var slot_count_value := int(slot_data.get("count", 1))
	var remove_count := clampi(count, 1, slot_count_value)
	slot_count_value -= remove_count
	if slot_count_value <= 0:
		slots[index] = null
	else:
		slot_data["count"] = slot_count_value

	_emit_state_changed()
	return {
		"item": item,
		"count": remove_count
	}


func try_insert_into_slot(index: int, item: ItemData, count: int) -> int:
	if not _is_valid_slot_index(index):
		return max(count, 0)
	if item == null:
		return max(count, 0)
	var remaining := max(count, 0)
	if remaining == 0:
		return 0

	var slot_data := slots[index]
	var max_stack := get_max_stack_for_item(item)
	if slot_data == null:
		var put_count := min(remaining, max_stack)
		slots[index] = {
			"item": item,
			"count": put_count
		}
		_emit_state_changed()
		return remaining - put_count

	var slot_item := slot_data.get("item", null) as ItemData
	if slot_item == null or slot_item.item_id != item.item_id:
		return remaining

	var slot_count_value := int(slot_data.get("count", 1))
	var can_add := min(max_stack - slot_count_value, remaining)
	if can_add <= 0:
		return remaining
	slot_data["count"] = slot_count_value + can_add
	_emit_state_changed()
	return remaining - can_add


func add_item_stack(item: ItemData, count: int) -> int:
	if item == null:
		return max(count, 0)
	var remaining := max(count, 0)
	if remaining == 0:
		return 0

	var changed := false
	var max_stack := get_max_stack_for_item(item)
	for i in range(slots.size()):
		if remaining == 0:
			break
		var slot_data := slots[i]
		if slot_data == null:
			continue
		var slot_item := slot_data.get("item", null) as ItemData
		if slot_item == null or slot_item.item_id != item.item_id:
			continue
		var slot_count_value := int(slot_data.get("count", 1))
		if slot_count_value >= max_stack:
			continue
		var can_add := min(max_stack - slot_count_value, remaining)
		slot_data["count"] = slot_count_value + can_add
		remaining -= can_add
		changed = true

	for i in range(slots.size()):
		if remaining == 0:
			break
		if slots[i] != null:
			continue
		var put_count := min(max_stack, remaining)
		slots[i] = {
			"item": item,
			"count": put_count
		}
		remaining -= put_count
		changed = true

	if changed:
		_emit_state_changed()
	return remaining


func save_state() -> Dictionary:
	return {
		"container_id": container_id,
		"slot_count": slot_count,
		"locked": locked,
		"slots": _serialize_slots(),
	}


func load_state(data: Dictionary) -> void:
	container_id = str(data.get("container_id", container_id))
	locked = bool(data.get("locked", locked))
	_set_slot_count(int(data.get("slot_count", slot_count)))
	var serialized_slots := data.get("slots", [])
	if serialized_slots is Array:
		_apply_serialized_slots(serialized_slots as Array)
	_emit_state_changed()


func notify_opened(player_id: int) -> void:
	container_opened.emit(self, player_id)


func notify_closed(player_id: int) -> void:
	container_closed.emit(self, player_id)


@rpc("authority", "call_local", "reliable")
func _rpc_sync_state(serialized_slots: Array, synced_slot_count: int, synced_locked: bool) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		return
	slot_count = max(1, synced_slot_count)
	locked = synced_locked
	_apply_serialized_slots(serialized_slots)
	container_changed.emit()


func _emit_state_changed() -> void:
	container_changed.emit()
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and shared_multiplayer:
		rpc("_rpc_sync_state", _serialize_slots(), slot_count, locked)


func _set_slot_count(value: int) -> void:
	_slot_count = max(1, value)
	var previous_size := slots.size()
	slots.resize(_slot_count)
	for i in range(previous_size, _slot_count):
		slots[i] = null
	for i in range(_slot_count):
		if not (slots[i] is Dictionary):
			continue
		var slot_data := slots[i] as Dictionary
		var item := slot_data.get("item", null) as ItemData
		if item == null:
			slots[i] = null
			continue
		slot_data["count"] = clampi(int(slot_data.get("count", 1)), 1, get_max_stack_for_item(item))


func _serialize_slots() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for slot_data in slots:
		if slot_data == null:
			output.append({})
			continue
		var slot_dict := slot_data as Dictionary
		var item := slot_dict.get("item", null) as ItemData
		output.append({
			"item_id": item.item_id if item != null else "",
			"count": int(slot_dict.get("count", 1))
		})
	return output


func _apply_serialized_slots(serialized_slots: Array) -> void:
	slots.resize(slot_count)
	for i in range(slot_count):
		slots[i] = null
		if i >= serialized_slots.size():
			continue
		var slot_entry := serialized_slots[i]
		if not (slot_entry is Dictionary):
			continue
		var slot_dict := slot_entry as Dictionary
		var item_id := str(slot_dict.get("item_id", ""))
		var item := _item_by_id(item_id)
		if item == null:
			continue
		slots[i] = {
			"item": item,
			"count": clampi(int(slot_dict.get("count", 1)), 1, get_max_stack_for_item(item))
		}


func _item_by_id(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null
	if _item_cache.has(item_id):
		return _item_cache[item_id] as ItemData
	if not _item_cache_built:
		_rebuild_item_cache()
	return _item_cache.get(item_id, null) as ItemData


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


func _resolve_container_ui() -> Node:
	for node in get_tree().get_nodes_in_group("container_ui"):
		return node

	var packed_scene := ui_scene if ui_scene != null else DEFAULT_UI_SCENE
	if packed_scene == null:
		return null

	var instance := packed_scene.instantiate()
	var ui_parent := _resolve_ui_parent()
	if ui_parent == null:
		return null
	ui_parent.add_child(instance)
	return instance


func _resolve_ui_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return get_tree().root
	var canvas_layer := current_scene.find_child("CanvasLayer", true, false)
	if canvas_layer != null:
		return canvas_layer
	return current_scene


func _is_valid_slot_index(index: int) -> bool:
	return index >= 0 and index < slots.size()
