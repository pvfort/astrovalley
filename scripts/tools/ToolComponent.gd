class_name ToolComponent
extends Node

signal tool_used(tool_id: String, context: StringName)
signal cooldown_updated(remaining_seconds: float)
signal durability_changed(current_durability: float)
signal power_changed(current_power: float)

@export var tool_data: ToolData

var current_durability: float = 0.0
var current_power: float = 0.0
var _last_used_time: float = -INF
var _equipped_modules: Dictionary = {}

func _ready() -> void:
	_initialize_runtime_state()

func _initialize_runtime_state() -> void:
	if tool_data == null:
		current_durability = 0.0
		current_power = 0.0
		return

	if current_durability <= 0.0:
		current_durability = maxf(tool_data.max_durability, 0.0)

	if current_power <= 0.0 and tool_data.battery_capacity > 0.0:
		current_power = tool_data.battery_capacity

func can_use(_context: StringName = &"") -> bool:
	if tool_data == null:
		return false

	if current_durability <= 0.0:
		return false

	if _is_on_cooldown():
		return false

	if tool_data.battery_capacity > 0.0 and current_power <= 0.0:
		return false

	return true

func apply_use(context: StringName = &"") -> bool:
	if not can_use(context):
		return false

	_last_used_time = Time.get_ticks_msec() / 1000.0
	_consume_durability(tool_data.durability_loss_per_use)
	_consume_power(tool_data.battery_drain_per_use)
	tool_used.emit(tool_data.tool_id, context)
	cooldown_updated.emit(get_cooldown_remaining())
	return true

func get_cooldown_remaining() -> float:
	if tool_data == null:
		return 0.0

	var elapsed := (Time.get_ticks_msec() / 1000.0) - _last_used_time
	return maxf(0.0, tool_data.cooldown_seconds - elapsed)

func get_interaction_modifiers(context: StringName) -> Dictionary:
	if tool_data == null:
		return {}
	return tool_data.get_context_modifiers(context)

func get_interaction_modifier(context: StringName, key: StringName, default_value: float = 1.0) -> float:
	if tool_data == null:
		return default_value
	return tool_data.get_modifier(context, key, default_value)

func get_scaled_value(base_value: float, scale_key: StringName, skill_level: int) -> float:
	if tool_data == null:
		return base_value

	var scale_per_level := tool_data.get_skill_scale(scale_key, 0.0)
	return base_value * (1.0 + (scale_per_level * float(maxi(skill_level, 0))))

func set_module(module_id: StringName, module_state: Variant = null) -> void:
	_equipped_modules[String(module_id)] = module_state

func get_module(module_id: StringName) -> Variant:
	return _equipped_modules.get(String(module_id), null)

func export_sync_state() -> Dictionary:
	return {
		"tool_id": tool_data.tool_id if tool_data != null else "",
		"current_durability": current_durability,
		"current_power": current_power,
		"last_used_time": _last_used_time,
		"modules": _equipped_modules.duplicate(true),
	}

func import_sync_state(sync_state: Dictionary) -> void:
	current_durability = float(sync_state.get("current_durability", current_durability))
	current_power = float(sync_state.get("current_power", current_power))
	_last_used_time = float(sync_state.get("last_used_time", _last_used_time))
	var modules := sync_state.get("modules", {})
	if modules is Dictionary:
		_equipped_modules = (modules as Dictionary).duplicate(true)

	durability_changed.emit(current_durability)
	power_changed.emit(current_power)
	cooldown_updated.emit(get_cooldown_remaining())

func _consume_durability(amount: float) -> void:
	if tool_data == null:
		return

	current_durability = clampf(current_durability - maxf(amount, 0.0), 0.0, tool_data.max_durability)
	durability_changed.emit(current_durability)

func _consume_power(amount: float) -> void:
	if tool_data == null or tool_data.battery_capacity <= 0.0:
		return

	current_power = clampf(current_power - maxf(amount, 0.0), 0.0, tool_data.battery_capacity)
	power_changed.emit(current_power)

func _is_on_cooldown() -> bool:
	return get_cooldown_remaining() > 0.0
