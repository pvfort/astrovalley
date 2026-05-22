extends Node

signal active_quest_changed(quest: Quest)
signal quest_progressed(quest: Quest)
signal quest_completed(quest: Quest)

const STARTER_QUEST_ID := "morning_routine"

var _quests: Dictionary = {}
var _active_quest_id := ""
var _player_id := -1


func _ready() -> void:
	_player_id = _resolve_local_player_id()
	_initialize_default_quests()
	_activate_current_quest()


func get_active_quest() -> Quest:
	var quest_variant: Variant = _quests.get(_active_quest_id, null)
	if quest_variant is Quest:
		return quest_variant as Quest
	return null


func get_active_quest_title() -> String:
	var quest := get_active_quest()
	return quest.title if quest != null else ""


func get_active_objective_text() -> String:
	var quest := get_active_quest()
	if quest == null:
		return ""

	var objective := quest.get_next_incomplete_objective()
	if objective == null:
		return "Quest complete"
	return objective.get_progress_text()


func save_state() -> Dictionary:
	var serialized_quests: Dictionary = {}
	for quest_id in _quests.keys():
		var quest_variant: Variant = _quests.get(quest_id, null)
		if quest_variant is Quest:
			serialized_quests[str(quest_id)] = (quest_variant as Quest).save_state()
	return {
		"active_quest_id": _active_quest_id,
		"quests": serialized_quests,
	}


func load_state(data: Dictionary) -> void:
	_initialize_default_quests()

	var saved_quests := data.get("quests", {})
	if saved_quests is Dictionary:
		for quest_id_variant in (saved_quests as Dictionary).keys():
			var quest_variant: Variant = _quests.get(str(quest_id_variant), null)
			var quest_state_variant: Variant = (saved_quests as Dictionary).get(quest_id_variant, {})
			if quest_variant is Quest and quest_state_variant is Dictionary:
				(quest_variant as Quest).load_state(quest_state_variant as Dictionary)

	_active_quest_id = str(data.get("active_quest_id", STARTER_QUEST_ID))
	_activate_current_quest()


func _initialize_default_quests() -> void:
	for quest_variant in _quests.values():
		if quest_variant is Quest:
			_disconnect_quest(quest_variant as Quest)
	_quests.clear()

	var quest := Quest.new()
	quest.id = STARTER_QUEST_ID
	quest.title = "Observatory Routine"
	quest.objectives = [
		_create_collect_mug_objective(),
		_create_use_station_objective(),
		_create_complete_observe_objective(),
	]

	_quests[quest.id] = quest

	if _active_quest_id.is_empty():
		_active_quest_id = quest.id


func _activate_current_quest() -> void:
	var quest := get_active_quest()
	if quest == null:
		return

	_disconnect_quest(quest)
	if not quest.progressed.is_connected(_on_quest_progressed):
		quest.progressed.connect(_on_quest_progressed)
	if not quest.completed.is_connected(_on_quest_completed):
		quest.completed.connect(_on_quest_completed)
	quest.activate(_player_id)
	active_quest_changed.emit(quest)
	quest_progressed.emit(quest)


func _disconnect_quest(quest: Quest) -> void:
	if quest == null:
		return
	quest.cleanup()
	if quest.progressed.is_connected(_on_quest_progressed):
		quest.progressed.disconnect(_on_quest_progressed)
	if quest.completed.is_connected(_on_quest_completed):
		quest.completed.disconnect(_on_quest_completed)


func _on_quest_progressed() -> void:
	var quest := get_active_quest()
	if quest != null:
		quest_progressed.emit(quest)


func _on_quest_completed() -> void:
	var quest := get_active_quest()
	if quest != null:
		quest_completed.emit(quest)
		quest_progressed.emit(quest)


func _resolve_local_player_id() -> int:
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1


func _create_collect_mug_objective() -> CollectItemObjective:
	var objective := CollectItemObjective.new()
	objective.target_item = "mug"
	objective.required_amount = 1
	objective.description = "Pick up a mug"
	return objective


func _create_use_station_objective() -> StationUseObjective:
	var objective := StationUseObjective.new()
	objective.target_station = "coffee_station"
	objective.required_uses = 1
	objective.description = "Use the coffee machine"
	return objective


func _create_complete_observe_objective() -> TaskCompleteObjective:
	var objective := TaskCompleteObjective.new()
	objective.target_task = "observe"
	objective.required_completions = 1
	objective.description = "Complete an observation"
	return objective
