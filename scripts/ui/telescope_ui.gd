class_name TelescopeUI
extends Control

const MINIGAME_DURATION := 20.0
const AIM_SPEED := 190.0
const OBJECT_BASE_SPEED := 120.0
const OBJECT_SPEED_VARIANCE := 90.0
const OBJECT_DIRECTION_UPDATE_INTERVAL := 0.65
const ALIGNMENT_THRESHOLD := 22.0

@onready var tab_container: TabContainer = $Panel/MarginContainer/VBoxContainer/TabContainer
@onready var calibration_requirements_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/CalibrationTab/CalibrationRequirements
@onready var calibration_status_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/CalibrationTab/CalibrationStatusLabel
@onready var calibrate_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/CalibrationTab/CalibrateButton
@onready var observation_info_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/ObservationTab/ObservationInfoLabel
@onready var observation_status_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/ObservationTab/ObservationStatusLabel
@onready var start_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/ObservationTab/ObservationButtons/StartObservationButton
@onready var progress_bar: ProgressBar = $Panel/MarginContainer/VBoxContainer/TabContainer/ObservationTab/ObservationMiniGame/ProgressBar
@onready var game_field: Control = $Panel/MarginContainer/VBoxContainer/TabContainer/ObservationTab/ObservationMiniGame/GameField
@onready var object_marker: ColorRect = $Panel/MarginContainer/VBoxContainer/TabContainer/ObservationTab/ObservationMiniGame/GameField/ObjectMarker
@onready var aim_marker: ColorRect = $Panel/MarginContainer/VBoxContainer/TabContainer/ObservationTab/ObservationMiniGame/GameField/AimMarker
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/Buttons/CloseButton

var station: ObservationComponent
var player: PlayerCharacter

var _minigame_running := false
var _elapsed := 0.0
var _aligned_time := 0.0
var _object_velocity := Vector2.ZERO
var _object_direction_timer := 0.0


func _ready() -> void:
	visible = false
	calibrate_button.pressed.connect(_on_calibrate_pressed)
	start_button.pressed.connect(_on_start_pressed)
	close_button.pressed.connect(close_ui)
	progress_bar.max_value = MINIGAME_DURATION
	progress_bar.value = 0.0


func open_for_station(target_station: ObservationComponent, target_player: PlayerCharacter) -> void:
	if target_station == null:
		return

	station = target_station
	player = target_player
	visible = true
	tab_container.current_tab = 0
	_minigame_running = false
	progress_bar.value = 0.0
	if InventoryManager != null:
		InventoryManager.set_inventory_open(true)
	_refresh_view()


func close_ui() -> void:
	_minigame_running = false
	visible = false
	station = null
	player = null
	if InventoryManager != null:
		InventoryManager.set_inventory_open(false)


func is_open() -> bool:
	return visible


func _refresh_view() -> void:
	_refresh_calibration_tab()
	_refresh_observation_tab()


func _refresh_calibration_tab() -> void:
	if station == null:
		calibration_requirements_label.text = "Requirements unavailable."
		calibration_status_label.text = ""
		calibrate_button.disabled = true
		return

	var requirement_lines: Array[String] = []
	for requirement in station.get_calibration_requirements():
		var item_id := str(requirement.get("item_id", ""))
		var amount := max(int(requirement.get("count", 0)), 0)
		var available := InventoryManager.count_item(item_id) if InventoryManager != null else 0
		if item_id.is_empty() or amount <= 0:
			continue
		requirement_lines.append("%s x%d (have %d)" % [item_id.replace("_", " "), amount, available])
	calibration_requirements_label.text = "Mechanical resources:\n%s" % "\n".join(requirement_lines)

	var player_id := _resolve_player_id()
	if station.is_calibrated(player_id):
		calibration_status_label.text = "Status: Calibrated"
		calibrate_button.disabled = true
		return

	var can_calibrate_result := station.can_calibrate(player_id)
	calibration_status_label.text = "Status: Not calibrated"
	calibrate_button.disabled = not bool(can_calibrate_result.get("ok", false))


func _refresh_observation_tab() -> void:
	if station == null:
		observation_info_label.text = "Observation station unavailable."
		observation_status_label.text = ""
		start_button.disabled = true
		return

	var player_id := _resolve_player_id()
	var calibrated := station.is_calibrated(player_id)
	var observation_time := station.get_observation_time(player_id)
	observation_info_label.text = "Calibrated: %s · Observation time: %d" % ["yes" if calibrated else "no", observation_time]
	start_button.disabled = _minigame_running or not calibrated or observation_time <= 0


func _on_calibrate_pressed() -> void:
	if station == null:
		return
	var result := station.calibrate(_resolve_player_id())
	calibration_status_label.text = str(result.get("message", "Calibration failed."))
	_refresh_view()


func _on_start_pressed() -> void:
	if station == null or _minigame_running:
		return
	_begin_minigame()


func _begin_minigame() -> void:
	_minigame_running = true
	_elapsed = 0.0
	_aligned_time = 0.0
	_object_direction_timer = 0.0
	progress_bar.value = 0.0

	var half_size := game_field.size * 0.5
	object_marker.position = _clamp_to_field(half_size)
	aim_marker.position = _clamp_to_field(half_size + Vector2(25.0, 0.0))
	_randomize_object_velocity()
	observation_status_label.text = "Use arrow keys to keep the telescope aligned."
	start_button.disabled = true
	calibrate_button.disabled = true


func _process(delta: float) -> void:
	if not visible or not _minigame_running:
		return

	_update_aim(delta)
	_update_object(delta)
	_update_alignment(delta)

	_elapsed += delta
	progress_bar.value = clampf(_elapsed, 0.0, MINIGAME_DURATION)

	if _elapsed >= MINIGAME_DURATION:
		_finish_minigame()


func _update_aim(delta: float) -> void:
	var input_vector := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	if input_vector.length_squared() > 1.0:
		input_vector = input_vector.normalized()
	aim_marker.position = _clamp_to_field(aim_marker.position + input_vector * AIM_SPEED * delta)


func _update_object(delta: float) -> void:
	_object_direction_timer -= delta
	if _object_direction_timer <= 0.0:
		_randomize_object_velocity()

	object_marker.position = _clamp_to_field(object_marker.position + _object_velocity * delta)


func _update_alignment(delta: float) -> void:
	var object_center := object_marker.position + (object_marker.size * 0.5)
	var aim_center := aim_marker.position + (aim_marker.size * 0.5)
	if object_center.distance_to(aim_center) <= ALIGNMENT_THRESHOLD:
		_aligned_time += delta


func _finish_minigame() -> void:
	_minigame_running = false
	calibrate_button.disabled = false
	var tracking_ratio := clampf(_aligned_time / MINIGAME_DURATION, 0.0, 1.0)
	var result := station.submit_observation(_resolve_player_id(), tracking_ratio) if station != null else {"ok": false, "message": "Observation station unavailable."}
	observation_status_label.text = str(result.get("message", "Observation failed."))
	_refresh_view()


func _randomize_object_velocity() -> void:
	_object_direction_timer = OBJECT_DIRECTION_UPDATE_INTERVAL
	var direction := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if direction.length_squared() <= 0.001:
		direction = Vector2(1.0, 0.0)
	direction = direction.normalized()
	var speed := OBJECT_BASE_SPEED + randf_range(-OBJECT_SPEED_VARIANCE, OBJECT_SPEED_VARIANCE)
	_object_velocity = direction * maxf(speed, 50.0)


func _clamp_to_field(position: Vector2) -> Vector2:
	var max_x := maxf(game_field.size.x - object_marker.size.x, 0.0)
	var max_y := maxf(game_field.size.y - object_marker.size.y, 0.0)
	return Vector2(
		clampf(position.x, 0.0, max_x),
		clampf(position.y, 0.0, max_y)
	)


func _resolve_player_id() -> int:
	if player != null and player.player_id >= 0:
		return player.player_id
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_ui()
		get_viewport().set_input_as_handled()
