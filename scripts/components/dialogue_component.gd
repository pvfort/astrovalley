class_name DialogueComponent
extends InteractableComponent

signal dialogue_started(player_id: int)
signal dialogue_finished(player_id: int)

const DIALOGUE_PRIORITY := 25

@export var dialogue_data: DialogueData
@export var dialogue_ui_path: NodePath

var _is_dialogue_open := false


func _ready() -> void:
	priority = max(priority, DIALOGUE_PRIORITY)


func can_interact(_player: PlayerCharacter) -> bool:
	return not _is_dialogue_open


func interact(player: PlayerCharacter) -> void:
	if player == null:
		return

	var dialogue_ui := _find_dialogue_ui()
	if dialogue_data == null or dialogue_ui == null or not dialogue_ui.has_method("open_dialogue"):
		_complete_interaction(player)
		return

	_is_dialogue_open = true
	dialogue_started.emit(player.player_id)
	dialogue_ui.open_dialogue(dialogue_data, Callable(self, "_on_dialogue_closed").bind(player))


func _on_dialogue_closed(player: PlayerCharacter) -> void:
	_is_dialogue_open = false
	_complete_interaction(player)


func _complete_interaction(player: PlayerCharacter) -> void:
	dialogue_finished.emit(player.player_id)
	_on_dialogue_completed(player)


func _on_dialogue_completed(_player: PlayerCharacter) -> void:
	pass


func _find_dialogue_ui() -> Node:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null

	if not dialogue_ui_path.is_empty():
		var dialogue_ui_from_path := get_node_or_null(dialogue_ui_path)
		if dialogue_ui_from_path != null:
			return dialogue_ui_from_path

	return scene_root.find_child("DialogueUI", true, false)
