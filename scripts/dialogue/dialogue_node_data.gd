extends Resource
class_name DialogueNodeData

@export var node_id: String = ""
@export var speaker_name: String = ""
@export_multiline var line_text: String = ""
@export var next_node_id: String = ""
@export var choices: Array[DialogueChoiceData] = []
