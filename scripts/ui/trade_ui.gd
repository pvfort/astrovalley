extends Control

@onready var trade_title_label: Label = $Panel/MarginContainer/VBoxContainer/TradeTitle
@onready var inventory_list: ItemList = $Panel/MarginContainer/VBoxContainer/Columns/InventoryColumn/InventoryList
@onready var offer_list: ItemList = $Panel/MarginContainer/VBoxContainer/Columns/OfferColumn/OfferList
@onready var partner_offer_list: ItemList = $Panel/MarginContainer/VBoxContainer/Columns/PartnerColumn/PartnerOfferList
@onready var amount_spinbox: SpinBox = $Panel/MarginContainer/VBoxContainer/ControlsRow/AmountSpinBox
@onready var add_offer_button: Button = $Panel/MarginContainer/VBoxContainer/ControlsRow/AddOfferButton
@onready var remove_offer_button: Button = $Panel/MarginContainer/VBoxContainer/ControlsRow/RemoveOfferButton
@onready var accept_button: Button = $Panel/MarginContainer/VBoxContainer/ActionRow/AcceptButton
@onready var cancel_button: Button = $Panel/MarginContainer/VBoxContainer/ActionRow/CancelButton
@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel

var _inventory_rows: Array[Dictionary] = []
var _offer_rows: Array[Dictionary] = []


func _ready() -> void:
	visible = false

	if not _is_local_player_ui():
		set_process_unhandled_input(false)
		return

	add_offer_button.pressed.connect(_on_add_offer_pressed)
	remove_offer_button.pressed.connect(_on_remove_offer_pressed)
	accept_button.pressed.connect(_on_accept_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

	if InventoryManager != null and not InventoryManager.inventory_changed.is_connected(_refresh_all):
		InventoryManager.inventory_changed.connect(_refresh_all)

	if TradeManager != null:
		if not TradeManager.trade_started.is_connected(_on_trade_started):
			TradeManager.trade_started.connect(_on_trade_started)
		if not TradeManager.trade_state_changed.is_connected(_on_trade_state_changed):
			TradeManager.trade_state_changed.connect(_on_trade_state_changed)
		if not TradeManager.trade_closed.is_connected(_on_trade_closed):
			TradeManager.trade_closed.connect(_on_trade_closed)
		if not TradeManager.trade_completed.is_connected(_on_trade_completed):
			TradeManager.trade_completed.connect(_on_trade_completed)
		if not TradeManager.trade_error.is_connected(_on_trade_error):
			TradeManager.trade_error.connect(_on_trade_error)

	_refresh_all()


func _exit_tree() -> void:
	if TradeManager != null:
		if TradeManager.trade_started.is_connected(_on_trade_started):
			TradeManager.trade_started.disconnect(_on_trade_started)
		if TradeManager.trade_state_changed.is_connected(_on_trade_state_changed):
			TradeManager.trade_state_changed.disconnect(_on_trade_state_changed)
		if TradeManager.trade_closed.is_connected(_on_trade_closed):
			TradeManager.trade_closed.disconnect(_on_trade_closed)
		if TradeManager.trade_completed.is_connected(_on_trade_completed):
			TradeManager.trade_completed.disconnect(_on_trade_completed)
		if TradeManager.trade_error.is_connected(_on_trade_error):
			TradeManager.trade_error.disconnect(_on_trade_error)

	if InventoryManager != null and InventoryManager.inventory_changed.is_connected(_refresh_all):
		InventoryManager.inventory_changed.disconnect(_refresh_all)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()


func _on_trade_started(_partner_id: int, partner_name: String) -> void:
	_open_trade_ui(partner_name)
	_refresh_all()
	_set_status("Trade started.")


func _on_trade_state_changed() -> void:
	if TradeManager == null or not TradeManager.is_trade_active():
		_close_trade_ui()
		return
	_refresh_all()


func _on_trade_closed(reason: String) -> void:
	_close_trade_ui()
	_set_status(reason)


func _on_trade_completed(_partner_id: int, partner_name: String) -> void:
	_close_trade_ui()
	_set_status("Trade with %s complete." % partner_name)


func _on_trade_error(message: String) -> void:
	_set_status(message)


func _on_add_offer_pressed() -> void:
	if TradeManager == null or not TradeManager.is_trade_active():
		return

	var selected := inventory_list.get_selected_items()
	if selected.is_empty():
		_set_status("Select an inventory item first.")
		return

	var inventory_index := int(selected[0])
	if inventory_index < 0 or inventory_index >= _inventory_rows.size():
		return

	var row: Dictionary = _inventory_rows[inventory_index]
	var item_id := str(row.get("item_id", ""))
	var available_count := int(row.get("count", 0))
	if item_id.is_empty() or available_count <= 0:
		return

	var next_offer := TradeManager.get_local_offer()
	var current_offered := int(next_offer.get(item_id, 0))
	var add_amount := max(int(amount_spinbox.value), 1)
	var max_total := max(available_count, 0)
	if current_offered >= max_total:
		_set_status("You are already offering all of this item.")
		return

	next_offer[item_id] = min(current_offered + add_amount, max_total)
	TradeManager.update_local_offer(next_offer)
	_set_status("Updated offer.")


func _on_remove_offer_pressed() -> void:
	if TradeManager == null or not TradeManager.is_trade_active():
		return

	var selected := offer_list.get_selected_items()
	if selected.is_empty():
		_set_status("Select an offered item first.")
		return

	var offer_index := int(selected[0])
	if offer_index < 0 or offer_index >= _offer_rows.size():
		return

	var row: Dictionary = _offer_rows[offer_index]
	var item_id := str(row.get("item_id", ""))
	if item_id.is_empty():
		return

	var remove_amount := max(int(amount_spinbox.value), 1)
	var next_offer := TradeManager.get_local_offer()
	var current := int(next_offer.get(item_id, 0))
	var next_count := current - remove_amount
	if next_count <= 0:
		next_offer.erase(item_id)
	else:
		next_offer[item_id] = next_count

	TradeManager.update_local_offer(next_offer)
	_set_status("Updated offer.")


func _on_accept_pressed() -> void:
	if TradeManager == null or not TradeManager.is_trade_active():
		return

	TradeManager.set_local_accept(not TradeManager.is_local_accepted())


func _on_cancel_pressed() -> void:
	if TradeManager == null or not TradeManager.is_trade_active():
		_close_trade_ui()
		return
	TradeManager.cancel_active_trade()


func _open_trade_ui(partner_name: String) -> void:
	visible = true
	trade_title_label.text = "Trade with %s" % partner_name
	add_to_group("movement_blocking_ui")
	if InventoryManager != null:
		InventoryManager.set_inventory_open(true)


func _close_trade_ui() -> void:
	visible = false
	remove_from_group("movement_blocking_ui")
	if InventoryManager != null:
		InventoryManager.set_inventory_open(false)


func _refresh_all() -> void:
	_refresh_inventory()
	_refresh_offers()
	_refresh_acceptance_status()


func _refresh_inventory() -> void:
	_inventory_rows.clear()
	inventory_list.clear()

	if InventoryManager == null:
		return

	var aggregated: Dictionary = {}
	for slot_index in range(InventoryManager.get_inventory_size()):
		var slot_data: Variant = InventoryManager.get_inventory_slot(slot_index)
		if not (slot_data is Dictionary):
			continue

		var slot_dict: Dictionary = slot_data as Dictionary
		var item_variant: Variant = slot_dict.get("item", null)
		if not (item_variant is ItemData):
			continue

		var item: ItemData = item_variant as ItemData
		var item_id := item.item_id
		if item_id.is_empty():
			continue
		var count := max(int(slot_dict.get("count", 0)), 0)
		if count <= 0:
			continue
		aggregated[item_id] = int(aggregated.get(item_id, 0)) + count

	for item_id_variant in aggregated.keys():
		var item_id := str(item_id_variant)
		_inventory_rows.append({
			"item_id": item_id,
			"count": int(aggregated.get(item_id, 0)),
			"name": _resolve_item_name(item_id),
		})

	_inventory_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")) < str(b.get("name", "")))

	for row in _inventory_rows:
		inventory_list.add_item("%s x%d" % [str(row.get("name", "")), int(row.get("count", 0))])


func _refresh_offers() -> void:
	offer_list.clear()
	partner_offer_list.clear()
	_offer_rows.clear()

	if TradeManager == null:
		return

	var local_offer := TradeManager.get_local_offer()
	var partner_offer := TradeManager.get_partner_offer()

	var local_item_ids: Array = local_offer.keys()
	local_item_ids.sort_custom(func(a, b): return str(a) < str(b))
	for item_id_variant in local_item_ids:
		var item_id := str(item_id_variant)
		var count := int(local_offer.get(item_id, 0))
		if count <= 0:
			continue
		_offer_rows.append({
			"item_id": item_id,
			"count": count,
			"name": _resolve_item_name(item_id),
		})

	for row in _offer_rows:
		offer_list.add_item("%s x%d" % [str(row.get("name", "")), int(row.get("count", 0))])

	var partner_item_ids: Array = partner_offer.keys()
	partner_item_ids.sort_custom(func(a, b): return str(a) < str(b))
	for item_id_variant in partner_item_ids:
		var item_id := str(item_id_variant)
		var count := int(partner_offer.get(item_id, 0))
		if count <= 0:
			continue
		partner_offer_list.add_item("%s x%d" % [_resolve_item_name(item_id), count])


func _refresh_acceptance_status() -> void:
	if TradeManager == null or not TradeManager.is_trade_active():
		accept_button.text = "Accept"
		return

	var my_status := "accepted" if TradeManager.is_local_accepted() else "pending"
	var partner_status := "accepted" if TradeManager.is_partner_accepted() else "pending"
	accept_button.text = "Unaccept" if TradeManager.is_local_accepted() else "Accept"
	status_label.text = "You: %s | Partner: %s" % [my_status, partner_status]


func _set_status(message: String) -> void:
	if message.is_empty():
		return
	status_label.text = message


func _resolve_item_name(item_id: String) -> String:
	if item_id.is_empty():
		return ""

	if InventoryManager != null and InventoryManager.has_method("_item_by_id"):
		var loaded_item: Variant = InventoryManager.call("_item_by_id", item_id)
		if loaded_item is ItemData:
			var item := loaded_item as ItemData
			if not item.display_name.is_empty():
				return item.display_name

	return item_id.replace("_", " ").capitalize()


func _is_local_player_ui() -> bool:
	var canvas_layer := get_parent()
	if canvas_layer == null:
		return true
	var player := canvas_layer.get_parent()
	if player is PlayerCharacter:
		return player.is_multiplayer_authority()
	return true
