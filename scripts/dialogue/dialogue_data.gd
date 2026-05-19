extends Resource
class_name DialogueData

@export var start_node_id: String = ""
@export var nodes: Array[DialogueNodeData] = []


func get_start_node_id() -> String:
	if not start_node_id.is_empty():
		return start_node_id

	for node in nodes:
		if node != null and not node.node_id.is_empty():
			return node.node_id

	return ""


func get_node(node_id: String) -> DialogueNodeData:
	if node_id.is_empty():
		return null

	for node in nodes:
		if node != null and node.node_id == node_id:
			return node

	return null
