extends Control

@onready var _day_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DayLabel
@onready var _time_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TimeRow/TimeLabel
@onready var _phase_icon: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/InfoRow/PhaseIcon
@onready var _weather_icon: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/InfoRow/WeatherIcon

@export var sun_icon: Texture2D = preload("res://assets/ui/time/sun_icon.png")
@export var moon_icon: Texture2D = preload("res://assets/ui/time/moon_icon.png")
@export var weather_placeholder_icon: Texture2D = preload("res://assets/ui/time/rain_icon.png")
@export var weather_clear_icon: Texture2D = preload("res://assets/ui/time/sun_icon.png")
@export var weather_cloudy_icon: Texture2D = preload("res://assets/ui/time/moon_icon.png")
@export var weather_rainy_icon: Texture2D = preload("res://assets/ui/time/rain_icon.png")
@export var weather_storm_icon: Texture2D = preload("res://assets/ui/time/rain_icon.png")
@export var weather_fog_icon: Texture2D = preload("res://assets/ui/time/moon_icon.png")

func _ready() -> void:
	WorldClock.time_changed.connect(_on_time_changed)
	WorldClock.day_changed.connect(_on_day_changed)
	WorldClock.phase_changed.connect(_on_phase_changed)
	if WeatherManager != null and WeatherManager.has_signal("weather_changed"):
		WeatherManager.weather_changed.connect(_on_weather_changed)

	_weather_icon.texture = weather_placeholder_icon
	_weather_icon.modulate = Color(1.0, 1.0, 1.0, 0.35)
	_weather_icon.tooltip_text = "Weather"

	_on_day_changed(WorldClock.current_day)
	_on_time_changed(WorldClock.current_hour, WorldClock.current_minute)
	_on_phase_changed(WorldClock.get_phase_name())
	if WeatherManager != null and WeatherManager.has_method("get_current_weather_data"):
		_on_weather_changed(WeatherManager.current_weather, WeatherManager.get_current_weather_data())

func _on_day_changed(day: int) -> void:
	_day_label.text = "Day %d" % day

func _on_time_changed(hour: int, minute: int) -> void:
	_time_label.text = "%02d:%02d" % [hour, minute]

func _on_phase_changed(phase_name: String) -> void:
	if phase_name == "Night":
		_phase_icon.texture = moon_icon
	else:
		_phase_icon.texture = sun_icon


func _on_weather_changed(weather_name: String, _weather_data: Dictionary) -> void:
	var normalized := weather_name.strip_edges().to_lower()
	match normalized:
		"clear":
			_weather_icon.texture = weather_clear_icon
			_weather_icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
		"cloudy":
			_weather_icon.texture = weather_cloudy_icon
			_weather_icon.modulate = Color(0.85, 0.88, 0.94, 0.95)
		"rainy":
			_weather_icon.texture = weather_rainy_icon
			_weather_icon.modulate = Color(0.78, 0.86, 1.0, 1.0)
		"storm":
			_weather_icon.texture = weather_storm_icon
			_weather_icon.modulate = Color(0.72, 0.78, 0.9, 1.0)
		"fog":
			_weather_icon.texture = weather_fog_icon
			_weather_icon.modulate = Color(0.9, 0.92, 0.95, 0.95)
		_:
			_weather_icon.texture = weather_placeholder_icon
			_weather_icon.modulate = Color(1.0, 1.0, 1.0, 0.35)
	_weather_icon.tooltip_text = "Weather: %s" % normalized.capitalize()
