extends Resource
class_name SkillData

@export var skill_id: String
@export var display_name: String
@export var description: String
@export var icon: Texture2D

@export var max_level: int = 10

@export var xp_curve: Array[int] = [
	100,
	250,
	500,
	900,
	1400,
	2000,
	2700,
	3500,
	4500,
	6000
]
