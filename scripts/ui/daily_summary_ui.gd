extends Control

@onready var _day_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DayLabel
@onready var _xp_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Stats/XpLabel
@onready var _money_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Stats/MoneyRow/MoneyLabel
@onready var _tasks_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Stats/TasksLabel
@onready var _observation_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Stats/ObservationRow/ObservationLabel
@onready var _programming_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Stats/ProgrammingRow/ProgrammingLabel
@onready var _continue_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ContinueButton

func _ready() -> void:
    visible = false
    _continue_button.pressed.connect(_on_continue_pressed)
    WorldClock.daily_summary_requested.connect(show_summary)

func show_summary(summary_data: Dictionary) -> void:
    visible = true
    _day_label.text = "Daily Summary - Day %d" % WorldClock.current_day
    _xp_label.text = "XP gained per skill: %s" % _format_skill_xp(summary_data.get("xp_gained_per_skill", {}))
    _money_label.text = "%d" % int(summary_data.get("money_earned", 0))
    _tasks_label.text = "Tasks completed: %d" % int(summary_data.get("tasks_completed", 0))
    _observation_label.text = "%d" % int(summary_data.get("observation_data_collected", 0))
    _programming_label.text = "%d" % int(summary_data.get("programming_progress", 0))

func _format_skill_xp(skill_data: Dictionary) -> String:
    if skill_data.is_empty():
        return "none"

    var chunks: PackedStringArray = []
    for skill_id in skill_data.keys():
        chunks.append("%s +%d" % [skill_id, int(skill_data[skill_id])])
    return ", ".join(chunks)

func _on_continue_pressed() -> void:
    visible = false
