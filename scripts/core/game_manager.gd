extends Node

# GameManager: Manages overall game state

var players: Dictionary = {}  # id -> player_data
var resources: Dictionary = {}  # resource_name -> {locked: bool, by: int}

func _ready():
	# Initialize resources
	resources["telescope"] = {"locked": false, "by": -1}

func add_player(id: int, name: String):
	players[id] = {"name": name, "current_task": ""}

func remove_player(id: int):
	players.erase(id)

func is_resource_available(resource: String) -> bool:
	if resources.has(resource):
		return not resources[resource]["locked"]
	return false

func lock_resource(resource: String, player_id: int) -> bool:
	if is_resource_available(resource):
		resources[resource]["locked"] = true
		resources[resource]["by"] = player_id
		return true
	return false

func unlock_resource(resource: String):
	if resources.has(resource):
		resources[resource]["locked"] = false
		resources[resource]["by"] = -1

func get_resource_holder(resource: String) -> int:
	if resources.has(resource) and resources[resource]["locked"]:
		return resources[resource]["by"]
	return -1