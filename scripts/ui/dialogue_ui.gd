extends Control

@onready var speaker_label: Label = $Panel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var body_label: Label = $Panel/MarginContainer/VBoxContainer/BodyLabel
@onready var choices_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ChoicesContainer
@onready var next_button: Button = $Panel/MarginContainer/VBoxContainer/ActionsContainer/NextButton
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/ActionsContainer/CloseButton

var _dialogue_data: DialogueData
var _current_node_id := ""
var _on_dialogue_finished: Callable = Callable()
var _is_open := false


func _ready() -> void:
	visible = false
	next_button.pressed.connect(_on_next_pressed)
	close_button.pressed.connect(close_dialogue)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if event.is_action_pressed("ui_cancel"):
		close_dialogue()
		get_viewport().set_input_as_handled()


func open_dialogue(dialogue_data: DialogueData, on_finished: Callable = Callable()) -> void:
	if dialogue_data == null:
		if on_finished.is_valid():
			on_finished.call()
		return

	_dialogue_data = dialogue_data
	_on_dialogue_finished = on_finished
	_current_node_id = _dialogue_data.get_start_node_id()

	if _current_node_id.is_empty():
		if _on_dialogue_finished.is_valid():
			_on_dialogue_finished.call()
		_reset_dialogue_state()
		return

	_is_open = true
	visible = true
	_render_current_node()


func close_dialogue() -> void:
	var callback := _on_dialogue_finished
	_reset_dialogue_state()
	if callback.is_valid():
		callback.call()


func _on_next_pressed() -> void:
	if not _is_open:
		return

	var node := _dialogue_data.get_node(_current_node_id)
	if node == null:
		close_dialogue()
		return

	if node.next_node_id.is_empty():
		close_dialogue()
		return

	_current_node_id = node.next_node_id
	_render_current_node()


func _on_choice_selected(next_node_id: String) -> void:
	if next_node_id.is_empty():
		close_dialogue()
		return

	_current_node_id = next_node_id
	_render_current_node()


func _render_current_node() -> void:
	var node := _dialogue_data.get_node(_current_node_id)
	if node == null:
		close_dialogue()
		return

	speaker_label.text = node.speaker_name
	body_label.text = node.line_text

	_clear_choice_buttons()
	var has_choices := not node.choices.is_empty()
	choices_container.visible = has_choices
	next_button.visible = not has_choices

	if not has_choices:
		return

	for choice in node.choices:
		if choice == null:
			continue

		var choice_button := Button.new()
		choice_button.text = choice.text
		choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_button.pressed.connect(_on_choice_selected.bind(choice.next_node_id))
		choices_container.add_child(choice_button)


func _clear_choice_buttons() -> void:
	for child in choices_container.get_children():
		child.queue_free()


func _reset_dialogue_state() -> void:
	_is_open = false
	visible = false
	_dialogue_data = null
	_current_node_id = ""
	_on_dialogue_finished = Callable()
	_clear_choice_buttons()
