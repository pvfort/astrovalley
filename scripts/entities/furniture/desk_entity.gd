class_name DeskEntity
extends Node2D

@export var grid_size: int = 32


func _ready() -> void:
	snap_to_grid()


func snap_to_grid() -> void:
	global_position = Vector2(
		round(global_position.x / float(grid_size)) * float(grid_size),
		round(global_position.y / float(grid_size)) * float(grid_size)
	)
