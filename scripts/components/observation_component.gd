class_name ObservationComponent
extends InteractableComponent

const OBSERVATION_PRIORITY := 20

@export var station_id: String = "telescope"

func _ready() -> void:
	priority = max(priority, OBSERVATION_PRIORITY)

func can_interact(player: PlayerCharacter) -> bool:
	if player == null:
		return false
	if TaskManager != null and TaskManager.has_method("get_active_task"):
		if TaskManager.get_active_task(player.player_id) != "":
			return false
	if GameManager != null and GameManager.has_method("get_observation_time"):
		return GameManager.get_observation_time(player.player_id) > 0
	return true

func interact(player: PlayerCharacter) -> void:
	if player == null:
		return

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		rpc_id(1, "request_start_observation", player.player_id)
		return

	_start_observation(player.player_id)

@rpc("any_peer", "reliable")
func request_start_observation(player_id: int) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != player_id:
		return
	_start_observation(player_id)

func _start_observation(player_id: int) -> void:
	if ObservationSystem == null or not ObservationSystem.has_method("start_observe"):
		return
	ObservationSystem.start_observe(player_id)
