class_name StoreNpcComponent
extends DialogueComponent

const STORE_NPC_PRIORITY := 30
@export var store_ui_path: NodePath

func _ready() -> void:
	super._ready()
	priority = max(priority, STORE_NPC_PRIORITY)

func _on_dialogue_completed(_player: PlayerCharacter) -> void:
	var store_ui := _find_store_ui()
	if store_ui == null:
		return

	if store_ui.has_method("open_store"):
		store_ui.open_store()

func _find_store_ui() -> Node:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null

	if not store_ui_path.is_empty():
		var store_ui_from_path: Node = get_node_or_null(store_ui_path)
		if store_ui_from_path != null:
			return store_ui_from_path

	return scene_root.find_child("StoreUI", true, false)
