class_name ProgrammingComponent
extends Node

@export var xp_gain: int = 15
@export var stamina_cost: float = 5.0
@export var allowed_mode := PlayerCharacter.InteractionMode.PRIMARY
@export var priority: int = 10


func interact(_player) -> void:
	print("[PROGRAMMING] coding...")

	SkillManager.add_xp(
		"programming",
		xp_gain
	)
