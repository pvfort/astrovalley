extends Node

signal time_changed(hour: int, minute: int)
signal hour_changed(hour: int)
signal day_changed(day: int)
signal phase_changed(phase_name: String)
signal daily_summary_requested(summary_data: Dictionary)

@export var real_seconds_per_game_minute: float = 1.0
@export var morning_start_hour: int = 6
@export var afternoon_start_hour: int = 12
@export var evening_start_hour: int = 18
@export var night_start_hour: int = 22

var current_day: int = 1
var current_hour: int = 8
var current_minute: int = 0

var _phase_name: String = "Morning"
var _accumulator: float = 0.0

var _daily_stats := {
    "xp_gained_per_skill": {},
    "money_earned": 0,
    "tasks_completed": 0,
    "observation_data_collected": 0,
    "programming_progress": 0,
}

func _ready() -> void:
    set_process(true)
    if multiplayer != null:
        multiplayer.peer_connected.connect(_on_peer_connected)
        if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
            rpc_id(1, "request_clock_sync")
    _emit_all_signals(true, true, true)

func _process(delta: float) -> void:
    if real_seconds_per_game_minute <= 0.0:
        return

    if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
        return

    _accumulator += delta
    while _accumulator >= real_seconds_per_game_minute:
        _accumulator -= real_seconds_per_game_minute
        _advance_one_minute()

func _advance_one_minute() -> void:
    var previous_hour := current_hour
    var previous_phase := _phase_name

    current_minute += 1
    if current_minute >= 60:
        current_minute = 0
        current_hour += 1
        if current_hour >= 24:
            current_hour = 0
            current_day += 1
            day_changed.emit(current_day)

    _phase_name = _resolve_phase_name(current_hour)
    time_changed.emit(current_hour, current_minute)

    if previous_hour != current_hour:
        hour_changed.emit(current_hour)

    if previous_phase != _phase_name:
        phase_changed.emit(_phase_name)

    _sync_to_clients()

func add_minutes(minutes: int) -> void:
    if minutes <= 0:
        return
    for _i in range(minutes):
        _advance_one_minute()

func skip_to_next_morning(morning_hour: int = 8) -> void:
    if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
        rpc_id(1, "server_skip_to_next_morning", morning_hour)
        return

    current_day += 1
    current_hour = clampi(morning_hour, 0, 23)
    current_minute = 0
    _phase_name = _resolve_phase_name(current_hour)
    _accumulator = 0.0
    _emit_all_signals(true, true, true)
    _sync_to_clients()

func set_time(day: int, hour: int, minute: int) -> void:
    current_day = maxi(1, day)
    current_hour = clampi(hour, 0, 23)
    current_minute = clampi(minute, 0, 59)
    _phase_name = _resolve_phase_name(current_hour)
    _emit_all_signals(true, true, true)
    _sync_to_clients()

func get_time_string() -> String:
    return "%02d:%02d" % [current_hour, current_minute]

func get_phase_name() -> String:
    return _phase_name

func _resolve_phase_name(hour: int) -> String:
    if hour >= morning_start_hour and hour < afternoon_start_hour:
        return "Morning"
    if hour >= afternoon_start_hour and hour < evening_start_hour:
        return "Afternoon"
    if hour >= evening_start_hour and hour < night_start_hour:
        return "Evening"
    return "Night"

func _emit_all_signals(emit_time: bool, emit_hour: bool, emit_day: bool) -> void:
    if emit_time:
        time_changed.emit(current_hour, current_minute)

    var new_phase := _resolve_phase_name(current_hour)
    if _phase_name != new_phase:
        _phase_name = new_phase
    phase_changed.emit(_phase_name)

    if emit_hour:
        hour_changed.emit(current_hour)
    if emit_day:
        day_changed.emit(current_day)

func _sync_to_clients() -> void:
    if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
        rpc("sync_clock", current_day, current_hour, current_minute, _phase_name)

@rpc("any_peer", "reliable")
func request_clock_sync() -> void:
    if multiplayer.is_server():
        rpc_id(multiplayer.get_remote_sender_id(), "sync_clock", current_day, current_hour, current_minute, _phase_name)

@rpc("authority", "reliable")
func sync_clock(day: int, hour: int, minute: int, phase_name: String) -> void:
    var previous_day := current_day
    var previous_hour := current_hour
    var previous_phase := _phase_name

    current_day = day
    current_hour = hour
    current_minute = minute
    _phase_name = phase_name

    time_changed.emit(current_hour, current_minute)
    if previous_hour != current_hour:
        hour_changed.emit(current_hour)
    if previous_day != current_day:
        day_changed.emit(current_day)
    if previous_phase != _phase_name:
        phase_changed.emit(_phase_name)

@rpc("any_peer", "reliable")
func server_skip_to_next_morning(morning_hour: int = 8) -> void:
    if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
        return
    skip_to_next_morning(morning_hour)

func get_daily_summary_data() -> Dictionary:
    return {
        "xp_gained_per_skill": (_daily_stats["xp_gained_per_skill"] as Dictionary).duplicate(true),
        "money_earned": _daily_stats["money_earned"],
        "tasks_completed": _daily_stats["tasks_completed"],
        "observation_data_collected": _daily_stats["observation_data_collected"],
        "programming_progress": _daily_stats["programming_progress"],
    }

func reset_daily_summary_data() -> void:
    _daily_stats = {
        "xp_gained_per_skill": {},
        "money_earned": 0,
        "tasks_completed": 0,
        "observation_data_collected": 0,
        "programming_progress": 0,
    }

func request_daily_summary() -> void:
    daily_summary_requested.emit(get_daily_summary_data())

func add_daily_skill_xp(skill_id: String, amount: int) -> void:
    if skill_id == "" or amount <= 0:
        return
    var skill_xp := _daily_stats["xp_gained_per_skill"] as Dictionary
    skill_xp[skill_id] = int(skill_xp.get(skill_id, 0)) + amount

func add_daily_money(amount: int) -> void:
    if amount > 0:
        _daily_stats["money_earned"] += amount

func increment_daily_tasks_completed(amount: int = 1) -> void:
    if amount > 0:
        _daily_stats["tasks_completed"] += amount

func add_observation_data(amount: int) -> void:
    if amount > 0:
        _daily_stats["observation_data_collected"] += amount

func add_programming_progress(amount: int) -> void:
    if amount > 0:
        _daily_stats["programming_progress"] += amount

func _on_peer_connected(id: int) -> void:
    if multiplayer.is_server():
        rpc_id(id, "sync_clock", current_day, current_hour, current_minute, _phase_name)
