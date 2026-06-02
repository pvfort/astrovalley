extends Node

signal player_registered(player_id: int)
signal stress_changed(player_id: int, current_stress: float, max_stress: float)

const DEFAULT_MAX_STRESS := 100.0

const DEFAULT_ACTION_COSTS := {
	"coding": 12.0,
	"writing": 9.0,
	"observing": 8.0,
	"teaching": 10.0,
}

const DEFAULT_RECOVERY_VALUES := {
	"sleeping": 100.0,
	"sweets": 18.0,
	"tomfoolery": 14.0,
	"pie_friday": 20.0,
	"social": 12.0,
}

var _player_states: Dictionary = {}


func register_player(player_id: int, max_stress: float = DEFAULT_MAX_STRESS, current_stress: float = -1.0) -> void:
	var state := _get_state(player_id)
	state["max_stress"] = maxf(1.0, max_stress)
	if current_stress < 0.0:
		state["current_stress"] = float(state["max_stress"])
	else:
		state["current_stress"] = clampf(current_stress, 0.0, float(state["max_stress"]))
	_player_states[player_id] = state
	player_registered.emit(player_id)
	stress_changed.emit(player_id, float(state["current_stress"]), float(state["max_stress"]))


func has_player(player_id: int) -> bool:
	return _player_states.has(player_id)


func set_max_stress(player_id: int, value: float) -> void:
	var state := _get_state(player_id)
	state["max_stress"] = maxf(1.0, value)
	state["current_stress"] = clampf(float(state["current_stress"]), 0.0, float(state["max_stress"]))
	_player_states[player_id] = state
	stress_changed.emit(player_id, float(state["current_stress"]), float(state["max_stress"]))


func set_current_stress(player_id: int, value: float) -> void:
	var state := _get_state(player_id)
	state["current_stress"] = clampf(value, 0.0, float(state["max_stress"]))
	_player_states[player_id] = state
	stress_changed.emit(player_id, float(state["current_stress"]), float(state["max_stress"]))


func consume_stress(player_id: int, amount: float) -> bool:
	if amount <= 0.0:
		return true
	var state := _get_state(player_id)
	state["current_stress"] = maxf(0.0, float(state["current_stress"]) - amount)
	_player_states[player_id] = state
	stress_changed.emit(player_id, float(state["current_stress"]), float(state["max_stress"]))
	return float(state["current_stress"]) > 0.0


func recover_stress(player_id: int, amount: float) -> void:
	if amount <= 0.0:
		return
	var state := _get_state(player_id)
	state["current_stress"] = clampf(float(state["current_stress"]) + amount, 0.0, float(state["max_stress"]))
	_player_states[player_id] = state
	stress_changed.emit(player_id, float(state["current_stress"]), float(state["max_stress"]))


func consume_for_action(player_id: int, action_id: String, override_cost: float = -1.0) -> bool:
	var cost := override_cost
	if cost < 0.0:
		cost = get_action_cost(action_id)
	return consume_stress(player_id, cost)


func recover_for_activity(player_id: int, activity_id: String, override_amount: float = -1.0) -> void:
	var amount := override_amount
	if amount < 0.0:
		amount = get_recovery_value(activity_id)
	recover_stress(player_id, amount)


func recover_from_sleep(player_id: int) -> void:
	var state := _get_state(player_id)
	state["current_stress"] = float(state["max_stress"])
	_player_states[player_id] = state
	stress_changed.emit(player_id, float(state["current_stress"]), float(state["max_stress"]))


func get_action_cost(action_id: String) -> float:
	if DEFAULT_ACTION_COSTS.has(action_id):
		return float(DEFAULT_ACTION_COSTS[action_id])
	return 0.0


func get_recovery_value(activity_id: String) -> float:
	if DEFAULT_RECOVERY_VALUES.has(activity_id):
		return float(DEFAULT_RECOVERY_VALUES[activity_id])
	return 0.0


func get_current_stress(player_id: int) -> float:
	var state := _get_state(player_id)
	return float(state["current_stress"])


func get_max_stress(player_id: int) -> float:
	var state := _get_state(player_id)
	return float(state["max_stress"])


func save_state() -> Dictionary:
	var saved_players: Dictionary = {}
	for player_id_variant in _player_states.keys():
		var player_id := int(player_id_variant)
		var state := _get_state(player_id)
		saved_players[str(player_id)] = {
			"max_stress": float(state["max_stress"]),
			"current_stress": float(state["current_stress"]),
		}
	return {
		"players": saved_players,
	}


func load_state(data: Dictionary) -> void:
	_player_states.clear()
	var players: Variant = data.get("players", {})
	if not (players is Dictionary):
		return
	for player_id_key in (players as Dictionary).keys():
		var player_data_variant: Variant = (players as Dictionary).get(player_id_key, {})
		if not (player_data_variant is Dictionary):
			continue
		var player_data := player_data_variant as Dictionary
		var state := _default_state()
		state["max_stress"] = maxf(1.0, float(player_data.get("max_stress", DEFAULT_MAX_STRESS)))
		state["current_stress"] = clampf(float(player_data.get("current_stress", state["max_stress"])), 0.0, float(state["max_stress"]))
		var player_id := int(str(player_id_key))
		_player_states[player_id] = state
		stress_changed.emit(player_id, float(state["current_stress"]), float(state["max_stress"]))


func export_snapshot() -> Dictionary:
	return save_state()


func import_snapshot(data: Dictionary) -> void:
	load_state(data)


func _get_state(player_id: int) -> Dictionary:
	if not _player_states.has(player_id):
		_player_states[player_id] = _default_state()
	return (_player_states[player_id] as Dictionary).duplicate(true)


func _default_state() -> Dictionary:
	return {
		"max_stress": DEFAULT_MAX_STRESS,
		"current_stress": DEFAULT_MAX_STRESS,
	}
