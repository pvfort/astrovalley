extends Node

# ObservationSystem: Handles observation tasks

const BASE_OBSERVATION_DATA: int = 100
const OBSERVATION_SKILL_ID := "observation"
const OBSERVATION_XP_REWARD := 36
const NEXT_DAY_ENERGY_RATIO_AFTER_OBSERVING := 0.5


func submit_observation(player_id: int, tracking_ratio: float) -> Dictionary:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return {"ok": false, "message": "Observation unavailable on client."}
	if GameManager == null or not GameManager.has_method("consume_observation_time"):
		return {"ok": false, "message": "Game manager unavailable."}
	if not GameManager.consume_observation_time(player_id, 1):
		return {"ok": false, "message": "You need observation time from tasks first."}

	var tracking_quality := clampf(tracking_ratio, 0.0, 1.0)
	var weather_multiplier := 1.0
	if WeatherManager != null and WeatherManager.has_method("get_observation_quality_multiplier"):
		weather_multiplier = maxf(float(WeatherManager.get_observation_quality_multiplier()), 0.0)

	var data_quality := maxf(tracking_quality * weather_multiplier, 0.0)
	var observation_data := maxi(0, int(round(float(BASE_OBSERVATION_DATA) * data_quality)))
	var xp_reward := maxi(0, int(round(float(OBSERVATION_XP_REWARD) * tracking_quality)))

	if EventBus != null:
		EventBus.station_used.emit(player_id, "telescope")
		if EventBus.has_signal("task_completed"):
			EventBus.task_completed.emit(player_id, "observe")

	if WorldClock != null and WorldClock.has_method("add_observation_data"):
		WorldClock.add_observation_data(observation_data)
	if WorldClock != null and WorldClock.has_method("add_daily_skill_xp") and xp_reward > 0:
		WorldClock.add_daily_skill_xp(OBSERVATION_SKILL_ID, xp_reward)
	if WorldClock != null and WorldClock.has_method("increment_daily_tasks_completed"):
		WorldClock.increment_daily_tasks_completed()
	if GameManager != null and GameManager.has_method("record_observation_output"):
		GameManager.record_observation_output(player_id, observation_data)
	if SkillManager != null and SkillManager.has_method("add_xp") and xp_reward > 0:
		SkillManager.add_xp(OBSERVATION_SKILL_ID, xp_reward)
	if EnergyManager != null and EnergyManager.has_method("apply_next_sleep_start_ratio"):
		EnergyManager.apply_next_sleep_start_ratio(player_id, NEXT_DAY_ENERGY_RATIO_AFTER_OBSERVING)

	if SaveManager != null and SaveManager.has_method("request_autosave"):
		SaveManager.request_autosave()

	return {
		"ok": true,
		"message": "Observation complete · %s quality · +%d data · +%d XP." % [quality_label_for_ratio(data_quality), observation_data, xp_reward],
		"tracking_ratio": tracking_quality,
		"data_quality": data_quality,
		"quality_label": quality_label_for_ratio(data_quality),
		"data_reward": observation_data,
		"xp_reward": xp_reward,
	}


func quality_label_for_ratio(ratio: float) -> String:
	var clamped := maxf(ratio, 0.0)
	if clamped >= 0.85:
		return "Excellent"
	if clamped >= 0.6:
		return "Good"
	if clamped >= 0.35:
		return "Fair"
	if clamped > 0.0:
		return "Poor"
	return "Noisy"
