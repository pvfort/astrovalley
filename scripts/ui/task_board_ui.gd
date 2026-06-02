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
var _recent_npc_talks: Dictionary = {}


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
	if EventBus != null and EventBus.has_signal("npc_talked_to"):
		if not EventBus.npc_talked_to.is_connected(_on_npc_talked_to):
			EventBus.npc_talked_to.connect(_on_npc_talked_to)


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
	var task_id := str(task.get("id", ""))
	var local_player_id := _resolve_local_player_id()
	var requirements_result := _validate_task_requirements(task)
	if not bool(requirements_result.get("ok", false)):
		_set_status(str(requirements_result.get("message", "Requirements not met.")))
		return false

	if not task_id.is_empty() and EventBus != null:
		if EventBus.has_signal("task_started"):
			EventBus.task_started.emit(local_player_id, task_id)

	_consume_task_requirements(task)
	var duration_minutes :Variant= max(int(task.get("duration_minutes", 0)), 0)
	if WorldClock != null and duration_minutes > 0:
		WorldClock.add_minutes(duration_minutes)

	var attendance_event_id := _resolve_task_attendance_event_id(task)
	_apply_stress_effects_for_task(task, local_player_id, attendance_event_id)

	var reward_summary: Array[String] = []

	var money_reward :Variant= max(int(task.get("money_reward", 0)), 0)
	if money_reward > 0 and InventoryManager != null:
		InventoryManager.funds += money_reward
		InventoryManager.inventory_changed.emit()
		reward_summary.append("$%d" % money_reward)
		if WorldClock != null:
			WorldClock.add_daily_money(money_reward)

	var salary_increase_reward :Variant= max(int(task.get("salary_increase_reward", 0)), 0)
	if salary_increase_reward > 0 and InventoryManager != null and InventoryManager.has_method("increase_daily_salary"):
		InventoryManager.increase_daily_salary(salary_increase_reward)
		reward_summary.append("Daily salary +$%d" % salary_increase_reward)

	var skill_id := str(task.get("skill_id", ""))
	var xp_reward :Variant= max(int(task.get("xp_reward", 0)), 0)
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
			var amount :Variant= max(int(entry.get("count", 0)), 0)
			if item_id.is_empty() or amount <= 0:
				continue
			var remaining: int = InventoryManager.try_insert_item_id(item_id, amount)
			var delivered :Variant= amount - remaining
			if delivered > 0:
				reward_summary.append("%s x%d" % [item_id.replace("_", " "), delivered])
			if remaining > 0:
				_set_status("Inventory full. Could not receive %s x%d." % [item_id.replace("_", " "), remaining])

	var observation_time_reward :Variant= max(int(task.get("observation_time_reward", 0)), 0)
	if observation_time_reward > 0 and GameManager != null and GameManager.has_method("grant_observation_time"):
		GameManager.grant_observation_time(_resolve_local_player_id(), observation_time_reward)
		reward_summary.append("Observation time +%d" % observation_time_reward)

	if not attendance_event_id.is_empty() and EventManager != null and EventManager.has_method("register_attendance"):
		var attendance_count := int(EventManager.register_attendance(_resolve_local_player_id(), attendance_event_id))
		reward_summary.append("%s attendance #%d" % [attendance_event_id.replace("_", " ").capitalize(), attendance_count])

	var unlock_software_variant: Variant = task.get("unlock_software_rewards", [])
	if unlock_software_variant is Array:
		var unlocked_labels: Array[String] = []
		for software in unlock_software_variant:
			var software_id := str(software).strip_edges()
			if software_id.is_empty():
				continue
			_unlock_software_for_all_workstations(software_id)
			unlocked_labels.append(software_id.replace("_", " "))
		if not unlocked_labels.is_empty():
			reward_summary.append("Unlocked software: %s" % ", ".join(unlocked_labels))

	if bool(task.get("unlock_cluster_access", false)):
		_unlock_cluster_for_all_workstations()
		reward_summary.append("Cluster access unlocked")

	if reward_summary.is_empty():
		reward_summary.append("No rewards")

	if not task_id.is_empty() and EventBus != null and EventBus.has_signal("task_completed"):
		EventBus.task_completed.emit(local_player_id, task_id)
		if WorldClock != null:
			WorldClock.increment_daily_tasks_completed()

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
	var money_reward :Variant= max(int(task.get("money_reward", 0)), 0)
	if money_reward > 0:
		rewards.append("$%d" % money_reward)

	var salary_increase_reward :Variant= max(int(task.get("salary_increase_reward", 0)), 0)
	if salary_increase_reward > 0:
		rewards.append("Daily salary +$%d" % salary_increase_reward)

	var skill_id := str(task.get("skill_id", ""))
	var xp_reward :Variant= max(int(task.get("xp_reward", 0)), 0)
	if not skill_id.is_empty() and xp_reward > 0:
		rewards.append("%d XP (%s)" % [xp_reward, skill_id.capitalize()])

	var item_rewards_variant: Variant = task.get("item_rewards", [])
	if item_rewards_variant is Array:
		for entry_variant in item_rewards_variant:
			if not (entry_variant is Dictionary):
				continue
			var entry: Dictionary = entry_variant as Dictionary
			var item_id := str(entry.get("item_id", ""))
			var amount :Variant= max(int(entry.get("count", 0)), 0)
			if item_id.is_empty() or amount <= 0:
				continue
			rewards.append("%s x%d" % [item_id.replace("_", " "), amount])

	var observation_time_reward :Variant= max(int(task.get("observation_time_reward", 0)), 0)
	if observation_time_reward > 0:
		rewards.append("Observation time +%d" % observation_time_reward)

	if rewards.is_empty():
		return "Rewards: --"
	return "Rewards: %s" % ", ".join(rewards)


func _validate_task_requirements(task: Dictionary) -> Dictionary:
	var required_programming_progress :Variant= max(int(task.get("required_programming_progress", 0)), 0)
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

	var required_room := str(task.get("required_room", "")).strip_edges()
	if not required_room.is_empty():
		var current_room := _get_current_room_id()
		if current_room != required_room:
			return {
				"ok": false,
				"message": "Need to be in %s (currently %s)." % [required_room.replace("_", " "), current_room.replace("_", " ")],
			}

	var required_event_active := str(task.get("required_event_active", "")).strip_edges()
	if not required_event_active.is_empty():
		if EventManager == null or not EventManager.has_method("is_event_active"):
			return {"ok": false, "message": "Event manager unavailable."}
		if not EventManager.is_event_active(required_event_active):
			return {"ok": false, "message": "Event %s is not active right now." % required_event_active.replace("_", " ")}

	var required_event_attendance :Variant= max(int(task.get("required_event_attendance", 0)), 0)
	if required_event_attendance > 0:
		var attendance_event_id := str(task.get("register_event_attendance", task.get("required_event_active", ""))).strip_edges()
		var current_attendance := 0
		if not attendance_event_id.is_empty() and EventManager != null and EventManager.has_method("get_attendance_count"):
			current_attendance = int(EventManager.get_attendance_count(_resolve_local_player_id(), attendance_event_id))
		if current_attendance < required_event_attendance:
			return {
				"ok": false,
				"message": "Need %d attendances for %s (have %d)." % [required_event_attendance, attendance_event_id.replace("_", " "), current_attendance],
			}

	var required_npc_talked := str(task.get("required_npc_talked", "")).strip_edges()
	if not required_npc_talked.is_empty():
		if not bool(_recent_npc_talks.get(required_npc_talked, false)):
			return {
				"ok": false,
				"message": "Talk to %s first." % required_npc_talked.replace("_", " "),
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
			var amount :Variant= max(int(entry.get("count", 0)), 0)
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
		var amount :Variant= max(int(entry.get("count", 0)), 0)
		if item_id.is_empty() or amount <= 0:
			continue
		InventoryManager.remove_items_by_id(item_id, amount)


func _resolve_local_player_id() -> int:
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1


func _on_npc_talked_to(player_id: int, npc_id: String) -> void:
	if player_id != _resolve_local_player_id():
		return
	if npc_id.is_empty():
		return
	_recent_npc_talks[npc_id] = true


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


func _get_current_room_id() -> String:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return ""
	if scene_root.has_method("get_current_room_id"):
		return str(scene_root.get_current_room_id())
	return ""


func _unlock_software_for_all_workstations(software_id: String) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	for node in scene_root.find_children("*", "ProgrammingComponent", true, false):
		if node != null and node.has_method("unlock_software"):
			node.unlock_software(software_id)


func _unlock_cluster_for_all_workstations() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	for node in scene_root.find_children("*", "ProgrammingComponent", true, false):
		if node != null and node.has_method("unlock_cluster_access"):
			node.unlock_cluster_access()


func _apply_stress_effects_for_task(task: Dictionary, player_id: int, attendance_event_id: String) -> void:
	if StressManager == null:
		return
	if not StressManager.has_method("consume_for_action") or not StressManager.has_method("recover_for_activity"):
		return

	var stress_action := _resolve_task_stress_action(task)
	if not stress_action.is_empty():
		_apply_resolved_stress_action(player_id, stress_action)
	else:
		var skill_id := str(task.get("skill_id", "")).strip_edges().to_lower()
		if skill_id == "tomfoolery":
			StressManager.recover_for_activity(player_id, "tomfoolery")
		elif _is_writing_task(task):
			StressManager.consume_for_action(player_id, "writing")
		elif skill_id == "programming":
			StressManager.consume_for_action(player_id, "coding")
		elif skill_id == "observation":
			StressManager.consume_for_action(player_id, "observing")
		elif skill_id == "teaching":
			StressManager.consume_for_action(player_id, "teaching")

	if attendance_event_id.is_empty():
		return
	if attendance_event_id == "pie_friday":
		StressManager.recover_for_activity(player_id, "pie_friday")
		return
	if EventManager != null and EventManager.has_method("event_has_tag"):
		if EventManager.event_has_tag(attendance_event_id, "social"):
			StressManager.recover_for_activity(player_id, "social")


func _resolve_task_stress_action(task: Dictionary) -> String:
	var explicit_action := str(task.get("stress_action", "")).strip_edges().to_lower()
	if not explicit_action.is_empty():
		return explicit_action
	return ""


func _apply_resolved_stress_action(player_id: int, stress_action: String) -> void:
	if stress_action.begins_with("recover:"):
		var activity := stress_action.trim_prefix("recover:")
		if not activity.is_empty():
			StressManager.recover_for_activity(player_id, activity)
		return
	if stress_action.begins_with("consume:"):
		var action := stress_action.trim_prefix("consume:")
		if not action.is_empty():
			StressManager.consume_for_action(player_id, action)
		return
	StressManager.consume_for_action(player_id, stress_action)


func _is_writing_task(task: Dictionary) -> bool:
	var writing_keywords := [
		"write",
		"writing",
		"draft",
		"memo",
		"proposal",
		"letter",
		"notes",
	]
	var haystacks := [
		str(task.get("id", "")).to_lower(),
		str(task.get("title", "")).to_lower(),
		str(task.get("description", "")).to_lower(),
	]
	for haystack in haystacks:
		for keyword in writing_keywords:
			if haystack.contains(keyword):
				return true
	return false


func _resolve_task_attendance_event_id(task: Dictionary) -> String:
	var register_event := str(task.get("register_event_attendance", "")).strip_edges()
	if not register_event.is_empty():
		return register_event
	return str(task.get("required_event_active", "")).strip_edges()


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
