class_name StatusEffectComponent
extends Node

signal effect_applied(effect_id: String)
signal effect_expired(effect_id: String)

var active_effects: Dictionary = {}

func apply(effect_id: String, duration: float, metadata: Dictionary = {}) -> void:
	if effect_id == "":
		return

	var entry := {
		"duration": maxf(duration, 0.0),
		"temporary": bool(metadata.get("temporary", true)),
		"metadata": metadata.duplicate(true),
	}
	active_effects[effect_id] = entry
	effect_applied.emit(effect_id)

func apply_effect(effect_id: String, effect_data: Dictionary) -> void:
	apply(effect_id, float(effect_data.get("duration", 0.0)), effect_data)

func has_effect(effect_id: String) -> bool:
	return active_effects.has(effect_id)

func clear_temporary_effects() -> void:
	var to_remove: Array[String] = []
	for effect_id in active_effects.keys():
		var entry := active_effects[effect_id] as Dictionary
		if bool(entry.get("temporary", false)):
			to_remove.append(effect_id)

	for effect_id in to_remove:
		active_effects.erase(effect_id)
		effect_expired.emit(effect_id)

func _process(delta: float) -> void:
	var expired: Array[String] = []

	for effect_id in active_effects.keys():
		var entry := active_effects[effect_id] as Dictionary
		entry["duration"] = maxf(0.0, float(entry.get("duration", 0.0)) - delta)
		active_effects[effect_id] = entry

		if float(entry["duration"]) <= 0.0:
			expired.append(effect_id)

	for effect_id in expired:
		active_effects.erase(effect_id)
		effect_expired.emit(effect_id)
