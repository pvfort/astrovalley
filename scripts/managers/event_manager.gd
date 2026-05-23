extends Node

signal world_event_started(event_id: String, event_data: Dictionary)
signal world_event_ended(event_id: String, event_data: Dictionary)
signal active_events_changed(active_events: Array[Dictionary])

const EVENTS_DATA_PATH: String = "res://data/world_events.json"
const DEFAULT_WEEKDAY: int = 1
const WEEK_LENGTH_DAYS: int = 7

var _event_definitions: Array[Dictionary] = []
var _active_events: Dictionary = {}
var _last_evaluated_hour_key: String = ""


func _ready() -> void:
	_load_event_definitions()
	if WorldClock != null:
		if not WorldClock.hour_changed.is_connected(_on_world_hour_changed):
			WorldClock.hour_changed.connect(_on_world_hour_changed)
		if not WorldClock.day_changed.is_connected(_on_world_day_changed):
			WorldClock.day_changed.connect(_on_world_day_changed)
	if WeatherManager != null and WeatherManager.has_signal("weather_changed"):
		if not WeatherManager.weather_changed.is_connected(_on_weather_changed):
			WeatherManager.weather_changed.connect(_on_weather_changed)
	_refresh_active_events(true)


func get_active_events() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for event_data in _active_events.values():
		if event_data is Dictionary:
			output.append((event_data as Dictionary).duplicate(true))
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")) < str(b.get("name", "")))
	return output


func is_event_active(event_id: String) -> bool:
	return _active_events.has(event_id)


func get_primary_event() -> Dictionary:
	var active := get_active_events()
	if active.is_empty():
		return {}
	return active[0]


func save_state() -> Dictionary:
	return {
		"active_event_ids": _active_events.keys(),
		"last_evaluated_hour_key": _last_evaluated_hour_key,
	}


func load_state(_data: Dictionary) -> void:
	_refresh_active_events(true)


func _on_world_day_changed(_day: int) -> void:
	_refresh_active_events()


func _on_world_hour_changed(_hour: int) -> void:
	_refresh_active_events()


func _on_weather_changed(_weather_name: String, _weather_data: Dictionary) -> void:
	_refresh_active_events(true)


func _refresh_active_events(force: bool = false) -> void:
	var now := _get_world_now()
	if now.is_empty():
		return

	var day := int(now.get("day", 1))
	var hour := int(now.get("hour", 0))
	var now_key := "%d:%d" % [day, hour]
	if not force and now_key == _last_evaluated_hour_key:
		return
	_last_evaluated_hour_key = now_key

	var next_active: Dictionary = {}
	for event_definition in _event_definitions:
		var activation := _resolve_event_activation(event_definition, day, hour)
		if activation.is_empty():
			continue
		var event_id := str(event_definition.get("id", ""))
		if event_id.is_empty():
			continue
		next_active[event_id] = activation

	for event_id in _active_events.keys():
		if next_active.has(event_id):
			continue
		var ended_event := _active_events[event_id] as Dictionary
		world_event_ended.emit(event_id, ended_event.duplicate(true))
		if EventBus != null and EventBus.has_signal("world_event_ended"):
			EventBus.world_event_ended.emit(event_id, ended_event.duplicate(true))

	for event_id in next_active.keys():
		if _active_events.has(event_id):
			continue
		var started_event := next_active[event_id] as Dictionary
		world_event_started.emit(event_id, started_event.duplicate(true))
		if EventBus != null and EventBus.has_signal("world_event_started"):
			EventBus.world_event_started.emit(event_id, started_event.duplicate(true))

	_active_events = next_active
	var active_snapshot := get_active_events()
	active_events_changed.emit(active_snapshot)
	if EventBus != null and EventBus.has_signal("world_events_updated"):
		EventBus.world_events_updated.emit(active_snapshot)


func _resolve_event_activation(event_definition: Dictionary, day: int, hour: int) -> Dictionary:
	var event_id := str(event_definition.get("id", ""))
	if event_id.is_empty():
		return {}

	var cycle_anchor_day := _resolve_cycle_anchor_day(event_definition, day)
	if cycle_anchor_day <= 0:
		return {}
	if not _is_day_window_active(event_definition, day):
		return {}
	if not _is_time_window_active(event_definition, hour):
		return {}
	if not _meets_conditions(event_definition, day, cycle_anchor_day):
		return {}

	var output := event_definition.duplicate(true)
	output["current_day"] = day
	output["current_hour"] = hour
	output["cycle_start_day"] = cycle_anchor_day
	output["weekday"] = get_weekday_name(day)
	return output


func _is_day_window_active(event_definition: Dictionary, day: int) -> bool:
	var duration_days := maxi(1, int(event_definition.get("duration_days", 1)))
	var start_day := maxi(1, int(event_definition.get("start_day", 1)))
	var repeat_interval_days := int(event_definition.get("repeat_interval_days", 0))

	var weekdays_variant := event_definition.get("weekdays", [])
	if weekdays_variant is Array:
		var weekdays := weekdays_variant as Array
		if not weekdays.is_empty():
			return weekdays.has(get_weekday_index(day))

	if repeat_interval_days > 0:
		if day < start_day:
			return false
		var elapsed := day - start_day
		var cycle_day := elapsed % repeat_interval_days
		return cycle_day >= 0 and cycle_day < duration_days

	if day < start_day:
		return false
	return day < start_day + duration_days


func _is_time_window_active(event_definition: Dictionary, hour: int) -> bool:
	var start_hour := clampi(int(event_definition.get("start_hour", 0)), 0, 23)
	var end_hour := clampi(int(event_definition.get("end_hour", 24)), 0, 24)
	if start_hour == end_hour:
		return true
	if start_hour < end_hour:
		return hour >= start_hour and hour < end_hour
	return hour >= start_hour or hour < end_hour


func _meets_conditions(event_definition: Dictionary, day: int, cycle_anchor_day: int) -> bool:
	var required_season := str(event_definition.get("required_season", "")).strip_edges().to_lower()
	if not required_season.is_empty():
		if WeatherManager == null:
			return false
		var current_season := str(WeatherManager.current_season).strip_edges().to_lower()
		if current_season != required_season:
			return false

	var required_weather_variant := event_definition.get("required_weather", [])
	if required_weather_variant is Array:
		var required_weather := required_weather_variant as Array
		if not required_weather.is_empty():
			if WeatherManager == null:
				return false
			var current_weather := str(WeatherManager.current_weather).strip_edges().to_lower()
			var normalized_required: Array[String] = []
			for weather_name in required_weather:
				normalized_required.append(str(weather_name).strip_edges().to_lower())
			if not normalized_required.has(current_weather):
				return false

	var min_day := int(event_definition.get("min_day", 1))
	if day < min_day:
		return false

	var chance := clampf(float(event_definition.get("chance", 1.0)), 0.0, 1.0)
	if chance >= 1.0:
		return true
	var chance_key := "%s:%d" % [str(event_definition.get("id", "")), cycle_anchor_day]
	var roll := abs(int(hash(chance_key)) % 10000) / 10000.0
	return roll < chance


func _resolve_cycle_anchor_day(event_definition: Dictionary, day: int) -> int:
	if day <= 0:
		return -1
	var weekdays_variant := event_definition.get("weekdays", [])
	if weekdays_variant is Array and not (weekdays_variant as Array).is_empty():
		return day

	var start_day := maxi(1, int(event_definition.get("start_day", 1)))
	var repeat_interval_days := int(event_definition.get("repeat_interval_days", 0))
	if repeat_interval_days > 0:
		if day < start_day:
			return -1
		var elapsed := day - start_day
		var cycle_index := int(elapsed / repeat_interval_days)
		return start_day + cycle_index * repeat_interval_days
	return start_day


func get_weekday_index(day: int) -> int:
	var safe_day := maxi(1, day)
	return ((safe_day - DEFAULT_WEEKDAY) % WEEK_LENGTH_DAYS) + 1


func get_weekday_name(day: int) -> String:
	match get_weekday_index(day):
		1:
			return "Monday"
		2:
			return "Tuesday"
		3:
			return "Wednesday"
		4:
			return "Thursday"
		5:
			return "Friday"
		6:
			return "Saturday"
		_:
			return "Sunday"


func _get_world_now() -> Dictionary:
	if WorldClock == null:
		return {}
	return {
		"day": int(WorldClock.current_day),
		"hour": int(WorldClock.current_hour),
	}


func _load_event_definitions() -> void:
	_event_definitions.clear()
	var file := FileAccess.open(EVENTS_DATA_PATH, FileAccess.READ)
	if file == null:
		push_warning("[EventManager] Events file not found at %s" % EVENTS_DATA_PATH)
		return

	var parsed: Variant = SaveSerializer.parse_save_data(file.get_as_text())
	if not (parsed is Array):
		push_warning("[EventManager] Expected an Array in %s" % EVENTS_DATA_PATH)
		return

	for entry in parsed:
		if not (entry is Dictionary):
			continue
		var event_definition := entry as Dictionary
		var event_id := str(event_definition.get("id", "")).strip_edges()
		if event_id.is_empty():
			continue
		_event_definitions.append(event_definition.duplicate(true))
