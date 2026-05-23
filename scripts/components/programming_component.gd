class_name ProgrammingComponent
extends InteractableComponent

signal programming_started(player_id: int)
signal programming_completed(player_id: int)

const PROGRAMMING_PRIORITY := 10

const DEFAULT_EMAIL_MESSAGES: Array[Dictionary] = [
	{
		"id": "email_prof_vega_1",
		"sender": "Prof. Vega",
		"subject": "Transit catalog subset",
		"body": "Pushing a calibrated subset from last week. Should be enough for local scripts.",
		"attachment": {
			"data_type": "small_data",
			"amount": 4,
			"quality": "small",
		},
		"downloaded": false,
	},
	{
		"id": "email_obs_north_1",
		"sender": "North Observatory",
		"subject": "Night block observations",
		"body": "Observation package is ready. Includes reduced light curves for proposal work.",
		"attachment": {
			"data_type": "special_data",
			"amount": 1,
			"quality": "special",
		},
		"downloaded": false,
	},
	{
		"id": "email_prof_lin_1",
		"sender": "Prof. Lin",
		"subject": "Sanity-check benchmark set",
		"body": "Use this benchmark set to validate your local processing scripts.",
		"attachment": {
			"data_type": "small_data",
			"amount": 3,
			"quality": "small",
		},
		"downloaded": false,
	},
]

const HARD_DRIVE_DATA: Dictionary = {
	"hard_drive_archive": {
		"data": {
			"big_data": 6,
		},
		"unlock_cluster": false,
	},
	"cluster_access_drive": {
		"data": {
			"big_data": 8,
		},
		"unlock_cluster": true,
	},
}

const PROJECT_DEFINITIONS: Array[Dictionary] = [
	{
		"id": "local_cleaning_pipeline",
		"display_name": "Local cleaning pipeline",
		"description": "Run local scripts on small data to produce clean samples for chapter drafts.",
		"required_data": {
			"small_data": 2,
		},
		"script_type": "local",
		"required_software": ["text_editor"],
		"xp_gain": 24,
		"time_minutes": 35,
		"progress_gain": 35,
		"energy_cost": 8.0,
	},
	{
		"id": "cluster_reduction_batch",
		"display_name": "Cluster reduction batch",
		"description": "Process bulk hard-drive data using cluster scripts for higher quality outputs.",
		"required_data": {
			"big_data": 4,
		},
		"script_type": "cluster",
		"required_software": ["python_toolkit"],
		"xp_gain": 48,
		"time_minutes": 70,
		"progress_gain": 70,
		"energy_cost": 14.0,
	},
	{
		"id": "proposal_observation_analysis",
		"display_name": "Proposal observation analysis",
		"description": "Combine special observation data with bulk reductions for milestone thesis results.",
		"required_data": {
			"special_data": 1,
			"big_data": 2,
		},
		"script_type": "cluster",
		"required_software": ["python_toolkit", "analysis_suite"],
		"xp_gain": 80,
		"time_minutes": 100,
		"progress_gain": 120,
		"energy_cost": 18.0,
	},
]

@export var station_id: String = "computer_station"
@export var skill_id: String = "programming"
@export var consume_energy: bool = true
@export var energy_cost: float = 12.0
@export var workstation_ui_path: NodePath
@export var active_texture: Texture2D = preload("res://assets/entities/furniture/computer_on.png")
@export var sprite_path: NodePath = NodePath("Sprite2D")
@export var unlocked_software: Array[String] = ["text_editor"]
@export var unlocked_script_modes: Array[String] = ["local"]
@export var cluster_access_unlocked := false

var _original_texture: Texture2D
var _is_coding := false
var _is_ui_open := false
var _pc_data_storage: Dictionary = {
	"small_data": 0,
	"big_data": 0,
	"special_data": 0,
}
var _email_messages: Array[Dictionary] = []
var _mounted_hard_drives: Array[String] = []


func _ready() -> void:
	priority = max(priority, PROGRAMMING_PRIORITY)
	if _email_messages.is_empty():
		_email_messages = _duplicate_email_messages(DEFAULT_EMAIL_MESSAGES)
	if cluster_access_unlocked and not unlocked_script_modes.has("cluster"):
		unlocked_script_modes.append("cluster")


func can_interact(_player: PlayerCharacter) -> bool:
	if _is_coding:
		return false
	return true


func interact(player: PlayerCharacter) -> void:
	if player == null or _is_coding:
		return

	var ui := _find_workstation_ui()
	if ui == null:
		push_warning("[ProgrammingComponent] ComputerWorkstationUI not found.")
		return

	if EventBus != null:
		EventBus.station_used.emit(player.player_id, station_id)

	_is_ui_open = true
	_set_computer_visual(true)
	if ui.has_method("open_for_station"):
		ui.open_for_station(self, player)


func notify_ui_closed() -> void:
	_is_ui_open = false
	if not _is_coding:
		_set_computer_visual(false)


func get_email_messages() -> Array[Dictionary]:
	return _email_messages.duplicate(true)


func get_pc_data() -> Dictionary:
	return _pc_data_storage.duplicate(true)


func get_coding_projects() -> Array[Dictionary]:
	return PROJECT_DEFINITIONS.duplicate(true)


func get_project_by_id(project_id: String) -> Dictionary:
	for project in PROJECT_DEFINITIONS:
		if str(project.get("id", "")) == project_id:
			return project.duplicate(true)
	return {}


func format_project_requirements(project: Dictionary) -> String:
	var req_data_variant: Variant = project.get("required_data", {})
	var req_data: Dictionary = req_data_variant as Dictionary if req_data_variant is Dictionary else {}
	var req_parts: Array[String] = []
	for key_variant in req_data.keys():
		var key := str(key_variant)
		req_parts.append("%s x%d" % [key.replace("_", " "), int(req_data.get(key_variant, 0))])
	req_parts.sort()

	var script_type := str(project.get("script_type", "local"))
	var software_needed: Array[String] = []
	var software_variant: Variant = project.get("required_software", [])
	if software_variant is Array:
		for entry in software_variant:
			software_needed.append(str(entry))

	var data_text := "Data: %s" % (", ".join(req_parts) if not req_parts.is_empty() else "none")
	var scripts_text := "Scripts: %s" % script_type
	var software_text := "Software: %s" % (", ".join(software_needed) if not software_needed.is_empty() else "none")
	return "%s\n%s\n%s" % [data_text, scripts_text, software_text]


func can_code_project(project_id: String) -> Dictionary:
	var project := get_project_by_id(project_id)
	if project.is_empty():
		return {"ok": false, "message": "Project not found."}

	var script_type := str(project.get("script_type", "local"))
	if not unlocked_script_modes.has(script_type):
		return {"ok": false, "message": "Missing %s script access." % script_type}

	if script_type == "cluster" and not _has_cluster_access():
		return {"ok": false, "message": "Cluster access is still locked."}

	var required_software_variant: Variant = project.get("required_software", [])
	if required_software_variant is Array:
		for software_entry in required_software_variant:
			var software := str(software_entry)
			if not unlocked_software.has(software):
				return {"ok": false, "message": "Missing software: %s" % software.replace("_", " ")}

	var required_data_variant: Variant = project.get("required_data", {})
	var required_data: Dictionary = required_data_variant as Dictionary if required_data_variant is Dictionary else {}
	for data_key_variant in required_data.keys():
		var data_key := str(data_key_variant)
		var needed :Variant= max(int(required_data.get(data_key_variant, 0)), 0)
		var available := int(_pc_data_storage.get(data_key, 0))
		if available < needed:
			return {
				"ok": false,
				"message": "Need %s x%d (have %d)." % [data_key.replace("_", " "), needed, available],
			}

	return {"ok": true, "message": "Ready to code."}


func code_project(project_id: String, player: PlayerCharacter) -> Dictionary:
	if _is_coding:
		return {"ok": false, "message": "Computer is already running a coding task."}

	var can_code_result := can_code_project(project_id)
	if not bool(can_code_result.get("ok", false)):
		return can_code_result

	var project := get_project_by_id(project_id)
	if project.is_empty():
		return {"ok": false, "message": "Project not found."}

	_consume_required_data(project)
	_is_coding = true
	_set_computer_visual(true)

	var xp_gain :Variant= max(int(project.get("xp_gain", 0)), 0)
	var time_minutes :Variant= max(int(project.get("time_minutes", 1)), 1)
	var progress_gain :Variant= max(int(project.get("progress_gain", time_minutes)), 0)
	var action_energy_cost := float(project.get("energy_cost", energy_cost))

	var pid := _resolve_player_id(player)
	programming_started.emit(pid)

	if skill_id != "" and SkillManager != null:
		SkillManager.add_xp(skill_id, xp_gain)
	if WorldClock != null:
		WorldClock.add_minutes(time_minutes)
		WorldClock.add_programming_progress(progress_gain)
		if skill_id != "":
			WorldClock.add_daily_skill_xp(skill_id, xp_gain)

	_attempt_energy_spend(player, action_energy_cost)

	programming_completed.emit(pid)
	_is_coding = false
	if not _is_ui_open:
		_set_computer_visual(false)
	_request_autosave()

	var project_name := str(project.get("display_name", project_id)).replace("_", " ")
	return {
		"ok": true,
		"message": "Completed %s. +%d XP, +%d thesis progress." % [project_name, xp_gain, progress_gain],
	}


func download_email_attachment(message_index: int) -> Dictionary:
	if message_index < 0 or message_index >= _email_messages.size():
		return {"ok": false, "message": "Select an email first."}

	var message: Dictionary = _email_messages[message_index]
	if bool(message.get("downloaded", false)):
		return {"ok": false, "message": "Data already downloaded for this email."}

	var attachment_variant: Variant = message.get("attachment", {})
	var attachment: Dictionary = attachment_variant as Dictionary if attachment_variant is Dictionary else {}
	var data_type := str(attachment.get("data_type", ""))
	var amount :Variant= max(int(attachment.get("amount", 0)), 0)
	if data_type.is_empty() or amount <= 0:
		return {"ok": false, "message": "Email has no valid data attachment."}

	_pc_data_storage[data_type] = int(_pc_data_storage.get(data_type, 0)) + amount
	message["downloaded"] = true
	_email_messages[message_index] = message
	_request_autosave()

	return {
		"ok": true,
		"message": "Downloaded %s x%d to PC storage." % [data_type.replace("_", " "), amount],
	}


func get_mountable_drive_item_ids() -> Array[String]:
	var options: Array[String] = []
	for item_key_variant in HARD_DRIVE_DATA.keys():
		var item_id := str(item_key_variant)
		if _mounted_hard_drives.has(item_id):
			continue
		if InventoryManager == null:
			continue
		if InventoryManager.count_item(item_id) <= 0:
			continue
		options.append(item_id)
	options.sort()
	return options


func get_mounted_hard_drives() -> Array[String]:
	return _mounted_hard_drives.duplicate()


func mount_hard_drive(item_id: String) -> Dictionary:
	if item_id.is_empty():
		return {"ok": false, "message": "No hard drive selected."}
	if _mounted_hard_drives.has(item_id):
		return {"ok": false, "message": "That hard drive is already mounted."}
	if not HARD_DRIVE_DATA.has(item_id):
		return {"ok": false, "message": "Unsupported hard drive."}
	if InventoryManager == null:
		return {"ok": false, "message": "Inventory manager unavailable."}
	if InventoryManager.count_item(item_id) <= 0:
		return {"ok": false, "message": "You do not have that hard drive in inventory."}
	if not InventoryManager.remove_items_by_id(item_id, 1):
		return {"ok": false, "message": "Could not mount hard drive."}

	_mounted_hard_drives.append(item_id)
	var drive_payload_variant: Variant = HARD_DRIVE_DATA.get(item_id, {})
	var drive_payload: Dictionary = drive_payload_variant as Dictionary if drive_payload_variant is Dictionary else {}
	var data_variant: Variant = drive_payload.get("data", {})
	var data_bundle: Dictionary = data_variant as Dictionary if data_variant is Dictionary else {}
	for data_key_variant in data_bundle.keys():
		var key := str(data_key_variant)
		var amount :Variant= max(int(data_bundle.get(data_key_variant, 0)), 0)
		_pc_data_storage[key] = int(_pc_data_storage.get(key, 0)) + amount

	if bool(drive_payload.get("unlock_cluster", false)):
		unlock_cluster_access()

	_request_autosave()
	return {
		"ok": true,
		"message": "Mounted %s and imported its data payload." % item_id.replace("_", " "),
	}


func unlock_cluster_access() -> void:
	cluster_access_unlocked = true
	if not unlocked_script_modes.has("cluster"):
		unlocked_script_modes.append("cluster")


func unlock_software(software_id: String) -> void:
	if software_id.is_empty():
		return
	if unlocked_software.has(software_id):
		return
	unlocked_software.append(software_id)


func save_state() -> Dictionary:
	return {
		"is_interacting": _is_coding,
		"pc_data_storage": _pc_data_storage.duplicate(true),
		"email_messages": _email_messages.duplicate(true),
		"mounted_hard_drives": _mounted_hard_drives.duplicate(),
		"cluster_access_unlocked": cluster_access_unlocked,
		"unlocked_software": unlocked_software.duplicate(),
		"unlocked_script_modes": unlocked_script_modes.duplicate(),
	}


func load_state(data: Dictionary) -> void:
	_is_coding = bool(data.get("is_interacting", false))

	var loaded_data_variant: Variant = data.get("pc_data_storage", _pc_data_storage)
	if loaded_data_variant is Dictionary:
		_pc_data_storage = (loaded_data_variant as Dictionary).duplicate(true)

	var loaded_emails_variant: Variant = data.get("email_messages", [])
	if loaded_emails_variant is Array:
		_email_messages = []
		for entry in loaded_emails_variant:
			if entry is Dictionary:
				_email_messages.append((entry as Dictionary).duplicate(true))

	if _email_messages.is_empty():
		_email_messages = _duplicate_email_messages(DEFAULT_EMAIL_MESSAGES)

	var drives_variant: Variant = data.get("mounted_hard_drives", [])
	if drives_variant is Array:
		_mounted_hard_drives.clear()
		for drive in drives_variant:
			_mounted_hard_drives.append(str(drive))

	cluster_access_unlocked = bool(data.get("cluster_access_unlocked", cluster_access_unlocked))

	var software_variant: Variant = data.get("unlocked_software", unlocked_software)
	if software_variant is Array:
		unlocked_software.clear()
		for software in software_variant:
			unlocked_software.append(str(software))

	var script_modes_variant: Variant = data.get("unlocked_script_modes", unlocked_script_modes)
	if script_modes_variant is Array:
		unlocked_script_modes.clear()
		for mode in script_modes_variant:
			unlocked_script_modes.append(str(mode))

	if cluster_access_unlocked and not unlocked_script_modes.has("cluster"):
		unlocked_script_modes.append("cluster")
	if unlocked_software.is_empty():
		unlocked_software.append("text_editor")
	if unlocked_script_modes.is_empty():
		unlocked_script_modes.append("local")

	_is_ui_open = false
	_set_computer_visual(_is_coding)


func _consume_required_data(project: Dictionary) -> void:
	var req_variant: Variant = project.get("required_data", {})
	if not (req_variant is Dictionary):
		return
	var req: Dictionary = req_variant as Dictionary
	for key_variant in req.keys():
		var key := str(key_variant)
		var amount :Variant= max(int(req.get(key_variant, 0)), 0)
		var available := int(_pc_data_storage.get(key, 0))
		_pc_data_storage[key] = max(available - amount, 0)


func _has_cluster_access() -> bool:
	return cluster_access_unlocked


func _resolve_player_id(player: PlayerCharacter) -> int:
	if player != null and player.player_id >= 0:
		return player.player_id
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return -1


func _attempt_energy_spend(player: PlayerCharacter, amount: float) -> void:
	if not consume_energy or amount <= 0.0 or player == null:
		return

	if player.has_method("consume_energy"):
		player.consume_energy(amount)
		return

	var status: StatusEffectComponent = player.get_status_effect_component()
	if status != null and status.has_method("apply"):
		status.apply("programming_fatigue", amount, {"temporary": true, "source": "programming"})


func _set_computer_visual(active: bool) -> void:
	var sprite := get_parent().get_node_or_null(sprite_path) as Sprite2D
	if sprite == null:
		return

	if _original_texture == null:
		_original_texture = sprite.texture

	if active and active_texture != null:
		sprite.texture = active_texture
	else:
		sprite.texture = _original_texture


func _find_workstation_ui() -> Node:
	if not workstation_ui_path.is_empty():
		var ui_from_path := get_node_or_null(workstation_ui_path)
		if ui_from_path != null:
			return ui_from_path

	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null

	return scene_root.find_child("ComputerWorkstationUI", true, false)


func _request_autosave() -> void:
	if SaveManager != null and SaveManager.has_method("request_autosave"):
		SaveManager.request_autosave()


func _duplicate_email_messages(source: Array[Dictionary]) -> Array[Dictionary]:
	var duplicated: Array[Dictionary] = []
	for entry in source:
		duplicated.append(entry.duplicate(true))
	return duplicated
