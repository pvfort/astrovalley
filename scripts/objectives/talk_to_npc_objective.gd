class_name TalkToNpcObjective
extends Objective

@export var description: String = ""
@export var target_npc_id: String = ""
@export var required_talks: int = 1

var current_talks := 0


func activate(player_id: int = -1) -> void:
	target_player_id = player_id
	if EventBus != null and EventBus.has_signal("npc_talked_to"):
		if not EventBus.npc_talked_to.is_connected(_on_npc_talked_to):
			EventBus.npc_talked_to.connect(_on_npc_talked_to)


func cleanup() -> void:
	if EventBus != null and EventBus.has_signal("npc_talked_to"):
		if EventBus.npc_talked_to.is_connected(_on_npc_talked_to):
			EventBus.npc_talked_to.disconnect(_on_npc_talked_to)


func _on_npc_talked_to(player_id, npc_id) -> void:
	if not is_event_for_player(int(player_id)):
		return
	if target_npc_id != "" and str(npc_id) != target_npc_id:
		return

	current_talks += 1
	progress_changed.emit()
	if current_talks >= required_talks:
		completed = true
		completed_changed.emit()


func get_progress_text() -> String:
	var label := description if not description.is_empty() else "Talk to %s" % target_npc_id
	return "%s (%d/%d)" % [label, mini(current_talks, required_talks), required_talks]


func save_state() -> Dictionary:
	var state := super.save_state()
	state["current_talks"] = current_talks
	return state


func load_state(data: Dictionary) -> void:
	super.load_state(data)
	current_talks = int(data.get("current_talks", current_talks))
