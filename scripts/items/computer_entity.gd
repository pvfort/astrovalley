extends Area2D
class_name ComputerEntity

@export var computer_ui_path: NodePath


func interact(player: PlayerCharacter) -> void:
	print("Computer interacted")
	var ui := get_node_or_null(computer_ui_path)

	if ui == null:
		push_error("Computer UI not found")
		return

	if ui.has_method("open"):
		ui.open()
