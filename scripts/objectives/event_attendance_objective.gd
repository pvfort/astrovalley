class_name EventAttendanceObjective
extends Objective

@export var description: String = ""
@export var target_event_id: String = ""
@export var required_attendances: int = 1

var current_attendances := 0


func activate(player_id: int = -1) -> void:
	target_player_id = player_id
	if EventBus != null and EventBus.has_signal("event_attended"):
		if not EventBus.event_attended.is_connected(_on_event_attended):
			EventBus.event_attended.connect(_on_event_attended)


func cleanup() -> void:
	if EventBus != null and EventBus.has_signal("event_attended"):
		if EventBus.event_attended.is_connected(_on_event_attended):
			EventBus.event_attended.disconnect(_on_event_attended)


func _on_event_attended(player_id, event_id, _attendance_count) -> void:
	if not is_event_for_player(int(player_id)):
		return
	if target_event_id != "" and str(event_id) != target_event_id:
		return

	current_attendances += 1
	progress_changed.emit()
	if current_attendances >= required_attendances:
		completed = true
		completed_changed.emit()


func get_progress_text() -> String:
	var label := description if not description.is_empty() else "Attend %s" % target_event_id
	return "%s (%d/%d)" % [label, mini(current_attendances, required_attendances), required_attendances]


func save_state() -> Dictionary:
	var state := super.save_state()
	state["current_attendances"] = current_attendances
	return state


func load_state(data: Dictionary) -> void:
	super.load_state(data)
	current_attendances = int(data.get("current_attendances", current_attendances))
