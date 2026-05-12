class_name StatusEffectComponent
extends Node

var active_effects = {}

func apply(effect_id: String, duration: float) -> void:
	print("[STATUS] applied:", effect_id, " duration:", duration)
	active_effects[effect_id] = duration
