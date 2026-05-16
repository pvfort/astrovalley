extends Node

const CHARACTERS_ROOT: String = "user://characters"
const SAVE_FILE_NAME: String = "furniture.json"
const PERSISTENT_OBJECT_SCRIPT: Script = preload("res://scripts/persistence/PersistentObject.gd")


func serialize_furniture(
scene_path: String,
position: Vector2,
rotation: float,
room_id: String,
persistent_id: String = "",
owner_character_id: String = "",
creation_timestamp: String = ""
) -> Dictionary:
var entry: FurnitureEntryData = FurnitureEntryData.new()
entry.scene_path = scene_path
entry.position = position
entry.rotation = rotation
entry.room_id = room_id
entry.persistent_id = persistent_id
entry.owner_character_id = owner_character_id
entry.creation_timestamp = creation_timestamp
return entry.to_dictionary()


func add_furniture(
scene_path: String,
position: Vector2,
rotation: float = 0.0,
room_id: String = "",
persistent_id: String = "",
owner_character_id: String = "",
creation_timestamp: String = ""
) -> void:
if scene_path.is_empty():
return

var entries: Array[FurnitureEntryData] = load_furniture_entries()
var entry: FurnitureEntryData = FurnitureEntryData.new()
entry.scene_path = scene_path
entry.position = position
entry.rotation = rotation
entry.room_id = room_id
entry.persistent_id = persistent_id
entry.owner_character_id = owner_character_id
entry.creation_timestamp = creation_timestamp
entries.append(entry)
save_furniture_entries(entries)


func remove_furniture(
scene_path: String,
position: Vector2,
room_id: String = "",
persistent_id: String = ""
) -> void:
var entries: Array[FurnitureEntryData] = load_furniture_entries()

if not persistent_id.is_empty():
for i in range(entries.size() - 1, -1, -1):
var by_id_entry: FurnitureEntryData = entries[i]
if by_id_entry.persistent_id == persistent_id:
entries.remove_at(i)
save_furniture_entries(entries)
return

for i in range(entries.size() - 1, -1, -1):
var entry: FurnitureEntryData = entries[i]
if entry.scene_path != scene_path:
continue
if not room_id.is_empty() and entry.room_id != room_id:
continue
if entry.position.distance_to(position) > 0.1:
continue

entries.remove_at(i)
break

save_furniture_entries(entries)


func update_furniture_transform(
persistent_id: String,
position: Vector2,
rotation: float,
room_id: String = ""
) -> bool:
if persistent_id.is_empty():
return false

var entries: Array[FurnitureEntryData] = load_furniture_entries()
for i in range(entries.size()):
var entry: FurnitureEntryData = entries[i]
if entry.persistent_id != persistent_id:
continue

entry.position = position
entry.rotation = rotation
if not room_id.is_empty():
entry.room_id = room_id
entries[i] = entry
save_furniture_entries(entries)
return true

return false


func load_room_furniture(parent: Node, room_id: String) -> void:
if parent == null:
return

for child in parent.get_children():
child.queue_free()

var entries: Array[FurnitureEntryData] = load_furniture_entries()
var needs_backfill_save: bool = false

for index in range(entries.size()):
var entry: FurnitureEntryData = entries[index]
if not room_id.is_empty() and entry.room_id != room_id:
continue
if entry.scene_path.is_empty():
continue

var packed: Variant = load(entry.scene_path)
if not (packed is PackedScene):
continue

var instance: Node = (packed as PackedScene).instantiate()
var owner_character_id: String = entry.owner_character_id
if owner_character_id.is_empty():
owner_character_id = _active_character_id()
var creation_timestamp: String = entry.creation_timestamp
if creation_timestamp.is_empty():
creation_timestamp = Time.get_datetime_string_from_system(true)

if entry.persistent_id.is_empty() and PersistenceRegistry != null:
entry.persistent_id = PersistenceRegistry.create_runtime_id(owner_character_id)
entry.owner_character_id = owner_character_id
entry.creation_timestamp = creation_timestamp
entries[index] = entry
needs_backfill_save = true

var persistent_component: PersistentObject = _ensure_persistent_component(instance)
persistent_component.persistent_id = entry.persistent_id
persistent_component.scene_path = entry.scene_path
persistent_component.owner_character_id = owner_character_id
persistent_component.creation_timestamp = creation_timestamp

if instance is Node2D:
var node_2d: Node2D = instance as Node2D
node_2d.global_position = entry.position
node_2d.rotation = entry.rotation

parent.add_child(instance)

if needs_backfill_save:
save_furniture_entries(entries)


func load_furniture_entries() -> Array[FurnitureEntryData]:
var save_path: String = _save_path()
if save_path.is_empty():
return []
if not FileAccess.file_exists(save_path):
return []

var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
if file == null:
push_error("[FurnitureSaveManager] Failed to open save file: %s" % save_path)
return []

var parsed: Variant = SaveSerializer.parse_save_data(file.get_as_text())
var entries: Array[FurnitureEntryData] = []
if not (parsed is Array):
return entries

var parsed_array: Array = parsed as Array
for entry_variant in parsed_array:
entries.append(FurnitureEntryData.from_variant(entry_variant))
return entries


func load_furniture_state() -> Array:
var entries: Array[FurnitureEntryData] = load_furniture_entries()
var serialized: Array = []
for entry in entries:
serialized.append(entry.to_dictionary())
return serialized


func save_furniture_entries(entries: Array[FurnitureEntryData]) -> void:
var serialized: Array[Dictionary] = []
for entry in entries:
serialized.append(entry.to_dictionary())

save_furniture_state(serialized)


func save_furniture_state(entries: Array) -> void:
var save_path: String = _save_path()
if save_path.is_empty():
return

var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
if file == null:
push_error("[FurnitureSaveManager] Failed to open save file for write: %s" % save_path)
return

file.store_string(SaveSerializer.serialize_save_data(entries))


func _active_character_id() -> String:
if CharacterSaveManager == null:
return ""

var profile: CharacterProfile = CharacterSaveManager.get_active_character()
if profile == null:
return ""

return str(profile.character_id)


func _save_path() -> String:
var character_id: String = _active_character_id()
if character_id.is_empty():
return ""

var character_dir: String = "%s/%s" % [CHARACTERS_ROOT, character_id]
DirAccess.make_dir_recursive_absolute(character_dir)
return "%s/%s" % [character_dir, SAVE_FILE_NAME]


func _ensure_persistent_component(instance: Node) -> PersistentObject:
var existing: Node = instance.find_child("PersistentObject", true, false)
if existing is PersistentObject:
return existing as PersistentObject

var persistent_component: PersistentObject = PERSISTENT_OBJECT_SCRIPT.new() as PersistentObject
persistent_component.name = "PersistentObject"
instance.add_child(persistent_component)
return persistent_component
