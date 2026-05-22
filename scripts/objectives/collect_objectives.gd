class_name CollectItemObjective
extends Objective

@export var description: String = ""
@export var target_item: String
@export var required_amount := 1

var current_amount := 0

func activate(player_id: int = -1):
	target_player_id = player_id
	if EventBus != null and not EventBus.item_collected.is_connected(_on_item_collected):
		EventBus.item_collected.connect(_on_item_collected)

func cleanup():
	if EventBus != null and EventBus.item_collected.is_connected(_on_item_collected):
		EventBus.item_collected.disconnect(_on_item_collected)

func _on_item_collected(player_id, item_id, amount):
	if not is_event_for_player(int(player_id)):
		return
	if item_id != target_item:
		return

	current_amount += amount
	progress_changed.emit()

	if current_amount >= required_amount:
		completed = true
		completed_changed.emit()

func get_progress_text() -> String:
	var label := description if not description.is_empty() else "Collect %s" % target_item
	return "%s (%d/%d)" % [label, min(current_amount, required_amount), required_amount]

func save_state() -> Dictionary:
	var state := super.save_state()
	state["current_amount"] = current_amount
	return state

func load_state(data: Dictionary) -> void:
	super.load_state(data)
	current_amount = int(data.get("current_amount", current_amount))
