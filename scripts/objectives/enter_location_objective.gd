class_name EnterLocationObjective
extends Objective

@export var description: String = ""
@export var target_location_id: String = ""
@export var required_entries: int = 1

var current_entries := 0


func activate(player_id: int = -1) -> void:
	target_player_id = player_id
	if EventBus != null and EventBus.has_signal("location_entered"):
		if not EventBus.location_entered.is_connected(_on_location_entered):
			EventBus.location_entered.connect(_on_location_entered)


func cleanup() -> void:
	if EventBus != null and EventBus.has_signal("location_entered"):
		if EventBus.location_entered.is_connected(_on_location_entered):
			EventBus.location_entered.disconnect(_on_location_entered)


func _on_location_entered(player_id, location_id) -> void:
	if not is_event_for_player(int(player_id)):
		return
	if target_location_id != "" and str(location_id) != target_location_id:
		return

	current_entries += 1
	progress_changed.emit()
	if current_entries >= required_entries:
		completed = true
		completed_changed.emit()


func get_progress_text() -> String:
	var label := description if not description.is_empty() else "Go to %s" % target_location_id
	return "%s (%d/%d)" % [label, mini(current_entries, required_entries), required_entries]


func save_state() -> Dictionary:
	var state := super.save_state()
	state["current_entries"] = current_entries
	return state


func load_state(data: Dictionary) -> void:
	super.load_state(data)
	current_entries = int(data.get("current_entries", current_entries))
