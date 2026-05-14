extends Node

signal skill_xp_changed(skill_id, xp)
signal skill_level_changed(skill_id, level)

var skills := {}


func _ready():
	var programming = preload(
		"res://resources/skills/programming_skill.tres"
	)

	register_skill(programming)


func register_skill(skill: SkillData) -> void:
	skills[skill.skill_id] = {
		"data": skill,
		"xp": 0,
		"level": 0
	}


func add_xp(skill_id: String, amount: int) -> void:
	if not skills.has(skill_id):
		print("[SKILL] unknown skill:", skill_id)
		return

	var entry = skills[skill_id]
	entry["xp"] += amount

	skill_xp_changed.emit(
		skill_id,
		entry["xp"]
	)

	_check_level_up(skill_id)


func _check_level_up(skill_id: String) -> void:
	var entry = skills[skill_id]
	var skill: SkillData = entry["data"]
	var xp: int = entry["xp"]
	var level: int = entry["level"]

	while level < skill.max_level:
		if level >= skill.xp_curve.size():
			break

		var required_xp = skill.xp_curve[level]

		if xp < required_xp:
			break

		level += 1
		entry["level"] = level

		print(
			"[SKILL] LEVEL UP:",
			skill.display_name,
			" -> ",
			level
		)

		skill_level_changed.emit(skill_id, level)


func get_level(skill_id: String) -> int:
	if not skills.has(skill_id):
		return 0

	return skills[skill_id]["level"]


func get_xp(skill_id: String) -> int:
	if not skills.has(skill_id):
		return 0

	return skills[skill_id]["xp"]
