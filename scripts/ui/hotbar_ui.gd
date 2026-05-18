extends Control

@export var slot_scene: PackedScene = preload("res://scenes/ui/HotbarSlot.tscn")

@onready var slots_container: HBoxContainer = $PanelContainer/MarginContainer/Slots

var _slots: Array = []
var _inventory_open: bool = false
var _tracked_player: PlayerCharacter = null


func _ready() -> void:
_build_slots()

if InventoryManager != null:
InventoryManager.inventory_changed.connect(_refresh_slots)
InventoryManager.inventory_toggled.connect(_on_inventory_toggled)
_inventory_open = InventoryManager.is_inventory_open

_update_visibility()
_set_tracked_player(_find_local_player())
_refresh_slots()
set_process(true)


func _process(_delta: float) -> void:
if _tracked_player == null or not is_instance_valid(_tracked_player):
_set_tracked_player(_find_local_player())


func _build_slots() -> void:
if slots_container.get_child_count() > 0:
return

_slots.clear()

var hotbar_size := 8
if InventoryManager != null:
hotbar_size = InventoryManager.HOTBAR_SIZE

for i in range(hotbar_size):
var slot = slot_scene.instantiate()
slot.slot_index = i
slot.slot_clicked.connect(_on_slot_clicked)
slots_container.add_child(slot)
_slots.append(slot)


func _on_inventory_toggled(open_state: bool) -> void:
_inventory_open = open_state
_update_visibility()


func _update_visibility() -> void:
visible = not _inventory_open


func _set_tracked_player(player: PlayerCharacter) -> void:
if _tracked_player != null and is_instance_valid(_tracked_player):
if _tracked_player.hotbar_selection_changed.is_connected(_on_hotbar_selection_changed):
_tracked_player.hotbar_selection_changed.disconnect(_on_hotbar_selection_changed)
if _tracked_player.equipped_item_changed.is_connected(_on_equipped_item_changed):
_tracked_player.equipped_item_changed.disconnect(_on_equipped_item_changed)

_tracked_player = player

if _tracked_player != null:
_tracked_player.hotbar_selection_changed.connect(_on_hotbar_selection_changed)
_tracked_player.equipped_item_changed.connect(_on_equipped_item_changed)

_refresh_slots()


func _find_local_player() -> PlayerCharacter:
var players := get_tree().get_nodes_in_group("player")
for node in players:
if node is PlayerCharacter and node.is_multiplayer_authority():
return node as PlayerCharacter
return null


func _on_slot_clicked(slot_index: int) -> void:
if _tracked_player == null:
return
_tracked_player.set_selected_hotbar_slot(slot_index)


func _on_hotbar_selection_changed(_selected_slot: int) -> void:
_refresh_slots()


func _on_equipped_item_changed(_item: ItemData, _selected_slot: int) -> void:
_refresh_slots()


func _refresh_slots() -> void:
if _slots.is_empty():
return

var selected_slot := 0
if _tracked_player != null and is_instance_valid(_tracked_player):
selected_slot = _tracked_player.selected_hotbar_slot

for i in range(_slots.size()):
var slot = _slots[i]
if slot == null:
continue
var slot_data = null
if InventoryManager != null:
slot_data = InventoryManager.get_hotbar_slot(i)
slot.set_slot_data(slot_data)
slot.set_selected(i == selected_slot)
