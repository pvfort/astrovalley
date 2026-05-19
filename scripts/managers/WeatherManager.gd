extends Node

signal weather_changed(weather_name: String, weather_data: Dictionary)
signal season_changed(season_name: String)
signal weather_rolled(day: int, weather_name: String)

const DEFAULT_WEATHER: String = "clear"
const DEFAULT_SEASON: String = "spring"

var current_weather: String = DEFAULT_WEATHER
var current_season: String = DEFAULT_SEASON
var current_humidity: float = 0.35
var current_seeing: float = 0.9
var current_turbulence: float = 0.1
var _last_rolled_day: int = 0
var _weather_profiles: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_build_default_profiles()

	if WorldClock != null:
		if not WorldClock.day_changed.is_connected(_on_world_day_changed):
			WorldClock.day_changed.connect(_on_world_day_changed)
		_on_world_day_changed(WorldClock.current_day)

	multiplayer.peer_connected.connect(_on_peer_connected)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		rpc_id(1, "request_weather_sync")


func set_weather(weather_name: String) -> void:
	var next_weather := _normalize_weather_name(weather_name)
	if next_weather.is_empty():
		next_weather = DEFAULT_WEATHER
	if not _weather_profiles.has(next_weather):
		next_weather = DEFAULT_WEATHER
	if next_weather == current_weather:
		return
	current_weather = next_weather
	_apply_weather_stats()
	weather_changed.emit(current_weather, get_current_weather_data())
	_sync_to_clients()


func set_season(season_name: String) -> void:
	var next_season := season_name.strip_edges().to_lower()
	if next_season.is_empty():
		next_season = DEFAULT_SEASON
	if next_season == current_season:
		return
	current_season = next_season
	season_changed.emit(current_season)
	_sync_to_clients()


func roll_weather_for_day(day: int, force: bool = false) -> void:
	if day <= 0:
		return
	if not force and day == _last_rolled_day:
		return
	_last_rolled_day = day
	var rolled_weather := _weighted_roll(current_season)
	current_weather = rolled_weather
	_apply_weather_stats()
	weather_changed.emit(current_weather, get_current_weather_data())
	weather_rolled.emit(day, current_weather)
	_sync_to_clients()


func get_current_weather_data() -> Dictionary:
	var weather_data := _get_weather_data(current_weather)
	return weather_data.to_dictionary()


func get_observation_quality_multiplier() -> float:
	return _get_weather_data(current_weather).observation_quality_multiplier


func is_telescope_usable() -> bool:
	return _get_weather_data(current_weather).telescope_usable


func get_outdoor_exploration_multiplier() -> float:
	return _get_weather_data(current_weather).outdoor_exploration_multiplier


func get_ambience_tint() -> Color:
	return _get_weather_data(current_weather).ambience_tint


func get_ambient_light_multiplier() -> float:
	return _get_weather_data(current_weather).ambient_light_multiplier


func get_precipitation_intensity() -> float:
	return _get_weather_data(current_weather).precipitation_intensity


func get_cloud_coverage() -> float:
	return _get_weather_data(current_weather).cloud_coverage


func get_forecast(_days_ahead: int = 1) -> Array[Dictionary]:
	return []


func save_state() -> Dictionary:
	return {
		"weather": current_weather,
		"season": current_season,
		"humidity": current_humidity,
		"seeing": current_seeing,
		"turbulence": current_turbulence,
		"last_rolled_day": _last_rolled_day,
	}


func load_state(data: Dictionary) -> void:
	set_season(str(data.get("season", DEFAULT_SEASON)))
	current_weather = _normalize_weather_name(str(data.get("weather", DEFAULT_WEATHER)))
	if not _weather_profiles.has(current_weather):
		current_weather = DEFAULT_WEATHER
	current_humidity = clampf(float(data.get("humidity", _get_weather_data(current_weather).humidity)), 0.0, 1.0)
	current_seeing = clampf(float(data.get("seeing", _get_weather_data(current_weather).seeing)), 0.0, 1.0)
	current_turbulence = clampf(float(data.get("turbulence", _get_weather_data(current_weather).turbulence)), 0.0, 1.0)
	_last_rolled_day = maxi(0, int(data.get("last_rolled_day", _last_rolled_day)))
	weather_changed.emit(current_weather, get_current_weather_data())
	_sync_to_clients()


func _build_default_profiles() -> void:
	_weather_profiles.clear()
	var defaults := WeatherData.default_profiles()
	for key in defaults.keys():
		var weather_name := str(key)
		_weather_profiles[weather_name] = defaults[weather_name]


func _on_world_day_changed(day: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	roll_weather_for_day(day)


func _weighted_roll(season_name: String) -> String:
	var safe_season := season_name.strip_edges().to_lower()
	var total_weight := 0.0
	var weather_names: Array[String] = []
	var weather_weights: Array[float] = []

	for weather_name in _weather_profiles.keys():
		var weather_data := _get_weather_data(str(weather_name))
		var weight := weather_data.get_weight_for_season(safe_season)
		if weight <= 0.0:
			continue
		weather_names.append(str(weather_name))
		weather_weights.append(weight)
		total_weight += weight

	if weather_names.is_empty() or total_weight <= 0.0:
		return DEFAULT_WEATHER

	var pick := _rng.randf_range(0.0, total_weight)
	var cumulative := 0.0
	for i in range(weather_names.size()):
		cumulative += weather_weights[i]
		if pick <= cumulative:
			return weather_names[i]

	return weather_names[weather_names.size() - 1]


func _get_weather_data(weather_name: String) -> WeatherData:
	var safe_weather := _normalize_weather_name(weather_name)
	var value : Variant = _weather_profiles.get(safe_weather, null)
	if value is WeatherData:
		return value as WeatherData
	return WeatherData.default_clear()


func _normalize_weather_name(weather_name: String) -> String:
	return weather_name.strip_edges().to_lower()


func _apply_weather_stats() -> void:
	var weather_data := _get_weather_data(current_weather)
	current_humidity = weather_data.humidity
	current_seeing = weather_data.seeing
	current_turbulence = weather_data.turbulence


func _sync_to_clients() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		rpc("sync_weather_state", current_weather, current_season, current_humidity, current_seeing, current_turbulence, _last_rolled_day)


@rpc("any_peer", "reliable")
func request_weather_sync() -> void:
	if multiplayer.is_server():
		rpc_id(multiplayer.get_remote_sender_id(), "sync_weather_state", current_weather, current_season, current_humidity, current_seeing, current_turbulence, _last_rolled_day)


@rpc("authority", "reliable")
func sync_weather_state(weather_name: String, season_name: String, humidity: float, seeing: float, turbulence: float, rolled_day: int) -> void:
	current_weather = _normalize_weather_name(weather_name)
	if not _weather_profiles.has(current_weather):
		current_weather = DEFAULT_WEATHER
	current_season = season_name.strip_edges().to_lower()
	if current_season.is_empty():
		current_season = DEFAULT_SEASON
	current_humidity = clampf(humidity, 0.0, 1.0)
	current_seeing = clampf(seeing, 0.0, 1.0)
	current_turbulence = clampf(turbulence, 0.0, 1.0)
	_last_rolled_day = maxi(0, rolled_day)
	weather_changed.emit(current_weather, get_current_weather_data())
	season_changed.emit(current_season)


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		rpc_id(id, "sync_weather_state", current_weather, current_season, current_humidity, current_seeing, current_turbulence, _last_rolled_day)
