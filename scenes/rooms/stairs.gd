extends Node2D

@onready var area = $StairArea

# configured externally (or via scene)
var from_level: int = 0
var to_level: int = 1

var target_position: Vector2i = Vector2i.ZERO


func _ready():
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body):
	print("STAIR TRIGGERED", body)
	# Optional safety check (only react to player)
	if not body.is_in_group("player"):
		return

	var main = get_tree().get_first_node_in_group("main_room")
	if main == null:
		push_warning("No main_room found for stair transition")
		return

	# Trigger level switch
	main.change_level(to_level, target_position)
