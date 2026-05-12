class_name ConsumableComponent
extends Node

@export var stamina_restore: float = 20.0
@export var duration: float = 10.0

func consume(player: PlayerCharacter) -> void:
	var status = player.get_node_or_null("StatusEffectComponent")
	if status == null:
		return

	status.apply_effect("energy_boost", {
		"stamina_restore": stamina_restore,
		"duration": duration
	})
