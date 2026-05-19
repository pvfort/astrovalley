extends Node

signal weather_changed(weather_name: String)
signal season_changed(season_name: String)

const DEFAULT_WEATHER: String = "clear"
const DEFAULT_SEASON: String = "spring"

var current_weather: String = DEFAULT_WEATHER
var current_season: String = DEFAULT_SEASON


func set_weather(weather_name: String) -> void:
	var next_weather := weather_name.strip_edges().to_lower()
	if next_weather.is_empty():
		next_weather = DEFAULT_WEATHER
	if next_weather == current_weather:
		return
	current_weather = next_weather
	weather_changed.emit(current_weather)


func set_season(season_name: String) -> void:
	var next_season := season_name.strip_edges().to_lower()
	if next_season.is_empty():
		next_season = DEFAULT_SEASON
	if next_season == current_season:
		return
	current_season = next_season
	season_changed.emit(current_season)


func save_state() -> Dictionary:
	return {
		"weather": current_weather,
		"season": current_season,
	}


func load_state(data: Dictionary) -> void:
	set_weather(str(data.get("weather", DEFAULT_WEATHER)))
	set_season(str(data.get("season", DEFAULT_SEASON)))
