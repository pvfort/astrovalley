extends Node

# NetworkManager: Handles multiplayer setup and connections
# Autoload singleton

signal player_connected(id: int)
signal player_disconnected(id: int)
signal game_state_synced(state: Dictionary)
signal chat_message_received(player_id: int, player_name: String, message: String)

var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var is_host: bool = false
const CHAT_MAX_LENGTH := 200

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)

func host_game(port: int = 4242) -> bool:
	print("[NetworkManager] Attempting to host on port:", port)

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port)

	if error != OK:
		print("[NetworkManager] Failed to host. ENet error code:", error)
		return false

	multiplayer.multiplayer_peer = peer
	is_host = true

	print("[NetworkManager] Hosting game on port", port)

	# Start world systems AFTER networking is valid
	if TimeManager != null:
		TimeManager.start_cycle()

	# Register host player
	var my_id := multiplayer.get_unique_id()
	GameManager.add_player(my_id, "Player" + str(my_id))

	return true

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
			"local_player_id": id,
		}
		print("[NetworkManager] Syncing state to peer ", id, " existing_players=", existing_players, " local_player_id=", id)
		rpc_id(id, "sync_game_state", state)

func _on_player_disconnected(id: int):
	player_disconnected.emit(id)
	print("Player disconnected: ", id)
	if multiplayer.is_server():
		GameManager.remove_player(id)

func send_chat_message(raw_message: String) -> void:
	var message := _sanitize_chat_message(raw_message)
	if message.is_empty():
		return

	if not multiplayer.has_multiplayer_peer():
		var local_id := multiplayer.get_unique_id()
		var local_name := _resolve_player_name(local_id)
		chat_message_received.emit(local_id, local_name, message)
		return

	if multiplayer.is_server():
		_broadcast_chat_message(multiplayer.get_unique_id(), message)
		return

	rpc_id(1, "server_submit_chat_message", message)

@rpc("any_peer", "reliable")
func server_submit_chat_message(message: String) -> void:
	if not multiplayer.is_server():
		return

	var sanitized := _sanitize_chat_message(message)
	if sanitized.is_empty():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return

	_broadcast_chat_message(sender_id, sanitized)

@rpc("authority", "reliable")
func receive_chat_message(player_id: int, player_name: String, message: String) -> void:
	chat_message_received.emit(player_id, player_name, message)

func _broadcast_chat_message(player_id: int, message: String) -> void:
	var player_name := _resolve_player_name(player_id)
	receive_chat_message(player_id, player_name, message)
	rpc("receive_chat_message", player_id, player_name, message)

func _resolve_player_name(player_id: int) -> String:
	if GameManager == null:
		return "Player%s" % str(player_id)
	if not GameManager.has_method("get_player_state"):
		return "Player%s" % str(player_id)
	var state: Dictionary = GameManager.get_player_state(player_id)
	var player_name := str(state.get("name", ""))
	if player_name.is_empty():
		return "Player%s" % str(player_id)
	return player_name

func _sanitize_chat_message(raw_message: String) -> String:
	var normalized := raw_message.replace("\n", " ").replace("\r", " ").strip_edges()
	if normalized.length() > CHAT_MAX_LENGTH:
		normalized = normalized.substr(0, CHAT_MAX_LENGTH)
	return normalized

# Server authoritative functions
@rpc("authority")
func sync_game_state(state: Dictionary):
	# Apply the current time phase received from the server
	TimeManager.sync_phase(state["phase"])
	# Notify listeners (e.g. main.gd) to spawn already-connected players
	game_state_synced.emit(state)
