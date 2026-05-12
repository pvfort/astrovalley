class_name ItemData
extends Resource

@export var item_id: String
@export var display_name: String
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var stack_size: int = 1
@export var tags: Array[String] = []
