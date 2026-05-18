class_name ToolData
extends Resource

@export var tool_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export var rarity: StringName = &"common"

@export var max_durability: float = 100.0
@export var durability_loss_per_use: float = 1.0

@export var energy_cost_per_use: float = 0.0
@export var cooldown_seconds: float = 0.0
@export var use_animation: StringName = &""

@export var skill_id: String = ""
@export var skill_scaling: Dictionary = {}

@export var interaction_modifiers: Dictionary = {}

@export var upgrade_ids: Array[String] = []
@export var module_slots: int = 0
@export var supported_modules: Array[StringName] = []

@export var battery_capacity: float = 0.0
@export var battery_drain_per_use: float = 0.0

@export var active_ability_id: StringName = &""
@export var active_ability_cooldown: float = 0.0
@export var contextual_interactions: Dictionary = {}

func get_context_modifiers(context: StringName) -> Dictionary:
	var context_key := String(context)
	var modifiers := interaction_modifiers.get(context_key, {})
	if modifiers is Dictionary:
		return modifiers as Dictionary
	return {}

func get_modifier(context: StringName, key: StringName, default_value: float = 1.0) -> float:
	var context_modifiers := get_context_modifiers(context)
	return float(context_modifiers.get(String(key), default_value))

func get_skill_scale(key: StringName, default_value: float = 0.0) -> float:
	return float(skill_scaling.get(String(key), default_value))
