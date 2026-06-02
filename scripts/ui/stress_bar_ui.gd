extends Control

const FILL_MARGIN := 2.0
const LERP_SPEED := 8.0

const COLOR_FULL := Color(0.25, 0.85, 0.45, 1.0)
const COLOR_MID := Color(0.95, 0.78, 0.15, 1.0)
const COLOR_LOW := Color(0.88, 0.24, 0.24, 1.0)

@onready var _fill: Panel = $Fill
@onready var _label: Label = $Label

var _player_id: int = -1
var _current_stress: float = 100.0
var _max_stress: float = 100.0
var _display_ratio: float = 1.0


func _ready() -> void:
	if StressManager == null:
		return
	StressManager.stress_changed.connect(_on_stress_changed)
	call_deferred("_bind_to_owning_player")


func _bind_to_owning_player() -> void:
	var player_node: Node = null

	var canvas_layer: Node = get_parent()
	if canvas_layer != null:
		var candidate: Node = canvas_layer.get_parent()
		if candidate is PlayerCharacter:
			player_node = candidate

	if player_node == null:
		for p in get_tree().get_nodes_in_group("player"):
			if p is PlayerCharacter and (p as PlayerCharacter).is_multiplayer_authority():
				player_node = p
				break

	if not (player_node is PlayerCharacter):
		visible = false
		return

	var player: PlayerCharacter = player_node as PlayerCharacter
	if not player.is_multiplayer_authority():
		visible = false
		return

	_player_id = player.player_id if player.player_id >= 0 else int(multiplayer.get_unique_id())

	if StressManager != null:
		if not StressManager.has_player(_player_id):
			StressManager.register_player(_player_id)
		_current_stress = StressManager.get_current_stress(_player_id)
		_max_stress = StressManager.get_max_stress(_player_id)
		_display_ratio = _current_stress / maxf(1.0, _max_stress)

	_update_fill_immediate()


func _on_stress_changed(pid: int, current: float, max_value: float) -> void:
	if pid != _player_id:
		return
	_current_stress = current
	_max_stress = max_value


func _process(delta: float) -> void:
	if _player_id < 0:
		return
	var target_ratio := _current_stress / maxf(1.0, _max_stress)
	_display_ratio = lerpf(_display_ratio, target_ratio, LERP_SPEED * delta)
	if absf(_display_ratio - target_ratio) < 0.001:
		_display_ratio = target_ratio
	_update_fill()
	_update_label()


func _update_fill_immediate() -> void:
	_display_ratio = _current_stress / maxf(1.0, _max_stress)
	_update_fill()
	_update_label()


func _update_fill() -> void:
	var bar_width := size.x - FILL_MARGIN * 2.0
	var fill_width := maxf(0.0, bar_width * _display_ratio)
	_fill.offset_right = FILL_MARGIN + fill_width
	_update_fill_color()


func _update_fill_color() -> void:
	var style := _fill.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	var ratio := clampf(_display_ratio, 0.0, 1.0)
	var color: Color
	if ratio >= 0.6:
		color = COLOR_FULL.lerp(COLOR_MID, (1.0 - ratio) / 0.4)
	elif ratio >= 0.2:
		color = COLOR_MID.lerp(COLOR_LOW, (0.6 - ratio) / 0.4)
	else:
		color = COLOR_LOW
	style.bg_color = color


func _update_label() -> void:
	_label.text = "S %d / %d" % [int(_current_stress), int(_max_stress)]
