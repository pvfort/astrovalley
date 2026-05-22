class_name TaskCompleteObjective
extends Objective

@export var description: String = ""
@export var target_task: String
@export var required_completions: int = 1

var current_completions := 0


func activate(player_id: int = -1):
	target_player_id = player_id
	if EventBus != null and not EventBus.task_completed.is_connected(_on_task_completed):
		EventBus.task_completed.connect(_on_task_completed)


func cleanup():
	if EventBus != null and EventBus.task_completed.is_connected(_on_task_completed):
		EventBus.task_completed.disconnect(_on_task_completed)


func _on_task_completed(player_id, task_id) -> void:
	if not is_event_for_player(int(player_id)):
		return
	if str(task_id) != target_task:
		return

	current_completions += 1
	progress_changed.emit()
	if current_completions >= required_completions:
		completed = true
		completed_changed.emit()


func get_progress_text() -> String:
	var label := description if not description.is_empty() else "Complete %s" % target_task
	return "%s (%d/%d)" % [label, min(current_completions, required_completions), required_completions]


func save_state() -> Dictionary:
	var state := super.save_state()
	state["current_completions"] = current_completions
	return state


func load_state(data: Dictionary) -> void:
	super.load_state(data)
	current_completions = int(data.get("current_completions", current_completions))
