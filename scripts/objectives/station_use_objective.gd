class_name StationUseObjective
extends Objective

@export var description: String = ""
@export var target_station: String
@export var required_uses: int = 1

var current_uses := 0


func activate(player_id: int = -1):
	target_player_id = player_id
	if EventBus != null and not EventBus.station_used.is_connected(_on_station_used):
		EventBus.station_used.connect(_on_station_used)


func cleanup():
	if EventBus != null and EventBus.station_used.is_connected(_on_station_used):
		EventBus.station_used.disconnect(_on_station_used)


func _on_station_used(player_id, station_id) -> void:
	if not is_event_for_player(int(player_id)):
		return
	if str(station_id) != target_station:
		return

	current_uses += 1
	progress_changed.emit()
	if current_uses >= required_uses:
		completed = true
		completed_changed.emit()


func get_progress_text() -> String:
	var label := description if not description.is_empty() else "Use %s" % target_station
	return "%s (%d/%d)" % [label, min(current_uses, required_uses), required_uses]


func save_state() -> Dictionary:
	var state := super.save_state()
	state["current_uses"] = current_uses
	return state


func load_state(data: Dictionary) -> void:
	super.load_state(data)
	current_uses = int(data.get("current_uses", current_uses))
