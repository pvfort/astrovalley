extends Node

# GameManager: Manages overall game state
signal player_task_changed(player_id: int, task_id: String)
signal player_stats_changed(player_id: int, player_state: Dictionary)

var players: Dictionary = {}  # id -> player_data
var resources: Dictionary = {}  # resource_name -> {locked: bool, by: int}

func _ready():
	# Initialize resources
	resources["telescope"] = {"locked": false, "by": -1}

	if TaskManager != null:
		if not TaskManager.task_started.is_connected(_on_task_started):
			TaskManager.task_started.connect(_on_task_started)
		if not TaskManager.task_completed.is_connected(_on_task_completed):
			TaskManager.task_completed.connect(_on_task_completed)

@warning_ignore("shadowed_variable_base_class")
func add_player(id: int, name: String):
	var existing: Dictionary = players.get(id, {})
	players[id] = {
		"name": name,
		"current_task": str(existing.get("current_task", "")),
		"tasks_completed": int(existing.get("tasks_completed", 0)),
		"observation_total": int(existing.get("observation_total", 0)),
	}

func remove_player(id: int):
	players.erase(id)

func is_resource_available(resource: String) -> bool:
	if resources.has(resource):
		return not resources[resource]["locked"]
	return false

func lock_resource(resource: String, player_id: int) -> bool:
	if is_resource_available(resource):
		resources[resource]["locked"] = true
		resources[resource]["by"] = player_id
		return true
	return false

func unlock_resource(resource: String):
	if resources.has(resource):
		resources[resource]["locked"] = false
		resources[resource]["by"] = -1

func get_resource_holder(resource: String) -> int:
	if resources.has(resource) and resources[resource]["locked"]:
		return resources[resource]["by"]
	return -1

func get_player_state(player_id: int) -> Dictionary:
	if not players.has(player_id):
		return {}
	return (players[player_id] as Dictionary).duplicate(true)

func get_current_task(player_id: int) -> String:
	return str(get_player_state(player_id).get("current_task", ""))

func record_observation_output(player_id: int, amount: int) -> void:
	if amount <= 0:
		return

	var player_state := _ensure_player_state(player_id)
	player_state["observation_total"] = int(player_state.get("observation_total", 0)) + amount
	_emit_player_state(player_id)

func save_state() -> Dictionary:
	var serialized_players: Dictionary = {}
	for player_id_variant in players.keys():
		var player_id: int = int(player_id_variant)
		serialized_players[str(player_id)] = get_player_state(player_id)

	return {
		"players": serialized_players,
		"resources": resources.duplicate(true),
	}

func load_state(data: Dictionary) -> void:
	players.clear()

	var saved_players :Variant= data.get("players", {})
	if saved_players is Dictionary:
		for player_id_variant in (saved_players as Dictionary).keys():
			var player_id: int = int(player_id_variant)
			var player_state_variant: Variant = (saved_players as Dictionary).get(player_id_variant, {})
			if not (player_state_variant is Dictionary):
				continue
			var player_state: Dictionary = (player_state_variant as Dictionary).duplicate(true)
			players[player_id] = {
				"name": str(player_state.get("name", "Player%s" % str(player_id))),
				"current_task": str(player_state.get("current_task", "")),
				"tasks_completed": int(player_state.get("tasks_completed", 0)),
				"observation_total": int(player_state.get("observation_total", 0)),
			}

	var saved_resources :Variant= data.get("resources", {})
	if saved_resources is Dictionary:
		resources = (saved_resources as Dictionary).duplicate(true)
	if not resources.has("telescope"):
		resources["telescope"] = {"locked": false, "by": -1}

func _on_task_started(player_id: int, task_id: String) -> void:
	var player_state := _ensure_player_state(player_id)
	player_state["current_task"] = task_id
	_emit_player_state(player_id)

func _on_task_completed(player_id: int, _task_id: String) -> void:
	var player_state := _ensure_player_state(player_id)
	player_state["current_task"] = ""
	player_state["tasks_completed"] = int(player_state.get("tasks_completed", 0)) + 1
	_emit_player_state(player_id)

func _ensure_player_state(player_id: int) -> Dictionary:
	if not players.has(player_id):
		add_player(player_id, "Player" + str(player_id))
	return players[player_id] as Dictionary

func _emit_player_state(player_id: int) -> void:
	var state := get_player_state(player_id)
	player_task_changed.emit(player_id, str(state.get("current_task", "")))
	player_stats_changed.emit(player_id, state)
