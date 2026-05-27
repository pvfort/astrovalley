class_name ObservationComponent
extends InteractableComponent

const OBSERVATION_PRIORITY := 20
const ENGINEERING_SKILL_ID := "engineering"
const CALIBRATION_XP_REWARD := 28
const CALIBRATION_REQUIREMENTS: Array[Dictionary] = [
	{"item_id": "printer_station", "count": 1},
	{"item_id": "office_chair", "count": 1},
]

@export var station_id: String = "telescope"
@export var telescope_ui_path: NodePath

func _ready() -> void:
	priority = max(priority, OBSERVATION_PRIORITY)

func can_interact(player: PlayerCharacter) -> bool:
	if player == null:
		return false
	if TaskManager != null and TaskManager.has_method("get_active_task"):
		if TaskManager.get_active_task(player.player_id) != "":
			return false
	return true

func interact(player: PlayerCharacter) -> void:
	if player == null:
		return

	var telescope_ui := _find_telescope_ui(player)
	if telescope_ui == null:
		push_warning("[ObservationComponent] TelescopeUI not found.")
		return

	if telescope_ui.has_method("open_for_station"):
		telescope_ui.open_for_station(self, player)

func get_calibration_requirements() -> Array[Dictionary]:
	return CALIBRATION_REQUIREMENTS.duplicate(true)

func is_calibrated(player_id: int) -> bool:
	if GameManager == null or not GameManager.has_method("is_telescope_calibrated"):
		return false
	return bool(GameManager.is_telescope_calibrated(player_id))

func get_observation_time(player_id: int) -> int:
	if GameManager == null or not GameManager.has_method("get_observation_time"):
		return 0
	return max(int(GameManager.get_observation_time(player_id)), 0)

func can_calibrate(player_id: int) -> Dictionary:
	if is_calibrated(player_id):
		return {"ok": false, "message": "Telescope already calibrated."}
	if InventoryManager == null:
		return {"ok": false, "message": "Inventory manager unavailable."}
	for requirement in CALIBRATION_REQUIREMENTS:
		var item_id := str(requirement.get("item_id", ""))
		var amount := max(int(requirement.get("count", 0)), 0)
		if item_id.is_empty() or amount <= 0:
			continue
		var available := InventoryManager.count_item(item_id)
		if available < amount:
			return {"ok": false, "message": "Need %s x%d (have %d)." % [item_id.replace("_", " "), amount, available]}
	return {"ok": true, "message": "Ready to calibrate."}

func calibrate(player_id: int) -> Dictionary:
	var validation := can_calibrate(player_id)
	if not bool(validation.get("ok", false)):
		return validation

	for requirement in CALIBRATION_REQUIREMENTS:
		var item_id := str(requirement.get("item_id", ""))
		var amount := max(int(requirement.get("count", 0)), 0)
		if item_id.is_empty() or amount <= 0:
			continue
		InventoryManager.remove_items_by_id(item_id, amount)

	if SkillManager != null and SkillManager.has_method("add_xp"):
		SkillManager.add_xp(ENGINEERING_SKILL_ID, CALIBRATION_XP_REWARD)
	if WorldClock != null and WorldClock.has_method("add_daily_skill_xp"):
		WorldClock.add_daily_skill_xp(ENGINEERING_SKILL_ID, CALIBRATION_XP_REWARD)
	if GameManager != null and GameManager.has_method("set_telescope_calibrated"):
		GameManager.set_telescope_calibrated(player_id, true)
	if EventBus != null and EventBus.has_signal("station_used"):
		EventBus.station_used.emit(player_id, "%s_calibration" % station_id)
	if SaveManager != null and SaveManager.has_method("request_autosave"):
		SaveManager.request_autosave()

	return {"ok": true, "message": "Calibration complete. +%d Engineering XP." % CALIBRATION_XP_REWARD}

func submit_observation(player_id: int, tracking_ratio: float) -> Dictionary:
	if not is_calibrated(player_id):
		return {"ok": false, "message": "Calibrate the telescope first."}
	if get_observation_time(player_id) <= 0:
		return {"ok": false, "message": "You need observation time from tasks first."}
	if ObservationSystem == null or not ObservationSystem.has_method("submit_observation"):
		return {"ok": false, "message": "Observation system unavailable."}
	return ObservationSystem.submit_observation(player_id, tracking_ratio)

func _find_telescope_ui(target_player: PlayerCharacter = null) -> Node:
	if target_player != null:
		var player_ui := target_player.get_node_or_null("CanvasLayer/TelescopeUI")
		if player_ui != null:
			return player_ui

	if not telescope_ui_path.is_empty():
		var ui_from_path := get_node_or_null(telescope_ui_path)
		if ui_from_path != null:
			return ui_from_path

	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null

	return scene_root.find_child("TelescopeUI", true, false)
