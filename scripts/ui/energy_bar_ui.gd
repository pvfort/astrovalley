extends Control

const FILL_MARGIN := 2.0
const LERP_SPEED := 8.0

const COLOR_FULL := Color(0.2, 0.85, 0.35, 1.0)
const COLOR_MID := Color(0.95, 0.75, 0.1, 1.0)
const COLOR_LOW := Color(0.9, 0.2, 0.15, 1.0)
const COLOR_EXHAUSTED := Color(0.55, 0.1, 0.45, 1.0)

@onready var _fill: Panel = $Fill
@onready var _label: Label = $Label

var _player_id: int = -1
var _current_energy: float = 100.0
var _max_energy: float = 100.0
var _display_ratio: float = 1.0
var _exhausted: bool = false


func _ready() -> void:
	if EnergyManager == null:
		return
	EnergyManager.energy_changed.connect(_on_energy_changed)
	EnergyManager.exhaustion_changed.connect(_on_exhaustion_changed)
	call_deferred("_bind_to_owning_player")


func _bind_to_owning_player() -> void:
	var player_node: Node = null

	var canvas_layer := get_parent()
	if canvas_layer != null:
		var candidate := canvas_layer.get_parent()
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

	var player := player_node as PlayerCharacter
	if not player.is_multiplayer_authority():
		visible = false
		return

	_player_id = player.player_id if player.player_id >= 0 else int(multiplayer.get_unique_id())

	if EnergyManager != null:
		if not EnergyManager.has_player(_player_id):
			EnergyManager.register_player(_player_id)
		_current_energy = EnergyManager.get_current_energy(_player_id)
		_max_energy = EnergyManager.get_max_energy(_player_id)
		_exhausted = EnergyManager.is_exhausted(_player_id)
		_display_ratio = _current_energy / maxf(1.0, _max_energy)

	_update_fill_immediate()


func _on_energy_changed(pid: int, current: float, max_e: float) -> void:
	if pid != _player_id:
		return
	_current_energy = current
	_max_energy = max_e


func _on_exhaustion_changed(pid: int, exhausted: bool) -> void:
	if pid != _player_id:
		return
	_exhausted = exhausted
	_update_fill_color()


func _process(delta: float) -> void:
	if _player_id < 0:
		return
	var target_ratio := _current_energy / maxf(1.0, _max_energy)
	_display_ratio = lerpf(_display_ratio, target_ratio, LERP_SPEED * delta)
	if absf(_display_ratio - target_ratio) < 0.001:
		_display_ratio = target_ratio
	_update_fill()
	_update_label()


func _update_fill_immediate() -> void:
	_display_ratio = _current_energy / maxf(1.0, _max_energy)
	_update_fill()
	_update_fill_color()
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
	if _exhausted:
		style.bg_color = COLOR_EXHAUSTED
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
	_label.text = "E %d / %d" % [int(_current_energy), int(_max_energy)]
	if _exhausted:
		_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.9))
	else:
		_label.remove_theme_color_override("font_color")
