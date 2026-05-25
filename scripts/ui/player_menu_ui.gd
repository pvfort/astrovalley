class_name PlayerMenuUI
extends Control

const STATIONLESS_RECIPES: Array[RecipeData] = [
	preload("res://resources/recipes/prepare_homework_recipe.tres"),
]
const INVENTORY_SLOT_SCENE := preload("res://scenes/ui/InventorySlot.tscn")

@onready var tab_container: TabContainer = $Panel/MarginContainer/VBoxContainer/TabContainer
@onready var inventory_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/InventoryScroll/InventoryGrid
@onready var funds_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/FundsLabel
@onready var skills_list: ItemList = $Panel/MarginContainer/VBoxContainer/TabContainer/SkillsTab/SkillsList
@onready var crafting_list: ItemList = $Panel/MarginContainer/VBoxContainer/TabContainer/CraftingTab/CraftingList
@onready var craft_requirements: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/CraftingTab/CraftingRequirements
@onready var crafting_status: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/CraftingTab/CraftingStatus
@onready var craft_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/CraftingTab/CraftingButtons/CraftButton
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/Buttons/CloseButton

var _selected_recipe: RecipeData = null


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close_menu)
	craft_button.pressed.connect(_on_craft_pressed)
	crafting_list.item_selected.connect(_on_recipe_selected)
	if InventoryManager != null:
		InventoryManager.inventory_changed.connect(_refresh_inventory_tab)
	if SkillManager != null:
		SkillManager.skill_xp_changed.connect(_refresh_skills_tab)
		SkillManager.skill_level_changed.connect(_refresh_skills_tab)
	_build_inventory_grid()
	_populate_crafting_list()
	_refresh_all_tabs()


func is_open() -> bool:
	return visible


func toggle_menu() -> void:
	if visible:
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	visible = true
	_refresh_all_tabs()
	if InventoryManager != null:
		InventoryManager.set_inventory_open(true)


func close_menu() -> void:
	visible = false
	if InventoryManager != null:
		InventoryManager.set_inventory_open(false)


func _refresh_all_tabs() -> void:
	_refresh_inventory_tab()
	_refresh_skills_tab()
	_refresh_crafting_details()


func _refresh_inventory_tab() -> void:
	if InventoryManager == null:
		funds_label.text = "Funds: --"
		return

	_build_inventory_grid()
	funds_label.text = "Funds: $%d" % int(InventoryManager.funds)
	for slot_index in range(inventory_grid.get_child_count()):
		var slot_node: Node = inventory_grid.get_child(slot_index)
		if slot_node.has_method("set_slot_data"):
			slot_node.call("set_slot_data", InventoryManager.get_inventory_slot(slot_index))


func _build_inventory_grid() -> void:
	if InventoryManager == null:
		return
	if inventory_grid.get_child_count() == InventoryManager.get_inventory_size():
		return

	for child in inventory_grid.get_children():
		child.queue_free()

	for slot_index in range(InventoryManager.get_inventory_size()):
		var slot_node: Node = INVENTORY_SLOT_SCENE.instantiate()
		slot_node.set("slot_index", slot_index)
		if slot_node.has_signal("slot_transfer_requested"):
			var transfer_callable := Callable(self, "_on_inventory_slot_transfer_requested")
			if not slot_node.is_connected("slot_transfer_requested", transfer_callable):
				slot_node.connect("slot_transfer_requested", transfer_callable)
		inventory_grid.add_child(slot_node)


func _on_inventory_slot_transfer_requested(from_index: int, to_index: int) -> void:
	if InventoryManager == null:
		return
	InventoryManager.move_inventory_slot(from_index, to_index)


func _refresh_skills_tab(_a = null, _b = null) -> void:
	skills_list.clear()
	if SkillManager == null:
		return

	for skill_id_variant in SkillManager.skills.keys():
		var skill_id := str(skill_id_variant)
		var skill_entry_variant: Variant = SkillManager.skills.get(skill_id, {})
		if not (skill_entry_variant is Dictionary):
			continue
		var skill_entry := skill_entry_variant as Dictionary
		var data_variant: Variant = skill_entry.get("data", null)
		var display_name := skill_id.capitalize()
		if data_variant != null and "display_name" in data_variant:
			display_name = str(data_variant.display_name)
		var level := int(skill_entry.get("level", 0))
		var xp := int(skill_entry.get("xp", 0))
		skills_list.add_item("%s · Lv %d · XP %d" % [display_name, level, xp])


func _populate_crafting_list() -> void:
	crafting_list.clear()
	for recipe in STATIONLESS_RECIPES:
		if recipe == null:
			continue
		crafting_list.add_item(recipe.display_name)

	if crafting_list.item_count > 0:
		crafting_list.select(0)
		_selected_recipe = STATIONLESS_RECIPES[0]
	else:
		_selected_recipe = null


func _on_recipe_selected(index: int) -> void:
	if index < 0 or index >= STATIONLESS_RECIPES.size():
		_selected_recipe = null
	else:
		_selected_recipe = STATIONLESS_RECIPES[index]
	_refresh_crafting_details()


func _refresh_crafting_details() -> void:
	if _selected_recipe == null:
		craft_requirements.text = "Select a recipe."
		craft_button.disabled = true
		return

	var lines: Array[String] = []
	for ingredient in _selected_recipe.ingredients:
		if ingredient == null:
			continue
		var have := InventoryManager.count_item(ingredient.item_id) if InventoryManager != null else 0
		lines.append("%s x%d (have %d)" % [ingredient.item_id.replace("_", " "), ingredient.quantity, have])
	craft_requirements.text = "\n".join(lines)
	craft_button.disabled = InventoryManager == null or not CraftingManager.can_craft(_selected_recipe, InventoryManager)


func _on_craft_pressed() -> void:
	if _selected_recipe == null or InventoryManager == null:
		return
	if not CraftingManager.can_craft(_selected_recipe, InventoryManager):
		crafting_status.text = "Missing ingredients."
		return
	if not CraftingManager.consume_ingredients(_selected_recipe, InventoryManager):
		crafting_status.text = "Could not consume ingredients."
		return
	if not CraftingManager.complete_recipe(_selected_recipe, InventoryManager):
		crafting_status.text = "Inventory is full."
		return
	crafting_status.text = "Crafted %s." % _selected_recipe.display_name
	_refresh_inventory_tab()
	_refresh_crafting_details()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
