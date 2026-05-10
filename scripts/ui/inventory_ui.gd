extends Control

@export var inventory_slot_scene: PackedScene = preload("res://scenes/ui/InventorySlot.tscn")
@export var equipment_slot_scene: PackedScene = preload("res://scenes/ui/EquipmentSlot.tscn")

@onready var inventory_tab_button: Button = $MarginContainer/Layout/TopBarPanel/MarginContainer/TopBar/InventoryTabButton
@onready var player_name_label: Label = $MarginContainer/Layout/TopBarPanel/MarginContainer/TopBar/PlayerName
@onready var player_portrait: TextureRect = $MarginContainer/Layout/TopBarPanel/MarginContainer/TopBar/PlayerPortrait
@onready var level_title_label: Label = $MarginContainer/Layout/TopBarPanel/MarginContainer/TopBar/LevelTitle
@onready var funds_label: Label = $MarginContainer/Layout/TopBarPanel/MarginContainer/TopBar/FundsLabel
@onready var thesis_button: Button = $MarginContainer/Layout/TopBarPanel/MarginContainer/TopBar/ThesisButton
@onready var sort_button: Button = $MarginContainer/Layout/TopBarPanel/MarginContainer/TopBar/SortButton
@onready var close_button: Button = $MarginContainer/Layout/TopBarPanel/MarginContainer/TopBar/CloseButton

@onready var main_inventory_panel: PanelContainer = $MarginContainer/Layout/MainInventoryPanel
@onready var inventory_grid: GridContainer = $MarginContainer/Layout/MainInventoryPanel/MarginContainer/MainRow/RightColumn/InventoryPanel/MarginContainer/InventoryGrid
@onready var equipment_grid: GridContainer = $MarginContainer/Layout/MainInventoryPanel/MarginContainer/MainRow/LeftColumn/EquipmentPanel/MarginContainer/EquipmentGrid

func _ready() -> void:
    _build_inventory_grid()
    _build_equipment_grid()
    _bind_signals()
    _refresh_player_profile()
    _refresh_inventory()
    _refresh_funds(InventoryManager.funds)
    _set_inventory_open(InventoryManager.inventory_open)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("inventory_toggle"):
        InventoryManager.toggle_inventory()
        get_viewport().set_input_as_handled()

func _bind_signals() -> void:
    inventory_tab_button.pressed.connect(func() -> void: InventoryManager.toggle_inventory())
    close_button.pressed.connect(func() -> void: InventoryManager.set_inventory_open(false))
    sort_button.pressed.connect(_on_sort_pressed)
    thesis_button.pressed.connect(_on_thesis_pressed)

    InventoryManager.inventory_open_changed.connect(_set_inventory_open)
    InventoryManager.inventory_changed.connect(_refresh_inventory)
    InventoryManager.funds_changed.connect(_refresh_funds)
    if PlayerData != null:
        PlayerData.player_profile_changed.connect(_refresh_player_profile)

func _build_inventory_grid() -> void:
    if inventory_grid.get_child_count() > 0:
        return

    for _i in range(InventoryManager.INVENTORY_SIZE):
        inventory_grid.add_child(inventory_slot_scene.instantiate())

func _build_equipment_grid() -> void:
    if equipment_grid.get_child_count() > 0:
        return

    for slot_name in InventoryManager.EQUIPMENT_SLOT_ORDER:
        var slot = equipment_slot_scene.instantiate()
        slot.slot_type = slot_name
        equipment_grid.add_child(slot)

func _refresh_player_profile() -> void:
    if PlayerData == null:
        return
    player_name_label.text = PlayerData.player_name
    player_portrait.texture = PlayerData.portrait
    level_title_label.text = "Lv.%d %s" % [PlayerData.player_level, PlayerData.player_title]
    level_title_label.tooltip_text = "%s\nLevel %d" % [PlayerData.player_title, PlayerData.player_level]

func _refresh_inventory() -> void:
    for i in range(inventory_grid.get_child_count()):
        var slot = inventory_grid.get_child(i)
        if slot.has_method("set_slot_data"):
            slot.set_slot_data(InventoryManager.get_inventory_slot(i))

    for i in range(equipment_grid.get_child_count()):
        var slot = equipment_grid.get_child(i)
        if slot.has_method("set_slot_data"):
            var key: StringName = slot.slot_type
            slot.set_slot_data(InventoryManager.equipped.get(key))

func _refresh_funds(value: int) -> void:
    funds_label.text = "Funds: $%d" % value

func _set_inventory_open(is_open: bool) -> void:
    main_inventory_panel.visible = is_open
    sort_button.disabled = not is_open
    close_button.disabled = not is_open

func _on_sort_pressed() -> void:
    InventoryManager.sort_inventory()

func _on_thesis_pressed() -> void:
    print("[Thesis] Open progression view (placeholder)")
