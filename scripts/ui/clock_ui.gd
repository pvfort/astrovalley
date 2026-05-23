extends Control

@onready var _day_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DayLabel
@onready var _time_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TimeRow/TimeLabel
@onready var _phase_icon: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/InfoRow/PhaseIcon
@onready var _weather_icon: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/InfoRow/WeatherIcon
@onready var _quest_task_button: Button = $PanelContainer/MarginContainer/VBoxContainer/QuestTaskButton
@onready var _current_task_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CurrentTaskLabel
@onready var _quest_label: Label = $PanelContainer/MarginContainer/VBoxContainer/QuestLabel
@onready var _event_label: Label = $PanelContainer/MarginContainer/VBoxContainer/EventLabel
@onready var _quest_task_panel: PanelContainer = $QuestTaskPanel
@onready var _task_title_label: Label = $QuestTaskPanel/MarginContainer/VBoxContainer/TaskTitleLabel
@onready var _task_progress_label: Label = $QuestTaskPanel/MarginContainer/VBoxContainer/TaskProgressLabel
@onready var _task_rewards_label: Label = $QuestTaskPanel/MarginContainer/VBoxContainer/TaskRewardsLabel
@onready var _quest_title_label: Label = $QuestTaskPanel/MarginContainer/VBoxContainer/QuestTitleLabel
@onready var _quest_progress_label: Label = $QuestTaskPanel/MarginContainer/VBoxContainer/QuestProgressLabel
@onready var _quest_rewards_label: Label = $QuestTaskPanel/MarginContainer/VBoxContainer/QuestRewardsLabel
@onready var _quest_task_close_button: Button = $QuestTaskPanel/MarginContainer/VBoxContainer/CloseButton

@export var sun_icon: Texture2D = preload("res://assets/ui/time/sun_icon.png")
@export var moon_icon: Texture2D = preload("res://assets/ui/time/moon_icon.png")
@export var weather_placeholder_icon: Texture2D = preload("res://assets/ui/time/rain_icon.png")
@export var weather_clear_icon: Texture2D = preload("res://assets/ui/time/sun_icon.png")
@export var weather_cloudy_icon: Texture2D = preload("res://assets/ui/time/moon_icon.png")
@export var weather_rainy_icon: Texture2D = preload("res://assets/ui/time/rain_icon.png")
@export var weather_storm_icon: Texture2D = preload("res://assets/ui/time/rain_icon.png")
@export var weather_fog_icon: Texture2D = preload("res://assets/ui/time/moon_icon.png")

func _ready() -> void:
	_quest_task_button.pressed.connect(_toggle_quest_task_panel)
	_quest_task_close_button.pressed.connect(_close_quest_task_panel)
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
	if EventManager != null and EventManager.has_signal("active_events_changed"):
		EventManager.active_events_changed.connect(_on_active_events_changed)

	_weather_icon.texture = weather_placeholder_icon
	_weather_icon.modulate = Color(1.0, 1.0, 1.0, 0.35)
	_weather_icon.tooltip_text = "Weather"

	_on_day_changed(WorldClock.current_day)
	_on_time_changed(WorldClock.current_hour, WorldClock.current_minute)
	_on_phase_changed(WorldClock.get_phase_name())
	if WeatherManager != null and WeatherManager.has_method("get_current_weather_data"):
		_on_weather_changed(WeatherManager.current_weather, WeatherManager.get_current_weather_data())
	_refresh_events()
	_refresh_progression()

func _on_day_changed(day: int) -> void:
	_day_label.text = "Day %d" % day

func _on_time_changed(hour: int, minute: int) -> void:
	_time_label.text = "%02d:%02d" % [hour, minute]
	if _quest_task_panel.visible:
		_refresh_quest_task_panel()

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


func _on_active_events_changed(_active_events: Array[Dictionary]) -> void:
	_refresh_events()


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
	if _quest_task_panel.visible:
		_refresh_quest_task_panel()


func _refresh_events() -> void:
	_event_label.tooltip_text = "Systemic world events"
	if EventManager == null or not EventManager.has_method("get_primary_event"):
		_event_label.text = "Event: none"
		return

	var primary_event: Dictionary = EventManager.get_primary_event()
	var event_name := str(primary_event.get("name", "")).strip_edges()
	var location := str(primary_event.get("location", "")).strip_edges().replace("_", " ")
	if event_name.is_empty():
		_event_label.text = "Event: none"
		return
	if location.is_empty():
		_event_label.text = "Event: %s" % event_name
		return
	_event_label.text = "Event: %s @ %s" % [event_name, location.capitalize()]


func _resolve_local_player_id() -> int:
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1


func _toggle_quest_task_panel() -> void:
	var next_visible := not _quest_task_panel.visible
	_quest_task_panel.visible = next_visible
	if next_visible:
		_refresh_quest_task_panel()


func _close_quest_task_panel() -> void:
	_quest_task_panel.visible = false


func _refresh_quest_task_panel() -> void:
	_refresh_task_section()
	_refresh_quest_section()


func _refresh_task_section() -> void:
	var local_player_id := _resolve_local_player_id()
	var current_task := ""
	if GameManager != null and GameManager.has_method("get_current_task"):
		current_task = GameManager.get_current_task(local_player_id)

	if current_task.is_empty():
		_task_title_label.text = "Task: none"
		_task_progress_label.text = "Progress: --"
		_task_rewards_label.text = "Rewards: --"
		return

	_task_title_label.text = "Task: %s" % current_task
	_task_progress_label.text = "Progress: active"
	_task_rewards_label.text = "Rewards: none listed"

	if TaskManager != null and TaskManager.has_method("get_active_task_details"):
		var task_details: Dictionary = TaskManager.get_active_task_details(local_player_id)
		var duration_seconds := float(task_details.get("duration_seconds", 0.0))
		var time_left_seconds := float(task_details.get("time_left_seconds", 0.0))
		if duration_seconds > 0.0:
			var completed_ratio := clampf((duration_seconds - time_left_seconds) / duration_seconds, 0.0, 1.0)
			_task_progress_label.text = "Progress: %d%% (%ds left)" % [int(round(completed_ratio * 100.0)), int(ceil(time_left_seconds))]
		var rewards_text := _format_rewards_from_data(task_details.get("task_data", {}))
		if not rewards_text.is_empty():
			_task_rewards_label.text = "Rewards: %s" % rewards_text


func _refresh_quest_section() -> void:
	if QuestManager == null or not QuestManager.has_method("get_active_quest"):
		_quest_title_label.text = "Quest: none"
		_quest_progress_label.text = "Progress: --"
		_quest_rewards_label.text = "Rewards: --"
		return

	var active_quest = QuestManager.get_active_quest()
	if active_quest == null:
		_quest_title_label.text = "Quest: none"
		_quest_progress_label.text = "Progress: --"
		_quest_rewards_label.text = "Rewards: --"
		return

	var quest_title := str(active_quest.title)
	_quest_title_label.text = "Quest: %s" % (quest_title if not quest_title.is_empty() else "untitled")
	var objective_lines: Array[String] = []
	for objective in active_quest.objectives:
		if objective == null:
			continue
		var progress_text := str(objective.get_progress_text())
		if progress_text.is_empty():
			continue
		var prefix := "✓ " if objective.completed else "• "
		objective_lines.append("%s%s" % [prefix, progress_text])
	_quest_progress_label.text = "Progress: %s" % ("\n".join(objective_lines) if not objective_lines.is_empty() else "--")
	_quest_rewards_label.text = "Rewards: none listed"


func _format_rewards_from_data(task_data_variant: Variant) -> String:
	if not (task_data_variant is Dictionary):
		return ""
	var task_data: Dictionary = task_data_variant as Dictionary
	var reward_parts: Array[String] = []

	var money_reward := max(int(task_data.get("money_reward", 0)), 0)
	if money_reward > 0:
		reward_parts.append("$%d" % money_reward)

	var skill_id := str(task_data.get("skill_id", ""))
	var xp_reward := max(int(task_data.get("xp_reward", 0)), 0)
	if not skill_id.is_empty() and xp_reward > 0:
		reward_parts.append("%d XP (%s)" % [xp_reward, skill_id.capitalize()])

	var observation_time_reward := max(int(task_data.get("observation_time_reward", 0)), 0)
	if observation_time_reward > 0:
		reward_parts.append("Observation time +%d" % observation_time_reward)

	var item_rewards_variant: Variant = task_data.get("item_rewards", [])
	if item_rewards_variant is Array:
		for item_reward_variant in item_rewards_variant:
			if not (item_reward_variant is Dictionary):
				continue
			var item_reward: Dictionary = item_reward_variant as Dictionary
			var item_id := str(item_reward.get("item_id", "")).replace("_", " ")
			var item_count := max(int(item_reward.get("count", 0)), 0)
			if item_id.is_empty() or item_count <= 0:
				continue
			reward_parts.append("%s x%d" % [item_id, item_count])

	return ", ".join(reward_parts)
