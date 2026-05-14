class_name StatusEffectComponent
extends Node

var active_effects = {}

func apply(effect_id: String, duration: float) -> void:
	print("[STATUS] applied:", effect_id, " duration:", duration)
	active_effects[effect_id] = duration


func has_effect(effect_id: String) -> bool:

	return active_effects.has(effect_id)

func _process(delta: float) -> void:

	var expired := []

	for effect_id in active_effects.keys():

		active_effects[effect_id] -= delta

		if active_effects[effect_id] <= 0.0:
			expired.append(effect_id)

	for effect_id in expired:

		print("[STATUS] expired:", effect_id)

		active_effects.erase(effect_id)
