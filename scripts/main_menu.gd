extends Control

# MainMenu: Handles host/join/quit actions before entering the gameplay scene.

const GAMEPLAY_SCENE = "res://scenes/main.tscn"
const DEFAULT_PORT = 4242

@onready var character_name_field: LineEdit = $VBoxContainer/CharacterCreatorRow/CharacterNameField
@onready var office_number_field: LineEdit = $VBoxContainer/CharacterCreatorRow/OfficeNumberField
@onready var character_selector: OptionButton = $VBoxContainer/CharacterSelectorRow/CharacterSelector
@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinRow/JoinButton
@onready var port_field: LineEdit = $VBoxContainer/PortField
@onready var ip_field: LineEdit = $VBoxContainer/JoinRow/IPField
@onready var status_label: Label = $VBoxContainer/StatusLabel

var _character_ids: Array[String] = []

func _ready() -> void:
	_reload_character_selector()
	_update_network_buttons()

func _on_host_pressed() -> void:
	if not _has_selected_character():
		return

	var port = int(port_field.text) if port_field.text.is_valid_int() else DEFAULT_PORT
	var ok = NetworkManager.host_game(port)
	if ok:
		get_tree().change_scene_to_file(GAMEPLAY_SCENE)
	else:
		status_label.text = "Failed to host on port %d" % port

func _on_join_pressed() -> void:
	if not _has_selected_character():
		return

	var ip = ip_field.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Please enter a server IP address."
		return
	var port = int(port_field.text) if port_field.text.is_valid_int() else DEFAULT_PORT
	var ok = NetworkManager.join_game(ip, port)
	if ok:
		get_tree().change_scene_to_file(GAMEPLAY_SCENE)
	else:
		status_label.text = "Failed to join %s:%d" % [ip, port]

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_create_character_button_pressed() -> void:
	var character_name := character_name_field.text.strip_edges()
	if character_name.is_empty():
		status_label.text = "Enter a character name to create a save."
		return

	var office_number := office_number_field.text.strip_edges()
	var profile := CharacterSaveManager.create_character(character_name, office_number)
	if profile == null:
		status_label.text = "Failed to create character save."
		return

	CharacterSaveManager.set_active_character(profile)
	_reload_character_selector(profile.character_id)
	character_name_field.clear()
	office_number_field.clear()
	status_label.text = "Created and selected: %s" % profile.character_name
	_update_network_buttons()

func _on_character_selector_item_selected(index: int) -> void:
	if index < 0 or index >= _character_ids.size():
		return

	var selected_profile := CharacterSaveManager.load_character(_character_ids[index])
	if selected_profile == null:
		status_label.text = "Failed to load selected character save."
		_update_network_buttons()
		return

	CharacterSaveManager.set_active_character(selected_profile)
	status_label.text = "Selected character: %s" % selected_profile.character_name
	_update_network_buttons()

func _reload_character_selector(selected_character_id: String = "") -> void:
	_character_ids.clear()
	character_selector.clear()

	var characters: Array = CharacterSaveManager.get_all_characters()
	for profile in characters:
		if profile == null:
			continue
		var label := profile.character_name
		if label.is_empty():
			label = profile.character_id
		if not profile.office_number.is_empty():
			label += " (Office %s)" % profile.office_number

		_character_ids.append(profile.character_id)
		character_selector.add_item(label)

	if _character_ids.is_empty():
		CharacterSaveManager.set_active_character(null)
		status_label.text = "Create and select a character save to host or join."
		_update_network_buttons()
		return

	var preferred_id := selected_character_id
	if preferred_id.is_empty():
		var active_profile := CharacterSaveManager.get_active_character()
		if active_profile != null:
			preferred_id = active_profile.character_id

	var preferred_index := _character_ids.find(preferred_id)
	if preferred_index == -1:
		preferred_index = 0

	character_selector.select(preferred_index)
	_on_character_selector_item_selected(preferred_index)

func _has_selected_character() -> bool:
	var active_profile := CharacterSaveManager.get_active_character()
	if active_profile != null:
		return true

	status_label.text = "Select a character save before hosting or joining."
	_update_network_buttons()
	return false

func _update_network_buttons() -> void:
	var has_active_character := CharacterSaveManager.get_active_character() != null
	host_button.disabled = not has_active_character
	join_button.disabled = not has_active_character
