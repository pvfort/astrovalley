class_name ProgrammingComponent
extends InteractableComponent

signal programming_started(player_id: int)
signal programming_completed(player_id: int)

const PROGRAMMING_PRIORITY := 10

@export var skill_id: String = "programming"
@export var xp_gain: int = 15
@export var time_advance_minutes: int = 45
@export var consume_energy: bool = true
@export var energy_cost: float = 12.0
@export var active_texture: Texture2D = preload("res://assets/entities/furniture/computer_on.png")
@export var sprite_path: NodePath = NodePath("Sprite2D")

var _original_texture: Texture2D
var _is_interacting := false

func _ready() -> void:
	priority = max(priority, PROGRAMMING_PRIORITY)

func interact(player: PlayerCharacter) -> void:
	if player == null or _is_interacting:
		return

	_is_interacting = true
	programming_started.emit(player.player_id)
	_set_computer_visual(true)

	var actual_xp := xp_gain
	var action_delay := 0.2
	if EnergyManager != null:
		var pid := _resolve_player_energy_id(player)
		if pid >= 0:
			actual_xp = int(float(xp_gain) * EnergyManager.get_xp_gain_multiplier(pid))
			action_delay /= maxf(0.1, EnergyManager.get_action_speed_multiplier(pid))

	if skill_id != "":
		SkillManager.add_xp(skill_id, actual_xp)
		WorldClock.add_daily_skill_xp(skill_id, actual_xp)

	WorldClock.add_minutes(time_advance_minutes)
	WorldClock.add_programming_progress(time_advance_minutes)
	_attempt_energy_spend(player)

	var tween := get_tree().root.create_tween()
	tween.tween_interval(action_delay)
	tween.finished.connect(
		func() -> void:
			if is_inside_tree():
				_set_computer_visual(false)
				programming_completed.emit(player.player_id)

			_is_interacting = false,
		CONNECT_ONE_SHOT
	)

func _resolve_player_energy_id(player: PlayerCharacter) -> int:
	if player.player_id >= 0:
		return player.player_id
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return -1

func _attempt_energy_spend(player: PlayerCharacter) -> void:
	if not consume_energy:
		return

	if player.has_method("consume_energy"):
		player.consume_energy(energy_cost)
		return

	var status := player.get_status_effect_component()
	if status != null and status.has_method("apply"):
		status.apply("programming_fatigue", energy_cost, {"temporary": true, "source": "programming"})

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


func save_state() -> Dictionary:
	return {
		"is_interacting": _is_interacting,
	}


func load_state(data: Dictionary) -> void:
	_is_interacting = bool(data.get("is_interacting", false))
	_set_computer_visual(_is_interacting)
