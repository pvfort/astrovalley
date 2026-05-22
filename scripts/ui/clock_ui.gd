extends Control

@onready var _day_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DayLabel
@onready var _time_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TimeRow/TimeLabel
@onready var _phase_icon: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/InfoRow/PhaseIcon
@onready var _weather_icon: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/InfoRow/WeatherIcon
@onready var _current_task_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CurrentTaskLabel
@onready var _quest_label: Label = $PanelContainer/MarginContainer/VBoxContainer/QuestLabel

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
	if GameManager != null and GameManager.has_signal("player_task_changed"):
		GameManager.player_task_changed.connect(_on_player_task_changed)
	if QuestManager != null:
		if QuestManager.has_signal("active_quest_changed"):
			QuestManager.active_quest_changed.connect(_refresh_progression)
		if QuestManager.has_signal("quest_progressed"):
			QuestManager.quest_progressed.connect(_refresh_progression)

	_weather_icon.texture = weather_placeholder_icon
	_weather_icon.modulate = Color(1.0, 1.0, 1.0, 0.35)
	_weather_icon.tooltip_text = "Weather"

	_on_day_changed(WorldClock.current_day)
	_on_time_changed(WorldClock.current_hour, WorldClock.current_minute)
	_on_phase_changed(WorldClock.get_phase_name())
	if WeatherManager != null and WeatherManager.has_method("get_current_weather_data"):
		_on_weather_changed(WeatherManager.current_weather, WeatherManager.get_current_weather_data())
	_refresh_progression()

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


func _on_player_task_changed(player_id: int, _task_id: String) -> void:
	if player_id != _resolve_local_player_id():
		return
	_refresh_progression()


func _refresh_progression(_value = null) -> void:
	var current_task := ""
	if GameManager != null and GameManager.has_method("get_current_task"):
		current_task = GameManager.get_current_task(_resolve_local_player_id())
	_current_task_label.text = "Task: %s" % (current_task if not current_task.is_empty() else "none")

	var quest_text := "none"
	if QuestManager != null and QuestManager.has_method("get_active_objective_text"):
		var active_quest_title := QuestManager.get_active_quest_title()
		var active_objective := QuestManager.get_active_objective_text()
		if not active_quest_title.is_empty() and not active_objective.is_empty():
			quest_text = "%s — %s" % [active_quest_title, active_objective]
		elif not active_quest_title.is_empty():
			quest_text = active_quest_title
	_current_task_label.tooltip_text = "Current task"
	_quest_label.text = "Quest: %s" % quest_text


func _resolve_local_player_id() -> int:
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1
