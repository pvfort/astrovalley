extends Node

signal active_quest_changed(quest: Quest)
signal quest_progressed(quest: Quest)
signal quest_completed(quest: Quest)

const STARTER_QUEST_ID := "morning_routine"
const QUEST_SEQUENCE: Array[String] = [
	"morning_routine",
	"meet_professor",
	"teaching_cycle",
	"python_friday_path",
	"it_cluster_access",
]

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
	_player_id = _resolve_local_player_id()
	_initialize_default_quests()

	var saved_quests: Variant = data.get("quests", {})
	if saved_quests is Dictionary:
		for quest_id_variant in (saved_quests as Dictionary).keys():
			var quest_variant: Variant = _quests.get(str(quest_id_variant), null)
			var quest_state_variant: Variant = (saved_quests as Dictionary).get(quest_id_variant, {})
			if quest_variant is Quest and quest_state_variant is Dictionary:
				(quest_variant as Quest).load_state(quest_state_variant as Dictionary)

	_active_quest_id = str(data.get("active_quest_id", STARTER_QUEST_ID))
	if not _quests.has(_active_quest_id):
		_active_quest_id = _find_first_available_quest_id()
	_activate_current_quest()


func _initialize_default_quests() -> void:
	for quest_variant in _quests.values():
		if quest_variant is Quest:
			_disconnect_quest(quest_variant as Quest)
	_quests.clear()

	_register_quest(_build_observatory_routine())
	_register_quest(_build_meet_professor_quest())
	_register_quest(_build_teaching_cycle_quest())
	_register_quest(_build_python_friday_quest())
	_register_quest(_build_it_cluster_quest())

	if _active_quest_id.is_empty():
		_active_quest_id = STARTER_QUEST_ID


func _register_quest(quest: Quest) -> void:
	if quest == null or quest.id.is_empty():
		return
	_quests[quest.id] = quest


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

	var next_quest_id := _find_next_quest_id(_active_quest_id)
	if next_quest_id.is_empty():
		return
	_active_quest_id = next_quest_id
	_activate_current_quest()


func _resolve_local_player_id() -> int:
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1


func _find_next_quest_id(current_quest_id: String) -> String:
	var index := QUEST_SEQUENCE.find(current_quest_id)
	if index == -1:
		return ""
	for i in range(index + 1, QUEST_SEQUENCE.size()):
		var candidate := QUEST_SEQUENCE[i]
		var quest_variant: Variant = _quests.get(candidate, null)
		if quest_variant is Quest:
			var quest := quest_variant as Quest
			if not quest.is_completed():
				return candidate
	return ""


func _find_first_available_quest_id() -> String:
	for quest_id in QUEST_SEQUENCE:
		var quest_variant: Variant = _quests.get(quest_id, null)
		if not (quest_variant is Quest):
			continue
		var quest := quest_variant as Quest
		if not quest.is_completed():
			return quest_id
	return STARTER_QUEST_ID


func _build_observatory_routine() -> Quest:
	var quest := Quest.new()
	quest.id = STARTER_QUEST_ID
	quest.title = "Observatory Routine"
	quest.objectives = [
		_create_collect_mug_objective(),
		_create_use_station_objective(),
		_create_complete_observe_objective(),
	]
	return quest


func _build_meet_professor_quest() -> Quest:
	var quest := Quest.new()
	quest.id = "meet_professor"
	quest.title = "Meet Your Professor"
	var talk := TalkToNpcObjective.new()
	talk.target_npc_id = "professor_alvarez"
	talk.description = "Visit Prof. Alvarez in office 101"
	var enter_office := EnterLocationObjective.new()
	enter_office.target_location_id = "office_101"
	enter_office.description = "Enter office 101"
	quest.objectives = [enter_office, talk]
	return quest


func _build_teaching_cycle_quest() -> Quest:
	var quest := Quest.new()
	quest.id = "teaching_cycle"
	quest.title = "Teaching Cycle"
	var tutor_task := TaskCompleteObjective.new()
	tutor_task.target_task = "tutor_class_session"
	tutor_task.description = "Complete a tutor class in the classroom"
	var deliver := DeliverHomeworkObjective.new()
	deliver.description = "Hand out homework copies to students"
	deliver.required_deliveries = 2
	var colloquium_task := TaskCompleteObjective.new()
	colloquium_task.target_task = "colloquium_attendance"
	colloquium_task.description = "Attend one colloquium session"
	quest.objectives = [tutor_task, deliver, colloquium_task]
	return quest


func _build_python_friday_quest() -> Quest:
	var quest := Quest.new()
	quest.id = "python_friday_path"
	quest.title = "Python Friday Track"
	var attendance := EventAttendanceObjective.new()
	attendance.target_event_id = "python_friday"
	attendance.required_attendances = 3
	attendance.description = "Attend Python Friday three times"
	quest.objectives = [attendance]
	return quest


func _build_it_cluster_quest() -> Quest:
	var quest := Quest.new()
	quest.id = "it_cluster_access"
	quest.title = "IT Cluster Access"
	var talk_it := TalkToNpcObjective.new()
	talk_it.target_npc_id = "it_admin"
	talk_it.description = "Speak with the IT coordinator"
	var onboarding := TaskCompleteObjective.new()
	onboarding.target_task = "it_cluster_onboarding"
	onboarding.description = "Complete IT cluster onboarding task"
	quest.objectives = [talk_it, onboarding]
	return quest


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
