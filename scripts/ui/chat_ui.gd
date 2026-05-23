extends Control

const MAX_VISIBLE_MESSAGES := 8

@onready var messages_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/Messages
@onready var input_line: LineEdit = $Panel/MarginContainer/VBoxContainer/InputLine

var _messages: Array[String] = []
var _chat_open := false
var _chat_active := true


func _ready() -> void:
	_chat_active = _is_local_player_ui()
	visible = _chat_active
	if not _chat_active:
		set_process_unhandled_input(false)
		return

	_ensure_chat_input_action()
	input_line.visible = false
	input_line.text_submitted.connect(_on_text_submitted)

	if NetworkManager != null and not NetworkManager.chat_message_received.is_connected(_on_chat_message_received):
		NetworkManager.chat_message_received.connect(_on_chat_message_received)


func _exit_tree() -> void:
	if NetworkManager != null and NetworkManager.chat_message_received.is_connected(_on_chat_message_received):
		NetworkManager.chat_message_received.disconnect(_on_chat_message_received)


func _unhandled_input(event: InputEvent) -> void:
	if not _chat_active:
		return

	if event.is_action_pressed("chat_open"):
		_set_chat_open(true)
		get_viewport().set_input_as_handled()
		return

	if not _chat_open:
		return

	if event.is_action_pressed("ui_cancel"):
		_set_chat_open(false)
		get_viewport().set_input_as_handled()


func _on_text_submitted(text: String) -> void:
	var message := text.strip_edges()
	if not message.is_empty() and NetworkManager != null and NetworkManager.has_method("send_chat_message"):
		NetworkManager.send_chat_message(message)
	_set_chat_open(false)


func _on_chat_message_received(_player_id: int, player_name: String, message: String) -> void:
	_messages.append("%s: %s" % [player_name, message])
	if _messages.size() > MAX_VISIBLE_MESSAGES:
		_messages = _messages.slice(_messages.size() - MAX_VISIBLE_MESSAGES, _messages.size())
	_refresh_messages()


func _refresh_messages() -> void:
	messages_label.text = "\n".join(_messages)
	var last_line := max(messages_label.get_line_count() - 1, 0)
	messages_label.scroll_to_line(last_line)


func _set_chat_open(opened: bool) -> void:
	_chat_open = opened
	input_line.visible = _chat_open
	if _chat_open:
		input_line.text = ""
		input_line.grab_focus()
		add_to_group("movement_blocking_ui")
	else:
		input_line.release_focus()
		remove_from_group("movement_blocking_ui")


func _ensure_chat_input_action() -> void:
	if not InputMap.has_action("chat_open"):
		InputMap.add_action("chat_open")

	for event in InputMap.action_get_events("chat_open"):
		if event is InputEventKey and event.keycode == KEY_T:
			return

	var key_event := InputEventKey.new()
	key_event.keycode = KEY_T
	key_event.physical_keycode = KEY_T
	InputMap.action_add_event("chat_open", key_event)


func _is_local_player_ui() -> bool:
	var canvas_layer := get_parent()
	if canvas_layer == null:
		return true
	var player := canvas_layer.get_parent()
	if player is PlayerCharacter:
		return player.is_multiplayer_authority()
	return true
