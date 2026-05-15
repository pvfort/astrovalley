extends Node

const CHARACTERS_ROOT := "user://characters"
const PROFILE_FILE_NAME := "profile.tres"
const ACTIVE_CHARACTER_FILE := "user://characters/active_character.cfg"
const ACTIVE_CHARACTER_SECTION := "character"
const ACTIVE_CHARACTER_KEY := "id"

const CharacterProfile = preload("res://scripts/player/character_profile.gd")

var _active_character: CharacterProfile = null


func _ready() -> void:
	randomize()
	_ensure_characters_root()


func create_character(character_name: String, office_number: String = "") -> CharacterProfile:
	var profile := CharacterProfile.new()
	profile.character_id = _generate_character_id()
	profile.character_name = character_name
	profile.office_number = office_number
	profile.creation_date = Time.get_datetime_string_from_system()
	profile.inventory_data = []
	profile.equipped_data = {}
	profile.skill_data = {}
	profile.funds = 0
	profile.world_time_stats = {}
	profile.player_stats = {}
	profile.current_level = 1

	if save_character(profile):
		return profile

	return null


func save_character(profile: CharacterProfile) -> bool:
	if profile == null:
		push_error("[CharacterSaveManager] Cannot save null profile.")
		return false

	if profile.character_id.is_empty():
		profile.character_id = _generate_character_id()

	var character_dir := _character_directory(profile.character_id)
	var profile_path := _profile_path(profile.character_id)

	if DirAccess.make_dir_recursive_absolute(character_dir) != OK:
		push_error("[CharacterSaveManager] Failed to create character directory: %s" % character_dir)
		return false

	var save_result := ResourceSaver.save(profile, profile_path)
	if save_result != OK:
		push_error("[CharacterSaveManager] Failed to save character profile: %s (%s)" % [profile_path, error_string(save_result)])
		return false

	return true


func load_character(character_id: String) -> CharacterProfile:
	if character_id.is_empty():
		return null

	var path := _profile_path(character_id)
	if not FileAccess.file_exists(path):
		return null

	var loaded := ResourceLoader.load(path)
	if loaded is CharacterProfile:
		return loaded

	push_error("[CharacterSaveManager] Failed to load CharacterProfile from: %s" % path)
	return null


func get_all_characters() -> Array:
	_ensure_characters_root()

	var characters: Array = []
	var dir := DirAccess.open(CHARACTERS_ROOT)
	if dir == null:
		return characters

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var profile := load_character(entry)
			if profile != null:
				characters.append(profile)
		entry = dir.get_next()
	dir.list_dir_end()

	return characters


func delete_character(character_id: String) -> bool:
	if character_id.is_empty():
		return false

	var profile_path := _profile_path(character_id)
	if FileAccess.file_exists(profile_path):
		var remove_file_result := DirAccess.remove_absolute(profile_path)
		if remove_file_result != OK:
			push_error("[CharacterSaveManager] Failed to remove profile: %s (%s)" % [profile_path, error_string(remove_file_result)])
			return false

	var dir_path := _character_directory(character_id)
	if DirAccess.dir_exists_absolute(dir_path):
		var remove_dir_result := DirAccess.remove_absolute(dir_path)
		if remove_dir_result != OK:
			push_error("[CharacterSaveManager] Failed to remove character directory: %s (%s)" % [dir_path, error_string(remove_dir_result)])
			return false

	if _active_character != null and _active_character.character_id == character_id:
		_active_character = null
		_clear_active_character_id()

	return true


func set_active_character(profile: CharacterProfile) -> void:
	_active_character = profile

	if profile == null:
		_clear_active_character_id()
		return

	_save_active_character_id(profile.character_id)


func get_active_character() -> CharacterProfile:
	if _active_character != null:
		return _active_character

	var stored_character_id := _load_active_character_id()
	if stored_character_id.is_empty():
		return null

	_active_character = load_character(stored_character_id)
	return _active_character


func _ensure_characters_root() -> void:
	DirAccess.make_dir_recursive_absolute(CHARACTERS_ROOT)


func _generate_character_id() -> String:
	var unix_time := int(Time.get_unix_time_from_system())
	return "character_%s_%s" % [str(unix_time), str(randi())]


func _character_directory(character_id: String) -> String:
	return "%s/%s" % [CHARACTERS_ROOT, character_id]


func _profile_path(character_id: String) -> String:
	return "%s/%s" % [_character_directory(character_id), PROFILE_FILE_NAME]


func _save_active_character_id(character_id: String) -> void:
	var config := ConfigFile.new()
	config.set_value(ACTIVE_CHARACTER_SECTION, ACTIVE_CHARACTER_KEY, character_id)
	var err := config.save(ACTIVE_CHARACTER_FILE)
	if err != OK:
		push_error("[CharacterSaveManager] Failed to save active character ID (%s)" % error_string(err))


func _load_active_character_id() -> String:
	if not FileAccess.file_exists(ACTIVE_CHARACTER_FILE):
		return ""

	var config := ConfigFile.new()
	var err := config.load(ACTIVE_CHARACTER_FILE)
	if err != OK:
		push_error("[CharacterSaveManager] Failed to load active character ID (%s)" % error_string(err))
		return ""

	return str(config.get_value(ACTIVE_CHARACTER_SECTION, ACTIVE_CHARACTER_KEY, ""))


func _clear_active_character_id() -> void:
	if FileAccess.file_exists(ACTIVE_CHARACTER_FILE):
		var err := DirAccess.remove_absolute(ACTIVE_CHARACTER_FILE)
		if err != OK:
			push_error("[CharacterSaveManager] Failed to clear active character file (%s)" % error_string(err))
