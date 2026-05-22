class_name Quest
extends Resource

signal progressed
signal completed

enum QuestState {
	LOCKED,
	AVAILABLE,
	ACTIVE,
	COMPLETED,
	FAILED
}

@export var id: String
@export var title: String
@export var objectives: Array[Objective]

var state := QuestState.ACTIVE

func activate(player_id: int = -1) -> void:
	state = QuestState.ACTIVE
	for objective in objectives:
		if objective == null:
			continue
		if not objective.progress_changed.is_connected(_on_objective_progressed):
			objective.progress_changed.connect(_on_objective_progressed)
		if not objective.completed_changed.is_connected(_on_objective_completed):
			objective.completed_changed.connect(_on_objective_completed)
		objective.quest_id = id
		objective.activate(player_id)

func cleanup() -> void:
	for objective in objectives:
		if objective == null:
			continue
		if objective.progress_changed.is_connected(_on_objective_progressed):
			objective.progress_changed.disconnect(_on_objective_progressed)
		if objective.completed_changed.is_connected(_on_objective_completed):
			objective.completed_changed.disconnect(_on_objective_completed)
		objective.cleanup()

func is_completed() -> bool:
	for objective in objectives:
		if objective == null:
			continue
		if not objective.completed:
			return false
	return true

func get_next_incomplete_objective() -> Objective:
	for objective in objectives:
		if objective != null and not objective.completed:
			return objective
	return null

func save_state() -> Dictionary:
	var objective_states: Array[Dictionary] = []
	for objective in objectives:
		objective_states.append(objective.save_state() if objective != null else {})
	return {
		"id": id,
		"state": state,
		"objectives": objective_states,
	}

func load_state(data: Dictionary) -> void:
	state = int(data.get("state", state))
	var objective_states_variant: Variant = data.get("objectives", [])
	if not (objective_states_variant is Array):
		return
	var objective_states: Array = objective_states_variant as Array
	for i in range(min(objectives.size(), objective_states.size())):
		if objectives[i] == null or not (objective_states[i] is Dictionary):
			continue
		objectives[i].load_state(objective_states[i] as Dictionary)

func _on_objective_progressed() -> void:
	progressed.emit()

func _on_objective_completed() -> void:
	progressed.emit()
	if is_completed():
		state = QuestState.COMPLETED
		completed.emit()
