extends Control

@onready var _day_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DayLabel
@onready var _time_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TimeRow/TimeLabel
@onready var _phase_icon: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/InfoRow/PhaseIcon
@onready var _weather_icon: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/InfoRow/WeatherIcon

@export var sun_icon: Texture2D = preload("res://assets/ui/time/sun_icon.png")
@export var moon_icon: Texture2D = preload("res://assets/ui/time/moon_icon.png")
@export var weather_placeholder_icon: Texture2D = preload("res://assets/ui/time/rain_icon.png")

func _ready() -> void:
    WorldClock.time_changed.connect(_on_time_changed)
    WorldClock.day_changed.connect(_on_day_changed)
    WorldClock.phase_changed.connect(_on_phase_changed)

    _weather_icon.texture = weather_placeholder_icon
    _weather_icon.modulate = Color(1.0, 1.0, 1.0, 0.35)

    _on_day_changed(WorldClock.current_day)
    _on_time_changed(WorldClock.current_hour, WorldClock.current_minute)
    _on_phase_changed(WorldClock.get_phase_name())

func _on_day_changed(day: int) -> void:
    _day_label.text = "Day %d" % day

func _on_time_changed(hour: int, minute: int) -> void:
    _time_label.text = "%02d:%02d" % [hour, minute]

func _on_phase_changed(phase_name: String) -> void:
    if phase_name == "Night":
        _phase_icon.texture = moon_icon
    else:
        _phase_icon.texture = sun_icon
