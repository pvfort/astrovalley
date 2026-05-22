class_name CraftingUI
extends Control

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var recipe_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Content/RecipeColumn/RecipeListScroll/RecipeList
@onready var recipe_name_label: Label = $Panel/MarginContainer/VBoxContainer/Content/DetailsColumn/RecipeName
@onready var ingredient_list: ItemList = $Panel/MarginContainer/VBoxContainer/Content/DetailsColumn/IngredientList
@onready var output_list: ItemList = $Panel/MarginContainer/VBoxContainer/Content/DetailsColumn/OutputList
@onready var craft_time_label: Label = $Panel/MarginContainer/VBoxContainer/Content/DetailsColumn/CraftTimeLabel
@onready var active_jobs_list: ItemList = $Panel/MarginContainer/VBoxContainer/ActiveJobsList
@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var craft_button: Button = $Panel/MarginContainer/VBoxContainer/Buttons/CraftButton
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/Buttons/CloseButton

var station: CraftingStationComponent
var inventory
var selected_recipe: RecipeData


func _ready() -> void:
	add_to_group("crafting_ui")
	visible = false
	craft_button.pressed.connect(_on_craft_button_pressed)
	close_button.pressed.connect(close_ui)
	if InventoryManager != null and not InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
	_clear_details()


func open_for_station(target_station, player_inventory) -> void:
	if not (target_station is CraftingStationComponent):
		return

	_disconnect_station()
	station = target_station as CraftingStationComponent
	inventory = player_inventory
	selected_recipe = null
	visible = true
	title_label.text = "Crafting: %s" % station.station_id.replace("_", " ").capitalize()
	status_label.text = ""

	if InventoryManager != null:
		InventoryManager.set_inventory_open(true)

	if not station.crafting_completed.is_connected(_on_station_crafting_completed):
		station.crafting_completed.connect(_on_station_crafting_completed)
	if not station.crafting_failed.is_connected(_on_station_crafting_failed):
		station.crafting_failed.connect(_on_station_crafting_failed)
	if not station.crafting_started.is_connected(_on_station_crafting_started):
		station.crafting_started.connect(_on_station_crafting_started)

	_populate_recipe_list()
	_refresh_active_jobs()


func close_ui() -> void:
	visible = false
	selected_recipe = null
	_clear_details()
	_disconnect_station()
	if InventoryManager != null:
		InventoryManager.set_inventory_open(false)


func _populate_recipe_list() -> void:
	for child in recipe_list.get_children():
		child.queue_free()

	if station == null:
		return

	for recipe in station.available_recipes:
		var button := Button.new()
		button.text = recipe.display_name
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void: _select_recipe(recipe))
		recipe_list.add_child(button)

	if station.available_recipes.is_empty():
		status_label.text = "No recipes available."
	elif station.available_recipes[0] != null:
		_select_recipe(station.available_recipes[0])


func _select_recipe(recipe: RecipeData) -> void:
	selected_recipe = recipe
	_refresh_details()


func _refresh_details() -> void:
	if selected_recipe == null:
		_clear_details()
		return

	recipe_name_label.text = selected_recipe.display_name
	ingredient_list.clear()
	output_list.clear()

	for ingredient in selected_recipe.ingredients:
		if ingredient == null:
			continue
		var owned :float= inventory.count_item(ingredient.item_id) if inventory != null and inventory.has_method("count_item") else 0
		ingredient_list.add_item("%s x%d (have %d)" % [ingredient.item_id, ingredient.quantity, owned])

	for output in selected_recipe.outputs:
		if output == null:
			continue
		output_list.add_item("%s x%d" % [output.item_id, output.quantity])

	craft_time_label.text = "Craft time: %.1fs" % selected_recipe.craft_time
	craft_button.disabled = station == null or inventory == null or not CraftingManager.can_craft(selected_recipe, inventory)


func _refresh_active_jobs() -> void:
	active_jobs_list.clear()
	if station == null:
		return

	for summary in station.get_active_job_summaries():
		active_jobs_list.add_item(summary)


func _clear_details() -> void:
	title_label.text = "Crafting"
	recipe_name_label.text = "Select a recipe"
	ingredient_list.clear()
	output_list.clear()
	craft_time_label.text = "Craft time: --"
	active_jobs_list.clear()
	status_label.text = ""
	craft_button.disabled = true


func _on_craft_button_pressed() -> void:
	if station == null or selected_recipe == null:
		return

	if station.start_recipe(selected_recipe, inventory):
		status_label.text = "Started %s." % selected_recipe.display_name
	_refresh_details()
	_refresh_active_jobs()


func _on_station_crafting_started(recipe_id: String) -> void:
	if selected_recipe != null and selected_recipe.id == recipe_id:
		status_label.text = "Started %s." % selected_recipe.display_name
	_refresh_active_jobs()


func _on_station_crafting_completed(recipe_id: String) -> void:
	var recipe_name := recipe_id
	if station != null:
		for recipe in station.available_recipes:
			if recipe != null and recipe.id == recipe_id:
				recipe_name = recipe.display_name
				break
	status_label.text = "Completed %s." % recipe_name
	_refresh_details()
	_refresh_active_jobs()


func _on_station_crafting_failed(message: String) -> void:
	status_label.text = message
	_refresh_details()
	_refresh_active_jobs()


func _on_inventory_changed() -> void:
	if not visible:
		return
	_refresh_details()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_ui()
		get_viewport().set_input_as_handled()


func _disconnect_station() -> void:
	if station == null:
		return
	if station.crafting_completed.is_connected(_on_station_crafting_completed):
		station.crafting_completed.disconnect(_on_station_crafting_completed)
	if station.crafting_failed.is_connected(_on_station_crafting_failed):
		station.crafting_failed.disconnect(_on_station_crafting_failed)
	if station.crafting_started.is_connected(_on_station_crafting_started):
		station.crafting_started.disconnect(_on_station_crafting_started)
	station = null
