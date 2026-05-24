class_name QuestNpcComponent
extends DialogueComponent

const QUEST_NPC_PRIORITY := 30

@export var npc_id: String = ""
@export var npc_name: String = "Professor"
@export var npc_role: String = "professor"
@export_multiline var dialogue_line: String = ""
@export var homework_item_id: String = "homework_copies"
@export var homework_delivery_amount: int = 1


func _ready() -> void:
	super._ready()
	priority = max(priority, QUEST_NPC_PRIORITY)
	if dialogue_data == null:
		dialogue_data = _build_default_dialogue()


func _on_dialogue_completed(player: PlayerCharacter) -> void:
	if player == null:
		return

	if EventBus != null and EventBus.has_signal("npc_talked_to"):
		EventBus.npc_talked_to.emit(player.player_id, npc_id)

	if npc_role != "student":
		return

	if InventoryManager == null:
		return

	var deliver_amount := maxi(1, homework_delivery_amount)
	if InventoryManager.count_item(homework_item_id) < deliver_amount:
		return

	if InventoryManager.remove_items_by_id(homework_item_id, deliver_amount):
		if EventBus != null and EventBus.has_signal("homework_delivered"):
			EventBus.homework_delivered.emit(player.player_id, npc_id, deliver_amount)


func _build_default_dialogue() -> DialogueData:
	var generated := DialogueData.new()
	var node := DialogueNodeData.new()
	node.node_id = "start"
	node.speaker_name = npc_name

	var fallback_line := "Let's keep your work progressing today."
	if npc_role == "student":
		fallback_line = "Hi! If you have printed homework copies, I can take one."
	elif npc_role == "it":
		fallback_line = "Complete my onboarding tasks and I'll unlock cluster access."
	node.line_text = dialogue_line if not dialogue_line.is_empty() else fallback_line

	generated.start_node_id = node.node_id
	generated.nodes = [node]
	return generated
