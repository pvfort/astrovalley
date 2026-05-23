class_name TaskBoardComponent
extends InteractableComponent

const TASK_BOARD_PRIORITY := 20

@export var task_board_ui_path: NodePath


func _ready() -> void:
    priority = max(priority, TASK_BOARD_PRIORITY)


func can_interact(_player: PlayerCharacter) -> bool:
    var task_board_ui := _find_task_board_ui()
    if task_board_ui == null:
        return false
    if task_board_ui.has_method("is_open"):
        return not task_board_ui.is_open()
    return true


func interact(_player: PlayerCharacter) -> void:
    var task_board_ui := _find_task_board_ui()
    if task_board_ui == null:
        return

    if task_board_ui.has_method("open_board"):
        task_board_ui.open_board()


func _find_task_board_ui() -> Node:
    var scene_root := get_tree().current_scene
    if scene_root == null:
        return null

    if not task_board_ui_path.is_empty():
        var ui_from_path := get_node_or_null(task_board_ui_path)
        if ui_from_path != null:
            return ui_from_path

    return scene_root.find_child("TaskBoardUI", true, false)
