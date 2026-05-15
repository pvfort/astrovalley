extends Control

@export var mug_item: ItemData = preload("res://resources/items/mug.tres")
@export var mug_price: int = 25
@export var coffee_item: ItemData = preload("res://resources/items/coffee.tres")
@export var coffee_price: int = 40

@onready var funds_label: Label = $Panel/MarginContainer/VBoxContainer/FundsLabel
@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var buy_mug_button: Button = $Panel/MarginContainer/VBoxContainer/BuyMugButton
@onready var buy_coffee_button: Button = $Panel/MarginContainer/VBoxContainer/BuyCoffeeButton
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/CloseButton

func _ready() -> void:
	visible = false

	buy_mug_button.pressed.connect(_on_buy_mug_pressed)
	buy_coffee_button.pressed.connect(_on_buy_coffee_pressed)
	close_button.pressed.connect(close_store)

	_refresh_funds()
	_set_status("")

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close_store()
		get_viewport().set_input_as_handled()

func open_store() -> void:
	visible = true
	_refresh_funds()
	_set_status("Welcome!")

func close_store() -> void:
	visible = false
	_set_status("")

func _on_buy_mug_pressed() -> void:
	_purchase_item(mug_item, mug_price)

func _on_buy_coffee_pressed() -> void:
	_purchase_item(coffee_item, coffee_price)

func _purchase_item(item: ItemData, cost: int) -> void:
	if InventoryManager == null:
		_set_status("Store unavailable.")
		return

	if item == null:
		_set_status("Item missing.")
		return

	if cost < 0:
		_set_status("Invalid item price.")
		return

	if InventoryManager.funds < cost:
		_set_status("Not enough funds.")
		return

	if not _has_free_inventory_slot():
		_set_status("Inventory is full.")
		return

	if InventoryManager.purchase_item(item, cost):
		_set_status("Purchased %s for $%d." % [item.display_name, cost])
	else:
		_set_status("Purchase failed.")

	_refresh_funds()

func _refresh_funds() -> void:
	if InventoryManager == null:
		funds_label.text = "Funds: $0"
		return

	funds_label.text = "Funds: $%d" % InventoryManager.funds

func _set_status(message: String) -> void:
	status_label.text = message

func _has_free_inventory_slot() -> bool:
	for slot in InventoryManager.inventory:
		if slot == null:
			return true

	return false
