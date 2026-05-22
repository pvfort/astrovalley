# Objective.gd
class_name Objective
extends Resource

signal progress_changed
signal completed_changed

var completed := false
var target_player_id := -1
var quest_id := ""

func activate(_player_id: int = -1):
	pass

func cleanup():
	pass

func is_event_for_player(player_id: int) -> bool:
	return target_player_id < 0 or target_player_id == player_id

func get_progress_text() -> String:
	return ""

func save_state() -> Dictionary:
	return {
		"completed": completed,
	}

func load_state(data: Dictionary) -> void:
	completed = bool(data.get("completed", completed))
