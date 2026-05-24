class_name DeliverHomeworkObjective
extends Objective

@export var description: String = ""
@export var required_deliveries: int = 1

var current_deliveries := 0


func activate(player_id: int = -1) -> void:
	target_player_id = player_id
	if EventBus != null and EventBus.has_signal("homework_delivered"):
		if not EventBus.homework_delivered.is_connected(_on_homework_delivered):
			EventBus.homework_delivered.connect(_on_homework_delivered)


func cleanup() -> void:
	if EventBus != null and EventBus.has_signal("homework_delivered"):
		if EventBus.homework_delivered.is_connected(_on_homework_delivered):
			EventBus.homework_delivered.disconnect(_on_homework_delivered)


func _on_homework_delivered(player_id, _npc_id, amount) -> void:
	if not is_event_for_player(int(player_id)):
		return

	current_deliveries += maxi(1, int(amount))
	progress_changed.emit()
	if current_deliveries >= required_deliveries:
		completed = true
		completed_changed.emit()


func get_progress_text() -> String:
	var label := description if not description.is_empty() else "Deliver homework copies"
	return "%s (%d/%d)" % [label, mini(current_deliveries, required_deliveries), required_deliveries]


func save_state() -> Dictionary:
	var state := super.save_state()
	state["current_deliveries"] = current_deliveries
	return state


func load_state(data: Dictionary) -> void:
	super.load_state(data)
	current_deliveries = int(data.get("current_deliveries", current_deliveries))
