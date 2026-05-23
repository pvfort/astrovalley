extends Node

# ObservationSystem: Handles observation tasks

const BASE_OBSERVATION_DATA: int = 100
const OBSERVATION_SKILL_ID := "observation"
const OBSERVATION_XP_REWARD := 36
const NEXT_DAY_ENERGY_RATIO_AFTER_OBSERVING := 0.5


func _ready() -> void:
	if not TaskManager.task_completed.is_connected(_on_task_completed):
		TaskManager.task_completed.connect(_on_task_completed)


func start_observe(player_id: int) -> bool:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return false
	if GameManager == null or not GameManager.has_method("consume_observation_time"):
		return false
	if not GameManager.consume_observation_time(player_id, 1):
		return false
	if not TaskManager.start_task(player_id, "observe"):
		if GameManager.has_method("grant_observation_time"):
			GameManager.grant_observation_time(player_id, 1)
		return false
	if EventBus != null:
		EventBus.station_used.emit(player_id, "telescope")
	return true


func _on_task_completed(player_id: int, task_id: String) -> void:
	if task_id != "observe":
		return
	var quality_multiplier := 1.0
	if WeatherManager != null and WeatherManager.has_method("get_observation_quality_multiplier"):
		quality_multiplier = float(WeatherManager.get_observation_quality_multiplier())
	var observation_data := maxi(0, int(round(float(BASE_OBSERVATION_DATA) * maxf(0.0, quality_multiplier))))
	if WorldClock != null and WorldClock.has_method("add_observation_data"):
		WorldClock.add_observation_data(observation_data)
	if WorldClock != null and WorldClock.has_method("add_daily_skill_xp"):
		WorldClock.add_daily_skill_xp(OBSERVATION_SKILL_ID, OBSERVATION_XP_REWARD)
	if GameManager != null and GameManager.has_method("record_observation_output"):
		GameManager.record_observation_output(player_id, observation_data)
	if SkillManager != null and SkillManager.has_method("add_xp"):
		SkillManager.add_xp(OBSERVATION_SKILL_ID, OBSERVATION_XP_REWARD)
	if EnergyManager != null and EnergyManager.has_method("apply_next_sleep_start_ratio"):
		EnergyManager.apply_next_sleep_start_ratio(player_id, NEXT_DAY_ENERGY_RATIO_AFTER_OBSERVING)
