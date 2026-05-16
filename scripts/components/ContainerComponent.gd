class_name ContainerComponent
extends InteractableComponent

signal container_changed

@export var container_id: String = ""
@export var slot_count: int = 16
@export var max_stack_per_slot: int = 99

var _slots: Array[ContainerSlotData] = []


func _ready() -> void:
if container_id.is_empty():
container_id = "container_%s" % str(get_instance_id())
slot_count = max(slot_count, 1)
max_stack_per_slot = max(max_stack_per_slot, 1)
_initialize_slots()


func interact(player: PlayerCharacter) -> void:
if player == null:
return

var ui: ContainerUI = _resolve_container_ui()
if ui == null:
return

ui.open_container(self, player)


func get_slot_count() -> int:
return _slots.size()


func get_slot_view(index: int) -> Dictionary:
if index < 0 or index >= _slots.size():
return {"item_id": "", "count": 0}

var slot: ContainerSlotData = _slots[index]
return slot.to_dictionary()


func transfer_from_player(player_slot_index: int, target_slot_index: int, amount: int = 1) -> bool:
if not _is_server_authority():
return false
if InventoryManager == null:
return false

var taken: InventorySlotData = InventoryManager.take_from_slot(player_slot_index, amount)
if taken.count <= 0 or taken.item_id.is_empty():
return false

var remaining: int = _insert_item(taken.item_id, taken.count, target_slot_index)
if remaining > 0:
InventoryManager.try_insert_item_id(taken.item_id, remaining)

var moved_count: int = taken.count - remaining
if moved_count <= 0:
return false

_notify_container_changed()
return true


func transfer_to_player(container_slot_index: int, amount: int = 1) -> bool:
if not _is_server_authority():
return false
if InventoryManager == null:
return false

var removed: ContainerSlotData = _remove_from_slot(container_slot_index, amount)
if removed.count <= 0 or removed.item_id.is_empty():
return false

var remaining: int = InventoryManager.try_insert_item_id(removed.item_id, removed.count)
if remaining > 0:
_insert_item(removed.item_id, remaining, container_slot_index)

var moved_count: int = removed.count - remaining
if moved_count <= 0:
return false

_notify_container_changed()
return true


func save_state() -> Dictionary:
var entry: ContainerEntryData = ContainerEntryData.new()
entry.container_id = container_id
entry.slot_count = _slots.size()

for slot in _slots:
var copy_slot: ContainerSlotData = ContainerSlotData.new(slot.item_id, slot.count)
entry.slots.append(copy_slot)

return {
"container": entry.to_dictionary(),
}


func load_state(data: Dictionary) -> void:
var raw_entry: Variant = data.get("container", data)
var entry: ContainerEntryData = ContainerEntryData.from_variant(raw_entry)

if not entry.container_id.is_empty():
container_id = entry.container_id
if entry.slot_count > 0:
slot_count = entry.slot_count

_initialize_slots()

for i in range(min(_slots.size(), entry.slots.size())):
var source_slot: ContainerSlotData = entry.slots[i]
_slots[i] = ContainerSlotData.new(source_slot.item_id, source_slot.count)

_notify_container_changed(false)


func _insert_item(item_id: String, count: int, preferred_index: int = -1) -> int:
if item_id.is_empty() or count <= 0:
return count

var remaining: int = count
var max_stack: int = max(max_stack_per_slot, 1)

if preferred_index >= 0 and preferred_index < _slots.size():
remaining = _insert_into_slot(preferred_index, item_id, remaining, max_stack)
if remaining <= 0:
return 0

for i in range(_slots.size()):
if remaining <= 0:
break
if i == preferred_index:
continue
remaining = _insert_into_slot(i, item_id, remaining, max_stack)

return remaining


func _insert_into_slot(index: int, item_id: String, count: int, max_stack: int) -> int:
if index < 0 or index >= _slots.size() or count <= 0:
return count

var slot: ContainerSlotData = _slots[index]
if slot.is_empty():
var add_amount: int = min(count, max_stack)
slot.item_id = item_id
slot.count = add_amount
_slots[index] = slot
return count - add_amount

if slot.item_id != item_id:
return count

if slot.count >= max_stack:
return count

var add_existing: int = min(max_stack - slot.count, count)
slot.count += add_existing
_slots[index] = slot
return count - add_existing


func _remove_from_slot(index: int, amount: int) -> ContainerSlotData:
var removed: ContainerSlotData = ContainerSlotData.new()
if index < 0 or index >= _slots.size() or amount <= 0:
return removed

var slot: ContainerSlotData = _slots[index]
if slot.is_empty():
return removed

var remove_count: int = min(slot.count, amount)
removed.item_id = slot.item_id
removed.count = remove_count

slot.count -= remove_count
if slot.count <= 0:
slot.item_id = ""
slot.count = 0

_slots[index] = slot
return removed


func _initialize_slots() -> void:
_slots.clear()
for _i in range(slot_count):
_slots.append(ContainerSlotData.new())


func _resolve_container_ui() -> ContainerUI:
var tree: SceneTree = get_tree()
if tree == null or tree.current_scene == null:
return null

var canvas_layer: Node = tree.current_scene.get_node_or_null("CanvasLayer")
if canvas_layer == null:
return null

var ui_node: Node = canvas_layer.get_node_or_null("ContainerUI")
if ui_node is ContainerUI:
return ui_node as ContainerUI

return null


func _is_server_authority() -> bool:
if multiplayer.has_multiplayer_peer():
return multiplayer.is_server()
return true


func _notify_container_changed(request_save: bool = true) -> void:
container_changed.emit()
if request_save and SaveManager != null:
if SaveManager.has_method("request_autosave"):
SaveManager.request_autosave()
else:
SaveManager.save_world()
