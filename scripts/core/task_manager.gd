extends Node

# TaskManager: Manages tasks from JSON
# Data-driven task system

signal task_started(player_id: int, task_id: String)
signal task_completed(player_id: int, task_id: String)

var tasks: Dictionary = {}
var active_tasks: Dictionary = {}  # player_id -> {task_id, timer}

func _ready():
	load_tasks()

func load_tasks():
	var file = FileAccess.open("res://data/tasks.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			var task_list = json.data
			for task in task_list:
				if not (task is Dictionary):
					continue
				var task_entry: Dictionary = task as Dictionary
				var task_id: String = str(task_entry.get("id", ""))
				if task_id.is_empty():
					push_warning("[TaskManager] Skipping task with missing id.")
					continue
				var allowed_phase: String = str(task_entry.get("allowed_phase", "")).to_lower()
				if allowed_phase.is_empty():
					push_warning("[TaskManager] Skipping task %s with missing allowed_phase." % task_id)
					continue
				var duration := float(task_entry.get("duration", 0.0))
				if duration <= 0.0:
					push_warning("[TaskManager] Skipping task %s with invalid duration." % task_id)
					continue
				tasks[task_id] = task_entry

func start_task(player_id: int, task_id: String) -> bool:
	if active_tasks.has(player_id):
		return false
	if not tasks.has(task_id):
		return false
	
	var task = tasks[task_id]
	var current_phase = TimeManager.get_current_phase()
	if str(task.get("allowed_phase", "")).to_lower() != current_phase.to_lower():
		return false

	if task_id == "observe" and WeatherManager != null and WeatherManager.has_method("is_telescope_usable"):
		if not WeatherManager.is_telescope_usable():
			return false
	
	# Check resource if required
	if task.has("required_resource"):
		if not GameManager.is_resource_available(task["required_resource"]):
			return false
		GameManager.lock_resource(task["required_resource"], player_id)
	
	# Start task
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = task["duration"]
	timer.one_shot = true
	timer.timeout.connect(func(): complete_task(player_id))
	timer.start()
	
	active_tasks[player_id] = {"task_id": task_id, "timer": timer}
	if EventBus != null:
		EventBus.task_started.emit(player_id, task_id)
	task_started.emit(player_id, task_id)
	return true

func complete_task(player_id: int):
	if not active_tasks.has(player_id):
		return
	
	var task_data = active_tasks[player_id]
	var task_id = task_data["task_id"]
	var task = tasks[task_id]
	
	# Unlock resource
	if task.has("required_resource"):
		GameManager.unlock_resource(task["required_resource"])
	
	task_data["timer"].queue_free()
	active_tasks.erase(player_id)
	if WorldClock != null and WorldClock.has_method("increment_daily_tasks_completed"):
		WorldClock.increment_daily_tasks_completed()
	if EventBus != null:
		EventBus.task_completed.emit(player_id, task_id)
	task_completed.emit(player_id, task_id)

func get_active_task(player_id: int) -> String:
	if active_tasks.has(player_id):
		return active_tasks[player_id]["task_id"]
	return ""

func save_state() -> Dictionary:
	var serialized_active_tasks: Dictionary = {}
	for player_id_variant in active_tasks.keys():
		var player_id: int = int(player_id_variant)
		var task_data: Dictionary = active_tasks[player_id] as Dictionary
		serialized_active_tasks[str(player_id)] = {
			"task_id": str(task_data.get("task_id", "")),
		}
	return {
		"active_tasks": serialized_active_tasks,
	}

func load_state(data: Dictionary) -> void:
	for task_data_variant in active_tasks.values():
		if not (task_data_variant is Dictionary):
			continue
		var task_data: Dictionary = task_data_variant as Dictionary
		var timer: Timer = task_data.get("timer", null) as Timer
		if timer != null and is_instance_valid(timer):
			timer.queue_free()

	active_tasks.clear()

	var saved_active_tasks := data.get("active_tasks", {})
	if not (saved_active_tasks is Dictionary):
		return

	for player_id_variant in (saved_active_tasks as Dictionary).keys():
		var entry_variant: Variant = (saved_active_tasks as Dictionary).get(player_id_variant, {})
		if not (entry_variant is Dictionary):
			continue
		var player_id: int = int(player_id_variant)
		var task_id: String = str((entry_variant as Dictionary).get("task_id", ""))
		if task_id.is_empty():
			continue
		start_task(player_id, task_id)
