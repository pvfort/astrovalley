class_name ItemData
extends Resource

@export var item_id: String
@export var display_name: String
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var stack_size: int = 1
@export var tags: Array[String] = []

@export var consumable: bool = false

@export var status_effect_id: String = ""
@export var status_effect_duration: float = 0.0

@export var replacement_item: ItemData

# Legacy placement fields retained for compatibility with existing systems/resources.
@export var placeable: bool = false
@export var placed_scene: PackedScene
@export var placement_size: Vector2i = Vector2i.ONE
@export var furniture_category: String = ""

# Preferred extensible placement fields for build mode and future placeable systems.
@export var placeable_scene: PackedScene
@export var placeable_category: String = ""
@export var footprint_size: Vector2i = Vector2i.ONE
@export var placement_offset: Vector2 = Vector2.ZERO


func get_active_placeable_scene() -> PackedScene:
	if placeable_scene != null:
		return placeable_scene
	return placed_scene


func get_active_footprint_size() -> Vector2i:
	if footprint_size != Vector2i.ZERO:
		return Vector2i(max(footprint_size.x, 1), max(footprint_size.y, 1))
	return Vector2i(max(placement_size.x, 1), max(placement_size.y, 1))
