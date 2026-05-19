class_name WeatherData
extends RefCounted

var weather_name: String = "clear"
var observation_quality_multiplier: float = 1.0
var telescope_usable: bool = true
var outdoor_exploration_multiplier: float = 1.0
var ambience_tint: Color = Color(1.0, 1.0, 1.0, 0.0)
var ambient_light_multiplier: float = 1.0
var precipitation_intensity: float = 0.0
var cloud_coverage: float = 0.0
var humidity: float = 0.35
var seeing: float = 0.9
var turbulence: float = 0.1
var supports_power_fluctuations: bool = false
var season_weights: Dictionary = {}


static func create(
	name: String,
	observation_quality: float,
	can_use_telescope: bool,
	outdoor_multiplier: float,
	tint: Color,
	ambient_multiplier: float,
	rain_intensity: float,
	clouds: float,
	humidity_value: float,
	seeing_value: float,
	turbulence_value: float,
	power_fluctuations: bool,
	weights: Dictionary
) -> WeatherData:
	var data := WeatherData.new()
	data.weather_name = name
	data.observation_quality_multiplier = maxf(0.0, observation_quality)
	data.telescope_usable = can_use_telescope
	data.outdoor_exploration_multiplier = maxf(0.0, outdoor_multiplier)
	data.ambience_tint = tint
	data.ambient_light_multiplier = clampf(ambient_multiplier, 0.0, 2.0)
	data.precipitation_intensity = clampf(rain_intensity, 0.0, 1.0)
	data.cloud_coverage = clampf(clouds, 0.0, 1.0)
	data.humidity = clampf(humidity_value, 0.0, 1.0)
	data.seeing = clampf(seeing_value, 0.0, 1.0)
	data.turbulence = clampf(turbulence_value, 0.0, 1.0)
	data.supports_power_fluctuations = power_fluctuations
	data.season_weights = _safe_weights(weights)
	return data


func get_weight_for_season(season_name: String) -> float:
	var safe_season := season_name.strip_edges().to_lower()
	if safe_season.is_empty():
		safe_season = "spring"
	return maxf(0.0, float(season_weights.get(safe_season, season_weights.get("default", 0.0))))


func to_dictionary() -> Dictionary:
	return {
		"name": weather_name,
		"observation_quality_multiplier": observation_quality_multiplier,
		"telescope_usable": telescope_usable,
		"outdoor_exploration_multiplier": outdoor_exploration_multiplier,
		"ambience_tint": ambience_tint,
		"ambient_light_multiplier": ambient_light_multiplier,
		"precipitation_intensity": precipitation_intensity,
		"cloud_coverage": cloud_coverage,
		"humidity": humidity,
		"seeing": seeing,
		"turbulence": turbulence,
		"supports_power_fluctuations": supports_power_fluctuations,
	}


static func default_clear() -> WeatherData:
	return create(
		"clear",
		1.0,
		true,
		1.0,
		Color(1.0, 1.0, 1.0, 0.0),
		1.0,
		0.0,
		0.05,
		0.3,
		1.0,
		0.1,
		false,
		{"default": 1.0, "spring": 0.38, "summer": 0.42, "autumn": 0.3, "winter": 0.25}
	)


static func default_profiles() -> Dictionary:
	return {
		"clear": default_clear(),
		"cloudy": create(
			"cloudy",
			0.65,
			true,
			0.95,
			Color(0.82, 0.86, 0.94, 0.18),
			0.92,
			0.0,
			0.75,
			0.55,
			0.65,
			0.28,
			false,
			{"default": 1.0, "spring": 0.30, "summer": 0.28, "autumn": 0.34, "winter": 0.32}
		),
		"rainy": create(
			"rainy",
			0.25,
			false,
			0.82,
			Color(0.68, 0.75, 0.85, 0.22),
			0.82,
			0.85,
			0.90,
			0.85,
			0.35,
			0.65,
			false,
			{"default": 1.0, "spring": 0.22, "summer": 0.18, "autumn": 0.24, "winter": 0.2}
		),
		"storm": create(
			"storm",
			0.1,
			false,
			0.65,
			Color(0.56, 0.62, 0.76, 0.3),
			0.72,
			1.0,
			1.0,
			0.95,
			0.22,
			0.85,
			true,
			{"default": 1.0, "spring": 0.06, "summer": 0.05, "autumn": 0.08, "winter": 0.05}
		),
		"fog": create(
			"fog",
			0.45,
			true,
			0.78,
			Color(0.86, 0.89, 0.92, 0.22),
			0.88,
			0.0,
			0.35,
			0.75,
			0.45,
			0.55,
			false,
			{"default": 1.0, "spring": 0.12, "summer": 0.07, "autumn": 0.14, "winter": 0.18}
		),
	}


static func _safe_weights(weights: Dictionary) -> Dictionary:
	var output := {"default": 1.0}
	for key in weights.keys():
		output[str(key).strip_edges().to_lower()] = maxf(0.0, float(weights[key]))
	return output
