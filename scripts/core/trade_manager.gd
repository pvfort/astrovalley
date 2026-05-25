extends Node

signal trade_started(partner_id: int, partner_name: String)
signal trade_state_changed
signal trade_closed(reason: String)
signal trade_completed(partner_id: int, partner_name: String)
signal trade_error(message: String)

var _active_trade_id: int = -1
var _active_partner_id: int = -1
var _active_partner_name: String = ""
var _local_offer: Dictionary = {}
var _partner_offer: Dictionary = {}
var _local_accepted: bool = false
var _partner_accepted: bool = false

var _server_next_trade_id: int = 1
var _server_trades: Dictionary = {}


func _ready() -> void:
	if multiplayer != null and not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func is_trade_active() -> bool:
	return _active_trade_id >= 0


func get_partner_id() -> int:
	return _active_partner_id


func get_partner_name() -> String:
	return _active_partner_name


func get_local_offer() -> Dictionary:
	return _local_offer.duplicate(true)


func get_partner_offer() -> Dictionary:
	return _partner_offer.duplicate(true)


func is_local_accepted() -> bool:
	return _local_accepted


func is_partner_accepted() -> bool:
	return _partner_accepted


func request_trade_with(target_player_id: int) -> bool:
	if target_player_id <= 0:
		_emit_trade_error("Invalid trade target.")
		return false

	var local_id := _local_player_id()
	if target_player_id == local_id:
		_emit_trade_error("You cannot trade with yourself.")
		return false

	if is_trade_active():
		_emit_trade_error("Finish the current trade first.")
		return false

	if not _is_multiplayer_active():
		_emit_trade_error("Trading requires multiplayer.")
		return false

	if multiplayer.is_server():
		_server_create_trade(local_id, target_player_id)
	else:
		rpc_id(1, "server_request_trade", target_player_id)

	return true


func update_local_offer(next_offer: Dictionary) -> void:
	if not is_trade_active():
		return

	var sanitized := _sanitize_offer(next_offer)
	if multiplayer.is_server():
		_server_apply_offer(_active_trade_id, _local_player_id(), sanitized)
		return

	if _is_multiplayer_active():
		rpc_id(1, "server_update_trade_offer", _active_trade_id, sanitized)


func set_local_accept(accepted: bool) -> void:
	if not is_trade_active():
		return

	if multiplayer.is_server():
		_server_set_acceptance(_active_trade_id, _local_player_id(), accepted)
		return

	if _is_multiplayer_active():
		rpc_id(1, "server_set_trade_acceptance", _active_trade_id, accepted)


func cancel_active_trade() -> void:
	if not is_trade_active():
		return

	if multiplayer.is_server():
		_server_cancel_trade(_active_trade_id, "Trade cancelled.")
		return

	if _is_multiplayer_active():
		rpc_id(1, "server_cancel_trade", _active_trade_id)


@rpc("any_peer", "reliable")
func server_request_trade(target_player_id: int) -> void:
	if not multiplayer.is_server():
		return
	var requester_id := multiplayer.get_remote_sender_id()
	_server_create_trade(requester_id, target_player_id)


@rpc("any_peer", "reliable")
func server_update_trade_offer(trade_id: int, offer: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_server_apply_offer(trade_id, sender_id, _sanitize_offer(offer))


@rpc("any_peer", "reliable")
func server_set_trade_acceptance(trade_id: int, accepted: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_server_set_acceptance(trade_id, sender_id, accepted)


@rpc("any_peer", "reliable")
func server_cancel_trade(trade_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var trade := _get_server_trade(trade_id)
	if trade.is_empty():
		return
	var players: Array = trade.get("players", [])
	if not players.has(sender_id):
		return
	_server_cancel_trade(trade_id, "Trade cancelled.")


@rpc("authority", "reliable")
func client_trade_started(trade_id: int, partner_id: int, partner_name: String) -> void:
	_active_trade_id = trade_id
	_active_partner_id = partner_id
	_active_partner_name = partner_name
	_local_offer = {}
	_partner_offer = {}
	_local_accepted = false
	_partner_accepted = false
	trade_started.emit(_active_partner_id, _active_partner_name)
	trade_state_changed.emit()


@rpc("authority", "reliable")
func client_trade_state(trade_id: int, offers: Dictionary, accepted_by: Dictionary) -> void:
	if trade_id != _active_trade_id:
		return

	var local_id := _local_player_id()
	_local_offer = _sanitize_offer(_dictionary(offers.get(local_id, {})))
	_partner_offer = _sanitize_offer(_dictionary(offers.get(_active_partner_id, {})))
	_local_accepted = bool(accepted_by.get(local_id, false))
	_partner_accepted = bool(accepted_by.get(_active_partner_id, false))
	trade_state_changed.emit()


@rpc("authority", "reliable")
func client_trade_cancelled(trade_id: int, reason: String) -> void:
	if trade_id != _active_trade_id:
		return
	_clear_local_trade(reason)


@rpc("authority", "reliable")
func client_trade_finalized(
	trade_id: int,
	partner_id: int,
	partner_name: String,
	give_offer: Dictionary,
	receive_offer: Dictionary
) -> void:
	if trade_id != _active_trade_id:
		return

	var success := _apply_trade_exchange(give_offer, receive_offer)
	if not success:
		_emit_trade_error("Trade completed, but inventory exchange failed locally.")

	_clear_local_trade("Trade complete.")
	trade_completed.emit(partner_id, partner_name)


func _server_create_trade(requester_id: int, target_id: int) -> void:
	if requester_id <= 0 or target_id <= 0:
		_server_send_error(requester_id, "Invalid trade request.")
		return
	if requester_id == target_id:
		_server_send_error(requester_id, "You cannot trade with yourself.")
		return
	if not _is_player_connected(target_id):
		_server_send_error(requester_id, "Target player is unavailable.")
		return
	if _find_server_trade_for_player(requester_id) >= 0:
		_server_send_error(requester_id, "You are already trading.")
		return
	if _find_server_trade_for_player(target_id) >= 0:
		_server_send_error(requester_id, "Target player is already trading.")
		return

	var trade_id := _server_next_trade_id
	_server_next_trade_id += 1

	var offers: Dictionary = {
		requester_id: {},
		target_id: {},
	}
	var accepted_by: Dictionary = {
		requester_id: false,
		target_id: false,
	}

	_server_trades[trade_id] = {
		"players": [requester_id, target_id],
		"offers": offers,
		"accepted_by": accepted_by,
	}

	_send_to_player(
		requester_id,
		"client_trade_started",
		[trade_id, target_id, _resolve_player_name(target_id)]
	)
	_send_to_player(
		target_id,
		"client_trade_started",
		[trade_id, requester_id, _resolve_player_name(requester_id)]
	)
	_server_broadcast_trade_state(trade_id)


func _server_apply_offer(trade_id: int, player_id: int, offer: Dictionary) -> void:
	var trade := _get_server_trade(trade_id)
	if trade.is_empty():
		return

	var players: Array = trade.get("players", [])
	if not players.has(player_id):
		return

	var offers: Dictionary = _dictionary(trade.get("offers", {}))
	offers[player_id] = offer
	trade["offers"] = offers

	var accepted_by: Dictionary = _dictionary(trade.get("accepted_by", {}))
	for player_id_variant in players:
		accepted_by[int(player_id_variant)] = false
	trade["accepted_by"] = accepted_by

	_server_trades[trade_id] = trade
	_server_broadcast_trade_state(trade_id)


func _server_set_acceptance(trade_id: int, player_id: int, accepted: bool) -> void:
	var trade := _get_server_trade(trade_id)
	if trade.is_empty():
		return

	var players: Array = trade.get("players", [])
	if not players.has(player_id):
		return

	var accepted_by: Dictionary = _dictionary(trade.get("accepted_by", {}))
	accepted_by[player_id] = accepted
	trade["accepted_by"] = accepted_by
	_server_trades[trade_id] = trade

	_server_broadcast_trade_state(trade_id)

	if not accepted:
		return

	var all_accepted := true
	for player_id_variant in players:
		var pid := int(player_id_variant)
		if not bool(accepted_by.get(pid, false)):
			all_accepted = false
			break

	if all_accepted:
		_server_finalize_trade(trade_id)


func _server_finalize_trade(trade_id: int) -> void:
	var trade := _get_server_trade(trade_id)
	if trade.is_empty():
		return

	var players: Array = trade.get("players", [])
	if players.size() != 2:
		_server_cancel_trade(trade_id, "Trade failed.")
		return

	var offers: Dictionary = _dictionary(trade.get("offers", {}))
	var player_a := int(players[0])
	var player_b := int(players[1])
	var offer_a := _sanitize_offer(_dictionary(offers.get(player_a, {})))
	var offer_b := _sanitize_offer(_dictionary(offers.get(player_b, {})))

	_send_to_player(
		player_a,
		"client_trade_finalized",
		[trade_id, player_b, _resolve_player_name(player_b), offer_a, offer_b]
	)
	_send_to_player(
		player_b,
		"client_trade_finalized",
		[trade_id, player_a, _resolve_player_name(player_a), offer_b, offer_a]
	)

	_server_trades.erase(trade_id)


func _server_broadcast_trade_state(trade_id: int) -> void:
	var trade := _get_server_trade(trade_id)
	if trade.is_empty():
		return

	var players: Array = trade.get("players", [])
	var offers: Dictionary = _dictionary(trade.get("offers", {}))
	var accepted_by: Dictionary = _dictionary(trade.get("accepted_by", {}))

	for player_id_variant in players:
		var player_id := int(player_id_variant)
		_send_to_player(
			player_id,
			"client_trade_state",
			[trade_id, offers, accepted_by]
		)


func _server_cancel_trade(trade_id: int, reason: String) -> void:
	var trade := _get_server_trade(trade_id)
	if trade.is_empty():
		return

	var players: Array = trade.get("players", [])
	for player_id_variant in players:
		var player_id := int(player_id_variant)
		_send_to_player(player_id, "client_trade_cancelled", [trade_id, reason])

	_server_trades.erase(trade_id)


func _apply_trade_exchange(give_offer: Dictionary, receive_offer: Dictionary) -> bool:
	if InventoryManager == null:
		return false

	var give := _sanitize_offer(give_offer)
	var receive := _sanitize_offer(receive_offer)

	if not _can_apply_trade_exchange(give, receive):
		return false

	for item_id_variant in give.keys():
		var item_id := str(item_id_variant)
		var required_count := int(give.get(item_id, 0))
		if InventoryManager.count_item(item_id) < required_count:
			return false

	for item_id_variant in give.keys():
		var item_id := str(item_id_variant)
		var remove_count := int(give.get(item_id, 0))
		if remove_count <= 0:
			continue
		var removed_all: bool = InventoryManager.remove_items_by_id(item_id, remove_count)
		if not removed_all:
			return false

	for item_id_variant in receive.keys():
		var item_id := str(item_id_variant)
		var add_count := int(receive.get(item_id, 0))
		if add_count <= 0:
			continue
		var remaining: int = InventoryManager.try_insert_item_id(item_id, add_count)
		if remaining > 0:
			return false

	return true


func _can_apply_trade_exchange(give: Dictionary, receive: Dictionary) -> bool:
	var working_inventory_variant: Variant = InventoryManager.get("inventory")
	if not (working_inventory_variant is Array):
		return true

	var simulated_inventory: Array = (working_inventory_variant as Array).duplicate(true)

	for item_id_variant in give.keys():
		var item_id := str(item_id_variant)
		var remove_count := int(give.get(item_id, 0))
		if remove_count <= 0:
			continue
		if not _simulate_remove(simulated_inventory, item_id, remove_count):
			return false

	for item_id_variant in receive.keys():
		var item_id := str(item_id_variant)
		var add_count := int(receive.get(item_id, 0))
		if add_count <= 0:
			continue
		if not _simulate_insert(simulated_inventory, item_id, add_count):
			return false

	return true


func _simulate_remove(simulated_inventory: Array, item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true

	var remaining := amount
	for slot_index in range(simulated_inventory.size()):
		if remaining <= 0:
			break

		var slot_variant: Variant = simulated_inventory[slot_index]
		if not (slot_variant is Dictionary):
			continue

		var slot_dict: Dictionary = slot_variant as Dictionary
		if _slot_item_id(slot_dict) != item_id:
			continue

		var current_count := max(int(slot_dict.get("count", 0)), 0)
		if current_count <= 0:
			simulated_inventory[slot_index] = null
			continue

		var remove_count := min(current_count, remaining)
		var next_count := current_count - remove_count
		if next_count <= 0:
			simulated_inventory[slot_index] = null
		else:
			slot_dict["count"] = next_count
			simulated_inventory[slot_index] = slot_dict

		remaining -= remove_count

	return remaining <= 0


func _simulate_insert(simulated_inventory: Array, item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true

	var item := _resolve_item_data(item_id)
	if item == null:
		return false

	var stack_limit := max(int(item.stack_size), 1)
	var remaining := amount

	for slot_index in range(simulated_inventory.size()):
		if remaining <= 0:
			break

		var slot_variant: Variant = simulated_inventory[slot_index]
		if not (slot_variant is Dictionary):
			continue

		var slot_dict: Dictionary = slot_variant as Dictionary
		if _slot_item_id(slot_dict) != item_id:
			continue

		var current_count := max(int(slot_dict.get("count", 0)), 0)
		if current_count >= stack_limit:
			continue

		var add_count := min(stack_limit - current_count, remaining)
		slot_dict["count"] = current_count + add_count
		simulated_inventory[slot_index] = slot_dict
		remaining -= add_count

	for slot_index in range(simulated_inventory.size()):
		if remaining <= 0:
			break

		if simulated_inventory[slot_index] != null:
			continue

		var add_count := min(stack_limit, remaining)
		simulated_inventory[slot_index] = {
			"item": item,
			"count": add_count,
		}
		remaining -= add_count

	return remaining <= 0


func _resolve_item_data(item_id: String) -> ItemData:
	if item_id.is_empty() or InventoryManager == null:
		return null

	if InventoryManager.has_method("_item_by_id"):
		var loaded: Variant = InventoryManager.call("_item_by_id", item_id)
		if loaded is ItemData:
			return loaded as ItemData

	return null


func _slot_item_id(slot_variant: Variant) -> String:
	if not (slot_variant is Dictionary):
		return ""

	var slot_dict: Dictionary = slot_variant as Dictionary
	var item_variant: Variant = slot_dict.get("item", null)
	if item_variant is ItemData:
		var item: ItemData = item_variant as ItemData
		return item.item_id
	return ""


func _clear_local_trade(reason: String) -> void:
	_active_trade_id = -1
	_active_partner_id = -1
	_active_partner_name = ""
	_local_offer = {}
	_partner_offer = {}
	_local_accepted = false
	_partner_accepted = false
	trade_closed.emit(reason)
	trade_state_changed.emit()


func _emit_trade_error(message: String) -> void:
	trade_error.emit(message)


func _server_send_error(player_id: int, message: String) -> void:
	_send_to_player(player_id, "client_trade_error", [message])


@rpc("authority", "reliable")
func client_trade_error(message: String) -> void:
	_emit_trade_error(message)


func _find_server_trade_for_player(player_id: int) -> int:
	for trade_id_variant in _server_trades.keys():
		var trade_id := int(trade_id_variant)
		var trade := _get_server_trade(trade_id)
		if trade.is_empty():
			continue
		var players: Array = trade.get("players", [])
		if players.has(player_id):
			return trade_id
	return -1


func _get_server_trade(trade_id: int) -> Dictionary:
	var trade_variant: Variant = _server_trades.get(trade_id, {})
	if trade_variant is Dictionary:
		return (trade_variant as Dictionary).duplicate(true)
	return {}


func _sanitize_offer(raw_offer: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for item_id_variant in raw_offer.keys():
		var item_id := str(item_id_variant).strip_edges()
		if item_id.is_empty():
			continue
		var count := max(int(raw_offer.get(item_id_variant, 0)), 0)
		if count <= 0:
			continue
		output[item_id] = count
	return output


func _dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _resolve_player_name(player_id: int) -> String:
	if GameManager == null or not GameManager.has_method("get_player_state"):
		return "Player%s" % str(player_id)
	var state: Dictionary = GameManager.get_player_state(player_id)
	var resolved := str(state.get("name", ""))
	if resolved.is_empty():
		return "Player%s" % str(player_id)
	return resolved


func _send_to_player(player_id: int, method: StringName, args: Array) -> void:
	if player_id <= 0:
		return
	if player_id == _local_player_id():
		callv(method, args)
		return
	match args.size():
		0:
			rpc_id(player_id, method)
		1:
			rpc_id(player_id, method, args[0])
		2:
			rpc_id(player_id, method, args[0], args[1])
		3:
			rpc_id(player_id, method, args[0], args[1], args[2])
		4:
			rpc_id(player_id, method, args[0], args[1], args[2], args[3])
		_:
			rpc_id(player_id, method, args[0], args[1], args[2], args[3], args[4])


func _local_player_id() -> int:
	return multiplayer.get_unique_id() if multiplayer != null else 1


func _is_player_connected(player_id: int) -> bool:
	if player_id == _local_player_id():
		return true
	if GameManager != null and (GameManager.players as Dictionary).has(player_id):
		return true
	return false


func _is_multiplayer_active() -> bool:
	return multiplayer != null and multiplayer.has_multiplayer_peer()


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var trade_id := _find_server_trade_for_player(peer_id)
	if trade_id >= 0:
		_server_cancel_trade(trade_id, "Trade cancelled (player disconnected).")
