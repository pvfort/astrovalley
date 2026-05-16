extends Node

const SAVE_ROOT: String = "res://saves/worlds"
const SAVE_FILE_NAME: String = "world.json"
const FURNITURE_CATEGORY: String = "placed_furniture"
const MACHINE_CATEGORY: String = "machine_states"
const ROOM_CATEGORY: String = "room_states"
const INVALID_PATH_CHARS: Array[String] = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", " "]
const REQUEST_AUTOSAVE_DELAY: float = 0.75

var _saveables: Dictionary = {}
var _loaded_world_data: WorldSaveData = WorldSaveData.new()
var _world_name: String = ""
var _world_seed: int = 0
var _loaded: bool = false
var _is_loading: bool = false
var _autosave_queued: bool = false


func _ready() -> void:
	_ensure_save_root()
	_connect_autosave_triggers()
	call_deferred("_load_world_after_boot")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		save_world()


func set_world_context(world_name: String, world_seed: int = 0) -> void:
	if not world_name.is_empty():
		_world_name = _sanitize_path_segment(world_name)
	_world_seed = world_seed


func register_saveable(component: SaveableComponent) -> void:
	if component == null:
		return
	if component.unique_id.is_empty():
		return
	_saveables[component.unique_id] = component


func unregister_saveable(component: SaveableComponent) -> void:
	if component == null:
		return
	if component.unique_id.is_empty():
		return
	if _saveables.get(component.unique_id, null) == component:
		_saveables.erase(component.unique_id)


func save_world() -> bool:
	if _is_loading or not _is_world_authority():
		return false

	var world_data: WorldSaveData = _build_world_data()
	var save_path: String = _save_file_path()
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Failed to open save file for write: %s" % save_path)
		return false

	file.store_string(SaveSerializer.serialize_save_data(world_data.to_dictionary()))
	_loaded_world_data = world_data
	_loaded = true
	return true


func request_autosave() -> void:
	if _autosave_queued:
		return
	_autosave_queued = true
	var timer: SceneTreeTimer = get_tree().create_timer(REQUEST_AUTOSAVE_DELAY)
	timer.timeout.connect(_flush_requested_autosave, CONNECT_ONE_SHOT)


func load_world() -> bool:
	if not _is_world_authority():
		return false

	var save_path: String = _save_file_path()
	if not FileAccess.file_exists(save_path):
		_loaded_world_data = _build_world_data()
		_loaded = true
		return false

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] Failed to open save file for read: %s" % save_path)
		return false

	var parsed: Variant = SaveSerializer.parse_save_data(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("[SaveManager] Save file JSON root must be a Dictionary.")
		return false

	var save_data: WorldSaveData = WorldSaveData.from_dictionary(parsed as Dictionary)
	_apply_world_data(save_data)
	_loaded_world_data = save_data
	_loaded = true
	return true


func restore_room_furniture(room_id: String, parent: Node) -> void:
	if parent == null:
		return
	if not _loaded:
		return

	for child in parent.get_children():
		var saveable: SaveableComponent = null
		for nested in child.get_children():
			if nested is SaveableComponent:
				saveable = nested as SaveableComponent
				break
		if saveable != null and saveable.category == FURNITURE_CATEGORY:
			child.queue_free()

	for entry in _loaded_world_data.placed_furniture:
		var state: Dictionary = _dictionary(entry.get("state", {}))
		if str(state.get("room_id", "")) != room_id:
			continue
		_instantiate_save_entry(entry, parent)


func _load_world_after_boot() -> void:
	if not _is_world_authority():
		return
	if _world_name.is_empty():
		_world_name = _default_world_name()
	load_world()



func _connect_autosave_triggers() -> void:
	get_tree().node_added.connect(_on_node_added)

	if WorldClock != null:
		WorldClock.hour_changed.connect(_on_world_hour_changed)



func _on_world_hour_changed(_hour: int) -> void:
	save_world()


func _on_node_added(node: Node) -> void:
	if node is SleepComponent:
		var sleep_component: SleepComponent = node as SleepComponent
		if not sleep_component.sleep_finished.is_connected(_on_sleep_finished):
			sleep_component.sleep_finished.connect(_on_sleep_finished)


func _on_sleep_finished(_player_id: int) -> void:
	save_world()


func _flush_requested_autosave() -> void:
	_autosave_queued = false
	save_world()


func _build_world_data() -> WorldSaveData:
	var data: WorldSaveData = WorldSaveData.new()
	data.world_name = _world_name if not _world_name.is_empty() else _default_world_name()
	data.seed = _world_seed
	data.saved_at = Time.get_datetime_string_from_system()
	data.systems = _collect_system_states()
	data.entities = _collect_entity_states()
	data.day = _resolve_saved_day(data.systems)
	data.season = _resolve_saved_season(data.systems)
	data.weather = _resolve_saved_weather(data.systems)
	data.placed_furniture = _filter_entities_by_category(data.entities, FURNITURE_CATEGORY)
	data.machine_states = _filter_entities_by_category(data.entities, MACHINE_CATEGORY)
	data.room_states = _filter_entities_by_category(data.entities, ROOM_CATEGORY)
	return data


func _apply_world_data(data: WorldSaveData) -> void:
	_is_loading = true
	_apply_system_states(data.systems)
	_apply_entity_states(data.entities)
	_is_loading = false


func _collect_system_states() -> Dictionary:
	var states: Dictionary = {}

	if InventoryManager != null and InventoryManager.has_method("save_state"):
		states["inventory"] = _dictionary(InventoryManager.save_state())
	if SkillManager != null and SkillManager.has_method("save_state"):
		states["skills"] = _dictionary(SkillManager.save_state())
	if WorldClock != null and WorldClock.has_method("save_state"):
		states["world_clock"] = _dictionary(WorldClock.save_state())
	if WeatherManager != null and WeatherManager.has_method("save_state"):
		states["weather"] = _dictionary(WeatherManager.save_state())

	return states


func _apply_system_states(states: Dictionary) -> void:
	if InventoryManager != null and InventoryManager.has_method("load_state"):
		InventoryManager.load_state(_dictionary(states.get("inventory", {})))
	if SkillManager != null and SkillManager.has_method("load_state"):
		SkillManager.load_state(_dictionary(states.get("skills", {})))
	if WorldClock != null and WorldClock.has_method("load_state"):
		WorldClock.load_state(_dictionary(states.get("world_clock", {})))
	if WeatherManager != null and WeatherManager.has_method("load_state"):
		WeatherManager.load_state(_dictionary(states.get("weather", {})))


func _collect_entity_states() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for component_variant in _saveables.values():
		if not (component_variant is SaveableComponent):
			continue
		var component: SaveableComponent = component_variant as SaveableComponent
		if not is_instance_valid(component):
			continue
		var entry: Dictionary = component.get_save_entry()
		if entry.is_empty():
			continue
		entries.append(entry)
	return entries


func _apply_entity_states(entries: Array[Dictionary]) -> void:
	var deferred_entries: Array[Dictionary] = []

	for entry in entries:
		if not (entry is Dictionary):
			continue
		var safe_entry: Dictionary = entry as Dictionary
		var category: String = str(safe_entry.get("category", ""))
		if category == FURNITURE_CATEGORY:
			continue
		var unique_id: String = str(safe_entry.get("unique_id", ""))
		var saveable_variant: Variant = _saveables.get(unique_id, null)
		if saveable_variant is SaveableComponent:
			(saveable_variant as SaveableComponent).load_from_entry(safe_entry)
		else:
			deferred_entries.append(safe_entry)

	for entry in deferred_entries:
		_instantiate_save_entry(entry, null)


func _instantiate_save_entry(entry: Dictionary, parent_override: Node) -> void:
	var scene_path: String = str(entry.get("scene_path", ""))
	if scene_path.is_empty():
		return

	var packed: Variant = load(scene_path)
	if not (packed is PackedScene):
		return

	var parent: Node = parent_override
	if parent == null:
		var parent_path: String = str(entry.get("parent_path", ""))
		parent = _resolve_parent(parent_path)
		if parent == null:
			parent = get_tree().current_scene
	if parent == null:
		return

	var instance: Node = (packed as PackedScene).instantiate()
	parent.add_child(instance)

	var saveable: SaveableComponent = _find_or_create_saveable(instance)
	if saveable == null:
		return

	saveable.unique_id = str(entry.get("unique_id", saveable.unique_id))
	saveable.category = str(entry.get("category", saveable.category))
	var scene_override: String = str(entry.get("scene_path", ""))
	if not scene_override.is_empty():
		saveable.scene_path_override = scene_override
	saveable.load_from_entry(entry)


func _find_or_create_saveable(node: Node) -> SaveableComponent:
	for child in node.get_children():
		if child is SaveableComponent:
			return child as SaveableComponent

	var saveable: SaveableComponent = SaveableComponent.new()
	saveable.name = "SaveableComponent"
	node.add_child(saveable)
	return saveable


func _resolve_parent(parent_path: String) -> Node:
	if parent_path.is_empty():
		return get_tree().current_scene
	var root: Window = get_tree().root
	if root.has_node(NodePath(parent_path)):
		return root.get_node(NodePath(parent_path))
	return get_tree().current_scene


func _filter_entities_by_category(entries: Array[Dictionary], category: String) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for entry in entries:
		if str(entry.get("category", "")) == category:
			output.append(entry)
	return output


func _resolve_saved_day(states: Dictionary) -> int:
	var world_clock_state: Dictionary = _dictionary(states.get("world_clock", {}))
	return int(world_clock_state.get("day", 1))


func _resolve_saved_season(states: Dictionary) -> String:
	var weather_state: Dictionary = _dictionary(states.get("weather", {}))
	return str(weather_state.get("season", "spring"))


func _resolve_saved_weather(states: Dictionary) -> String:
	var weather_state: Dictionary = _dictionary(states.get("weather", {}))
	return str(weather_state.get("weather", "clear"))


func _default_world_name() -> String:
	var mp := _get_mp()

	if mp != null and mp.has_multiplayer_peer():
		if mp.is_server():
			return "host_%s" % str(mp.get_unique_id())
		return "host_1"

	return "local_world"


func _ensure_save_root() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_ROOT)


func _save_file_path() -> String:
	var world_key: String = _world_name if not _world_name.is_empty() else _default_world_name()
	var world_dir: String = "%s/%s" % [SAVE_ROOT, _sanitize_path_segment(world_key)]
	DirAccess.make_dir_recursive_absolute(world_dir)
	return "%s/%s" % [world_dir, SAVE_FILE_NAME]


func _get_mp() -> MultiplayerAPI:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.multiplayer

func _is_world_authority() -> bool:
	var mp := _get_mp()
	if mp == null:
		return true

	if mp.has_multiplayer_peer():
		return mp.is_server()

	return true

func _sanitize_path_segment(value: String) -> String:
	var sanitized: String = value.strip_edges().to_lower()
	if sanitized.is_empty():
		return "default_world"

	for ch in INVALID_PATH_CHARS:
		sanitized = sanitized.replace(ch, "_")

	return sanitized


func _dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
