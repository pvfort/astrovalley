class_name BuildPreview
extends Node2D

const VALID_COLOR := Color(1.0, 1.0, 1.0, 0.6)
const INVALID_COLOR := Color(1.0, 0.35, 0.35, 0.75)

@export var grid_size: int = 32

var _placement_offset: Vector2 = Vector2.ZERO
var _preview_sprite: Sprite2D = null


func _ready() -> void:
	_preview_sprite = Sprite2D.new()
	_preview_sprite.modulate = VALID_COLOR
	add_child(_preview_sprite)


func configure(texture: Texture2D, placement_offset: Vector2 = Vector2.ZERO) -> void:
	_placement_offset = placement_offset
	if _preview_sprite == null:
		return
	_preview_sprite.texture = texture
	_preview_sprite.position = _placement_offset


func set_validity(is_valid: bool) -> void:
	if _preview_sprite == null:
		return
	_preview_sprite.modulate = VALID_COLOR if is_valid else INVALID_COLOR


func set_world_position(world_position: Vector2) -> void:
	global_position = get_snapped_position(world_position)


func get_snapped_position(world_position: Vector2) -> Vector2:
	return Vector2(
		round(world_position.x / float(grid_size)) * float(grid_size),
		round(world_position.y / float(grid_size)) * float(grid_size)
	)
