extends Node

# NetworkManager: Handles multiplayer setup and connections
# Autoload singleton

signal player_connected(id: int)
signal player_disconnected(id: int)

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

func _on_player_disconnected(id: int):
	player_disconnected.emit(id)
	print("Player disconnected: ", id)
	if multiplayer.is_server():
		GameManager.remove_player(id)

# Server authoritative functions
@rpc("authority", "call_local")
func sync_game_state(state: Dictionary):
	# Sync game state from server
	pass  # Implement as needed