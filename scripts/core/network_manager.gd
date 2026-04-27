extends Node

# NetworkManager: Handles multiplayer setup and connections
# Autoload singleton

signal player_connected(id: int)
signal player_disconnected(id: int)
signal game_state_synced(state: Dictionary)

var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var is_host: bool = false

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)

func host_game(port: int = 4242) -> bool:
	var error = peer.create_server(port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		is_host = true
		print("Hosting game on port ", port)
		TimeManager.start_cycle()
		# Register the server's own player so late-joiners can be told about it
		var my_id = multiplayer.get_unique_id()
		GameManager.add_player(my_id, "Player" + str(my_id))
		return true
	else:
		print("Failed to host: ", error)
		return false

func join_game(ip: String, port: int = 4242) -> bool:
	var error = peer.create_client(ip, port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		is_host = false
		print("Joining game at ", ip, ":", port)
		return true
	else:
		print("Failed to join: ", error)
		return false

func _on_player_connected(id: int):
	player_connected.emit(id)
	print("Player connected: ", id)
	if multiplayer.is_server():
		GameManager.add_player(id, "Player" + str(id))
		# Send current game state to the newly connected client so they can
		# spawn already-connected players and sync the time phase.
		var existing_players: Array = GameManager.players.keys().filter(
			func(pid: int) -> bool: return pid != id
		)
		var state := {
			"phase": TimeManager.current_phase,
			"players": existing_players,
		}
		rpc_id(id, "sync_game_state", state)

func _on_player_disconnected(id: int):
	player_disconnected.emit(id)
	print("Player disconnected: ", id)
	if multiplayer.is_server():
		GameManager.remove_player(id)

# Server authoritative functions
@rpc("authority")
func sync_game_state(state: Dictionary):
	# Apply the current time phase received from the server
	TimeManager.sync_phase(state["phase"])
	# Notify listeners (e.g. main.gd) to spawn already-connected players
	game_state_synced.emit(state)