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
				tasks[task["id"]] = task

func start_task(player_id: int, task_id: String) -> bool:
	if not tasks.has(task_id):
		return false
	
	var task = tasks[task_id]
	var current_phase = TimeManager.get_current_phase()
	if task["allowed_phase"] != current_phase:
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
	task_completed.emit(player_id, task_id)

func get_active_task(player_id: int) -> String:
	if active_tasks.has(player_id):
		return active_tasks[player_id]["task_id"]
	return ""