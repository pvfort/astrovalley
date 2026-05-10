extends Resource
class_name ItemData

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export_enum("consumable", "tool", "research", "equipment", "key_item", "misc") var item_category: String = "misc"
@export_multiline var description: String
@export_range(1, 999, 1) var max_stack_size: int = 99
