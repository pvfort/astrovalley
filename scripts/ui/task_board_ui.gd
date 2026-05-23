class_name TaskBoardUI
extends Control

const TASK_DATA_PATH := "res://data/task_board_tasks.json"

@export var refresh_interval_days: int = 3
@export var offered_task_count: int = 4

@onready var day_label: Label = $Panel/MarginContainer/VBoxContainer/DayLabel
@onready var task_list: ItemList = $Panel/MarginContainer/VBoxContainer/Columns/TaskListColumn/TaskList
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/Columns/TaskDetailsColumn/TaskTitle
@onready var description_label: Label = $Panel/MarginContainer/VBoxContainer/Columns/TaskDetailsColumn/TaskDescription
@onready var duration_label: Label = $Panel/MarginContainer/VBoxContainer/Columns/TaskDetailsColumn/TaskDuration
@onready var rewards_label: Label = $Panel/MarginContainer/VBoxContainer/Columns/TaskDetailsColumn/TaskRewards
@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var accept_button: Button = $Panel/MarginContainer/VBoxContainer/Buttons/AcceptTaskButton
@onready var refresh_button: Button = $Panel/MarginContainer/VBoxContainer/Buttons/RefreshButton
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/Buttons/CloseButton

var _task_pool: Array[Dictionary] = []
var _available_tasks: Array[Dictionary] = []
var _selected_index: int = -1
var _next_refresh_day: int = 1


func _ready() -> void:
    visible = false
    accept_button.pressed.connect(_on_accept_pressed)
    refresh_button.pressed.connect(_on_refresh_pressed)
    close_button.pressed.connect(close_board)
    task_list.item_selected.connect(_on_task_selected)

    _load_task_pool()
    _refresh_available_tasks(true)

    if WorldClock != null and not WorldClock.day_changed.is_connected(_on_day_changed):
        WorldClock.day_changed.connect(_on_day_changed)


func open_board() -> void:
    if _task_pool.is_empty():
        _load_task_pool()
    if _should_refresh_for_day(_get_current_day()):
        _refresh_available_tasks(false)
    _update_day_label()
    visible = true
    if InventoryManager != null:
        InventoryManager.set_inventory_open(true)


func close_board() -> void:
    visible = false
    if InventoryManager != null:
        InventoryManager.set_inventory_open(false)


func is_open() -> bool:
    return visible


func _on_day_changed(day: int) -> void:
    if _should_refresh_for_day(day):
        _refresh_available_tasks(false)
    _update_day_label()


func _on_task_selected(index: int) -> void:
    _selected_index = index
    _update_task_details()


func _on_accept_pressed() -> void:
    if _selected_index < 0 or _selected_index >= _available_tasks.size():
        _set_status("Select a task first.")
        return

    var task: Dictionary = _available_tasks[_selected_index]
    if not _complete_task(task):
        return
    _available_tasks.remove_at(_selected_index)
    _rebuild_task_list()

    if _available_tasks.is_empty() and _should_refresh_for_day(_get_current_day()):
        _refresh_available_tasks(false)
        _set_status("Task completed. The board has refreshed.")


func _on_refresh_pressed() -> void:
    if not _should_refresh_for_day(_get_current_day()):
        _set_status("New tasks will be posted on day %d." % _next_refresh_day)
        return
    _refresh_available_tasks(false)
    _set_status("Task board refreshed.")


func _complete_task(task: Dictionary) -> bool:
    var task_title := str(task.get("title", "Task"))
    var requirements_result := _validate_task_requirements(task)
    if not bool(requirements_result.get("ok", false)):
        _set_status(str(requirements_result.get("message", "Requirements not met.")))
        return false

    _consume_task_requirements(task)
    var duration_minutes := max(int(task.get("duration_minutes", 0)), 0)
    if WorldClock != null and duration_minutes > 0:
        WorldClock.add_minutes(duration_minutes)

    var reward_summary: Array[String] = []

    var money_reward := max(int(task.get("money_reward", 0)), 0)
    if money_reward > 0 and InventoryManager != null:
        InventoryManager.funds += money_reward
        InventoryManager.inventory_changed.emit()
        reward_summary.append("$%d" % money_reward)
        if WorldClock != null:
            WorldClock.add_daily_money(money_reward)

    var skill_id := str(task.get("skill_id", ""))
    var xp_reward := max(int(task.get("xp_reward", 0)), 0)
    if not skill_id.is_empty() and xp_reward > 0 and SkillManager != null:
        SkillManager.add_xp(skill_id, xp_reward)
        reward_summary.append("%d XP (%s)" % [xp_reward, skill_id.capitalize()])
        if WorldClock != null:
            WorldClock.add_daily_skill_xp(skill_id, xp_reward)

    var item_rewards_variant: Variant = task.get("item_rewards", [])
    if item_rewards_variant is Array and InventoryManager != null:
        for entry_variant in item_rewards_variant:
            if not (entry_variant is Dictionary):
                continue
            var entry: Dictionary = entry_variant as Dictionary
            var item_id := str(entry.get("item_id", ""))
            var amount := max(int(entry.get("count", 0)), 0)
            if item_id.is_empty() or amount <= 0:
                continue
            var remaining: int = InventoryManager.try_insert_item_id(item_id, amount)
            var delivered := amount - remaining
            if delivered > 0:
                reward_summary.append("%s x%d" % [item_id.replace("_", " "), delivered])
            if remaining > 0:
                _set_status("Inventory full. Could not receive %s x%d." % [item_id.replace("_", " "), remaining])

    var observation_time_reward := max(int(task.get("observation_time_reward", 0)), 0)
    if observation_time_reward > 0 and GameManager != null and GameManager.has_method("grant_observation_time"):
        GameManager.grant_observation_time(_resolve_local_player_id(), observation_time_reward)
        reward_summary.append("Observation time +%d" % observation_time_reward)

    if reward_summary.is_empty():
        reward_summary.append("No rewards")

    _set_status("Completed %s. Rewards: %s" % [task_title, ", ".join(reward_summary)])
    return true


func _refresh_available_tasks(initial_load: bool) -> void:
    if _task_pool.is_empty():
        _available_tasks.clear()
        _rebuild_task_list()
        _set_status("No task data found.")
        return

    var source := _task_pool.duplicate(true)
    source.shuffle()

    _available_tasks.clear()
    var target_count := mini(offered_task_count, source.size())
    for i in range(target_count):
        _available_tasks.append(source[i])

    _next_refresh_day = _get_current_day() + max(refresh_interval_days, 1)
    _rebuild_task_list()
    if initial_load:
        _set_status("")
    else:
        _set_status("New tasks are available.")


func _rebuild_task_list() -> void:
    task_list.clear()
    for task in _available_tasks:
        task_list.add_item(str(task.get("title", "Task")))

    if _available_tasks.is_empty():
        _selected_index = -1
        title_label.text = "No tasks available"
        description_label.text = "Come back after the next refresh."
        duration_label.text = "Duration: --"
        rewards_label.text = "Rewards: --"
        accept_button.disabled = true
        _update_day_label()
        return

    _selected_index = 0
    task_list.select(0)
    _update_task_details()
    _update_day_label()


func _update_task_details() -> void:
    if _selected_index < 0 or _selected_index >= _available_tasks.size():
        title_label.text = "No task selected"
        description_label.text = ""
        duration_label.text = "Duration: --"
        rewards_label.text = "Rewards: --"
        accept_button.disabled = true
        return

    var task: Dictionary = _available_tasks[_selected_index]
    title_label.text = str(task.get("title", "Task"))
    description_label.text = str(task.get("description", ""))
    duration_label.text = "Duration: %d min" % max(int(task.get("duration_minutes", 0)), 0)
    rewards_label.text = _format_rewards(task)
    accept_button.disabled = false


func _format_rewards(task: Dictionary) -> String:
    var rewards: Array[String] = []
    var money_reward := max(int(task.get("money_reward", 0)), 0)
    if money_reward > 0:
        rewards.append("$%d" % money_reward)

    var skill_id := str(task.get("skill_id", ""))
    var xp_reward := max(int(task.get("xp_reward", 0)), 0)
    if not skill_id.is_empty() and xp_reward > 0:
        rewards.append("%d XP (%s)" % [xp_reward, skill_id.capitalize()])

    var item_rewards_variant: Variant = task.get("item_rewards", [])
    if item_rewards_variant is Array:
        for entry_variant in item_rewards_variant:
            if not (entry_variant is Dictionary):
                continue
            var entry: Dictionary = entry_variant as Dictionary
            var item_id := str(entry.get("item_id", ""))
            var amount := max(int(entry.get("count", 0)), 0)
            if item_id.is_empty() or amount <= 0:
                continue
            rewards.append("%s x%d" % [item_id.replace("_", " "), amount])

    var observation_time_reward := max(int(task.get("observation_time_reward", 0)), 0)
    if observation_time_reward > 0:
        rewards.append("Observation time +%d" % observation_time_reward)

    if rewards.is_empty():
        return "Rewards: --"
    return "Rewards: %s" % ", ".join(rewards)


func _validate_task_requirements(task: Dictionary) -> Dictionary:
    var required_programming_progress := max(int(task.get("required_programming_progress", 0)), 0)
    if required_programming_progress > 0:
        var current_programming_progress := 0
        if WorldClock != null and WorldClock.has_method("get_daily_summary_data"):
            var summary: Dictionary = WorldClock.get_daily_summary_data()
            current_programming_progress = max(int(summary.get("programming_progress", 0)), 0)
        if current_programming_progress < required_programming_progress:
            return {
                "ok": false,
                "message": "Need %d programming progress today (have %d)." % [required_programming_progress, current_programming_progress],
            }

    var required_items_variant: Variant = task.get("required_items", [])
    if required_items_variant is Array:
        if InventoryManager == null:
            return {"ok": false, "message": "Inventory manager unavailable."}
        for entry_variant in required_items_variant:
            if not (entry_variant is Dictionary):
                continue
            var entry: Dictionary = entry_variant as Dictionary
            var item_id := str(entry.get("item_id", ""))
            var amount := max(int(entry.get("count", 0)), 0)
            if item_id.is_empty() or amount <= 0:
                continue
            var available := InventoryManager.count_item(item_id)
            if available < amount:
                return {
                    "ok": false,
                    "message": "Need %s x%d (have %d)." % [item_id.replace("_", " "), amount, available],
                }

    return {"ok": true, "message": "Ready"}


func _consume_task_requirements(task: Dictionary) -> void:
    var required_items_variant: Variant = task.get("required_items", [])
    if not (required_items_variant is Array):
        return
    if InventoryManager == null:
        return

    for entry_variant in required_items_variant:
        if not (entry_variant is Dictionary):
            continue
        var entry: Dictionary = entry_variant as Dictionary
        var item_id := str(entry.get("item_id", ""))
        var amount := max(int(entry.get("count", 0)), 0)
        if item_id.is_empty() or amount <= 0:
            continue
        InventoryManager.remove_items_by_id(item_id, amount)


func _resolve_local_player_id() -> int:
    if multiplayer.has_multiplayer_peer():
        return multiplayer.get_unique_id()
    return 1


func _set_status(message: String) -> void:
    status_label.text = message


func _should_refresh_for_day(day: int) -> bool:
    return day >= _next_refresh_day


func _update_day_label() -> void:
    day_label.text = "Day %d · Next refresh day: %d" % [_get_current_day(), _next_refresh_day]


func _get_current_day() -> int:
    if WorldClock != null:
        return max(int(WorldClock.current_day), 1)
    return 1


func _load_task_pool() -> void:
    _task_pool.clear()

    var file := FileAccess.open(TASK_DATA_PATH, FileAccess.READ)
    if file == null:
        push_warning("[TaskBoardUI] Could not open %s" % TASK_DATA_PATH)
        return

    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK:
        push_warning("[TaskBoardUI] Could not parse %s" % TASK_DATA_PATH)
        return

    var parsed: Variant = parser.data
    if not (parsed is Array):
        push_warning("[TaskBoardUI] Task data must be an array.")
        return

    for entry_variant in parsed:
        if not (entry_variant is Dictionary):
            continue
        var entry: Dictionary = entry_variant as Dictionary
        if not _is_valid_task(entry):
            continue
        _task_pool.append(entry)


func _is_valid_task(task: Dictionary) -> bool:
    return not str(task.get("id", "")).is_empty() \
        and not str(task.get("title", "")).is_empty()


func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if event.is_action_pressed("ui_cancel"):
        close_board()
        get_viewport().set_input_as_handled()
