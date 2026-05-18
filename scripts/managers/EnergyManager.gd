extends Node

signal player_registered(player_id: int)
signal energy_changed(player_id: int, current_energy: float, max_energy: float)
signal exhaustion_changed(player_id: int, exhausted: bool)

const DEFAULT_MAX_ENERGY := 100.0
const EXHAUSTED_THRESHOLD_RATIO := 0.2
const EXHAUSTED_MOVEMENT_MULTIPLIER := 0.7
const EXHAUSTED_XP_MULTIPLIER := 0.75
const EXHAUSTED_ACTION_SPEED_MULTIPLIER := 0.75

const DEFAULT_ACTION_COSTS := {
	"programming": 12.0,
	"observation": 10.0,
	"maintenance": 14.0,
	"exploration": 8.0,
	"teaching": 9.0,
	"exercise": 16.0,
}

const DEFAULT_RECOVERY_VALUES := {
	"resting": 10.0,
	"food": 20.0,
	"coffee_restore": 18.0,
	"coffee_temp_max_bonus": 12.0,
	"coffee_temp_max_duration": 180.0,
}

var _player_states: Dictionary = {}


func _process(delta: float) -> void:
	for player_id_variant in _player_states.keys():
		var player_id := int(player_id_variant)
		var state := _get_state(player_id)
		var previous_bonus := float(state["temporary_max_bonus"])
		var previous_exhausted := bool(state["exhausted"])
		var duration := float(state["temporary_max_duration"])
		if duration > 0.0:
			duration = maxf(0.0, duration - delta)
			state["temporary_max_duration"] = duration
			if duration <= 0.0:
				state["temporary_max_bonus"] = 0.0
		_recalculate_exhaustion(state)
		_clamp_current_energy(state)
		_player_states[player_id] = state
		if not is_equal_approx(previous_bonus, float(state["temporary_max_bonus"])):
			energy_changed.emit(player_id, float(state["current_energy"]), _resolve_max_energy(state))
		if previous_exhausted != bool(state["exhausted"]):
			exhaustion_changed.emit(player_id, bool(state["exhausted"]))


func register_player(player_id: int, max_energy: float = DEFAULT_MAX_ENERGY, current_energy: float = -1.0) -> void:
	var state := _get_state(player_id)
	state["max_energy"] = maxf(1.0, max_energy)
	if current_energy < 0.0:
		state["current_energy"] = float(state["max_energy"])
	else:
		state["current_energy"] = clampf(current_energy, 0.0, _resolve_max_energy(state))
	_recalculate_exhaustion(state)
	_player_states[player_id] = state
	player_registered.emit(player_id)
	energy_changed.emit(player_id, float(state["current_energy"]), _resolve_max_energy(state))
	exhaustion_changed.emit(player_id, bool(state["exhausted"]))


func has_player(player_id: int) -> bool:
	return _player_states.has(player_id)


func set_max_energy(player_id: int, value: float) -> void:
	var state := _get_state(player_id)
	state["max_energy"] = maxf(1.0, value)
	_clamp_current_energy(state)
	_recalculate_exhaustion(state)
	_player_states[player_id] = state
	energy_changed.emit(player_id, float(state["current_energy"]), _resolve_max_energy(state))
	exhaustion_changed.emit(player_id, bool(state["exhausted"]))


func set_current_energy(player_id: int, value: float) -> void:
	var state := _get_state(player_id)
	state["current_energy"] = clampf(value, 0.0, _resolve_max_energy(state))
	var was_exhausted := bool(state["exhausted"])
	_recalculate_exhaustion(state)
	_player_states[player_id] = state
	energy_changed.emit(player_id, float(state["current_energy"]), _resolve_max_energy(state))
	if was_exhausted != bool(state["exhausted"]):
		exhaustion_changed.emit(player_id, bool(state["exhausted"]))


func consume_energy(player_id: int, amount: float) -> bool:
	if amount <= 0.0:
		return true
	var state := _get_state(player_id)
	state["current_energy"] = maxf(0.0, float(state["current_energy"]) - amount)
	var was_exhausted := bool(state["exhausted"])
	_recalculate_exhaustion(state)
	_player_states[player_id] = state
	energy_changed.emit(player_id, float(state["current_energy"]), _resolve_max_energy(state))
	if was_exhausted != bool(state["exhausted"]):
		exhaustion_changed.emit(player_id, bool(state["exhausted"]))
	return float(state["current_energy"]) > 0.0


func consume_for_action(player_id: int, action_id: String, override_cost: float = -1.0) -> bool:
	var cost := override_cost
	if cost < 0.0:
		cost = get_action_cost(action_id)
	return consume_energy(player_id, cost)


func recover_energy(player_id: int, amount: float) -> void:
	if amount <= 0.0:
		return
	var state := _get_state(player_id)
	state["current_energy"] = clampf(float(state["current_energy"]) + amount, 0.0, _resolve_max_energy(state))
	var was_exhausted := bool(state["exhausted"])
	_recalculate_exhaustion(state)
	_player_states[player_id] = state
	energy_changed.emit(player_id, float(state["current_energy"]), _resolve_max_energy(state))
	if was_exhausted != bool(state["exhausted"]):
		exhaustion_changed.emit(player_id, bool(state["exhausted"]))


func recover_from_sleep(player_id: int) -> void:
	var state := _get_state(player_id)
	state["temporary_max_bonus"] = 0.0
	state["temporary_max_duration"] = 0.0
	state["current_energy"] = _resolve_max_energy(state)
	state["exhausted"] = false
	_player_states[player_id] = state
	energy_changed.emit(player_id, float(state["current_energy"]), _resolve_max_energy(state))
	exhaustion_changed.emit(player_id, false)


func recover_from_rest(player_id: int, amount: float = -1.0) -> void:
	var recover_amount := amount
	if recover_amount < 0.0:
		recover_amount = float(DEFAULT_RECOVERY_VALUES["resting"])
	recover_energy(player_id, recover_amount)


func recover_from_food(player_id: int, amount: float = -1.0) -> void:
	var recover_amount := amount
	if recover_amount < 0.0:
		recover_amount = float(DEFAULT_RECOVERY_VALUES["food"])
	recover_energy(player_id, recover_amount)


func recover_from_coffee(player_id: int, restore_amount: float = -1.0, temp_max_bonus: float = -1.0, temp_duration: float = -1.0) -> void:
	var applied_restore := restore_amount if restore_amount >= 0.0 else float(DEFAULT_RECOVERY_VALUES["coffee_restore"])
	var applied_bonus := temp_max_bonus if temp_max_bonus >= 0.0 else float(DEFAULT_RECOVERY_VALUES["coffee_temp_max_bonus"])
	var applied_duration := temp_duration if temp_duration >= 0.0 else float(DEFAULT_RECOVERY_VALUES["coffee_temp_max_duration"])
	if applied_bonus > 0.0 and applied_duration > 0.0:
		apply_temporary_max_energy(player_id, applied_bonus, applied_duration)
	recover_energy(player_id, applied_restore)


func apply_temporary_max_energy(player_id: int, bonus: float, duration: float) -> void:
	if bonus <= 0.0 or duration <= 0.0:
		return
	var state := _get_state(player_id)
	state["temporary_max_bonus"] = maxf(float(state["temporary_max_bonus"]), bonus)
	state["temporary_max_duration"] = maxf(float(state["temporary_max_duration"]), duration)
	_clamp_current_energy(state)
	_recalculate_exhaustion(state)
	_player_states[player_id] = state
	energy_changed.emit(player_id, float(state["current_energy"]), _resolve_max_energy(state))
	exhaustion_changed.emit(player_id, bool(state["exhausted"]))


func get_action_cost(action_id: String) -> float:
	if DEFAULT_ACTION_COSTS.has(action_id):
		return float(DEFAULT_ACTION_COSTS[action_id])
	return 0.0


func get_current_energy(player_id: int) -> float:
	var state := _get_state(player_id)
	return float(state["current_energy"])


func get_max_energy(player_id: int) -> float:
	var state := _get_state(player_id)
	return _resolve_max_energy(state)


func get_base_max_energy(player_id: int) -> float:
	var state := _get_state(player_id)
	return float(state["max_energy"])


func is_exhausted(player_id: int) -> bool:
	var state := _get_state(player_id)
	return bool(state["exhausted"])


func get_movement_speed_multiplier(player_id: int) -> float:
	if is_exhausted(player_id):
		return EXHAUSTED_MOVEMENT_MULTIPLIER
	return 1.0


func get_xp_gain_multiplier(player_id: int) -> float:
	if is_exhausted(player_id):
		return EXHAUSTED_XP_MULTIPLIER
	return 1.0


func get_action_speed_multiplier(player_id: int) -> float:
	if is_exhausted(player_id):
		return EXHAUSTED_ACTION_SPEED_MULTIPLIER
	return 1.0


func save_state() -> Dictionary:
	var saved_players: Dictionary = {}
	for player_id_variant in _player_states.keys():
		var player_id := int(player_id_variant)
		var state := _get_state(player_id)
		saved_players[str(player_id)] = {
			"max_energy": float(state["max_energy"]),
			"current_energy": float(state["current_energy"]),
			"temporary_max_bonus": float(state["temporary_max_bonus"]),
			"temporary_max_duration": float(state["temporary_max_duration"]),
			"exhausted": bool(state["exhausted"]),
		}
	return {
		"players": saved_players,
	}


func load_state(data: Dictionary) -> void:
	_player_states.clear()
	var players := data.get("players", {})
	if not (players is Dictionary):
		return
	for player_id_key in (players as Dictionary).keys():
		var player_data_variant := (players as Dictionary).get(player_id_key, {})
		if not (player_data_variant is Dictionary):
			continue
		var player_data := player_data_variant as Dictionary
		var state := _default_state()
		state["max_energy"] = maxf(1.0, float(player_data.get("max_energy", DEFAULT_MAX_ENERGY)))
		state["temporary_max_bonus"] = maxf(0.0, float(player_data.get("temporary_max_bonus", 0.0)))
		state["temporary_max_duration"] = maxf(0.0, float(player_data.get("temporary_max_duration", 0.0)))
		state["current_energy"] = clampf(float(player_data.get("current_energy", state["max_energy"])), 0.0, _resolve_max_energy(state))
		_recalculate_exhaustion(state)
		var player_id := int(str(player_id_key))
		_player_states[player_id] = state
		energy_changed.emit(player_id, float(state["current_energy"]), _resolve_max_energy(state))
		exhaustion_changed.emit(player_id, bool(state["exhausted"]))


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
		"max_energy": DEFAULT_MAX_ENERGY,
		"current_energy": DEFAULT_MAX_ENERGY,
		"temporary_max_bonus": 0.0,
		"temporary_max_duration": 0.0,
		"exhausted": false,
	}


func _resolve_max_energy(state: Dictionary) -> float:
	return maxf(1.0, float(state.get("max_energy", DEFAULT_MAX_ENERGY)) + float(state.get("temporary_max_bonus", 0.0)))


func _clamp_current_energy(state: Dictionary) -> void:
	state["current_energy"] = clampf(float(state.get("current_energy", 0.0)), 0.0, _resolve_max_energy(state))


func _recalculate_exhaustion(state: Dictionary) -> void:
	var max_energy := _resolve_max_energy(state)
	var current_energy := float(state.get("current_energy", 0.0))
	state["exhausted"] = current_energy <= (max_energy * EXHAUSTED_THRESHOLD_RATIO)
