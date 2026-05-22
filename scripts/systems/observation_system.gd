extends Node

# ObservationSystem: Handles observation tasks

const BASE_OBSERVATION_DATA: int = 100


func _ready() -> void:
	if not TaskManager.task_completed.is_connected(_on_task_completed):
		TaskManager.task_completed.connect(_on_task_completed)


func start_observe(player_id: int) -> bool:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return false
	if WeatherManager != null and WeatherManager.has_method("is_telescope_usable"):
		if not WeatherManager.is_telescope_usable():
			return false
	if TaskManager.start_task(player_id, "observe"):
		if EventBus != null:
			EventBus.station_used.emit(player_id, "telescope")
		return true
	return false


func _on_task_completed(player_id: int, task_id: String) -> void:
	if task_id != "observe":
		return
	var quality_multiplier := 1.0
	if WeatherManager != null and WeatherManager.has_method("get_observation_quality_multiplier"):
		quality_multiplier = float(WeatherManager.get_observation_quality_multiplier())
	var observation_data := maxi(0, int(round(float(BASE_OBSERVATION_DATA) * maxf(0.0, quality_multiplier))))
	if WorldClock != null and WorldClock.has_method("add_observation_data"):
		WorldClock.add_observation_data(observation_data)
	if GameManager != null and GameManager.has_method("record_observation_output"):
		GameManager.record_observation_output(player_id, observation_data)
