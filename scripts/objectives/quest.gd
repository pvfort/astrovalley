class_name Quest
extends Resource

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

func is_completed() -> bool:
	for objective in objectives:
		if not objective.completed:
			return false
	return true
