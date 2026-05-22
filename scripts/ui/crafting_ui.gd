class_name CraftingUI
extends Control

var station: CraftingStationComponent
var inventory

var selected_recipe: RecipeData
func open_for_station(
	target_station,
	player_inventory
):

	station = target_station
	inventory = player_inventory

	populate_recipe_list()
	
func populate_recipe_list():

	for recipe in station.available_recipes:

		var button := Button.new()

		button.text = recipe.display_name

		button.pressed.connect(
			func():
				select_recipe(recipe)
		)

		$RecipeList.add_child(button)
		
func select_recipe(recipe: RecipeData):

	selected_recipe = recipe

	$RecipeDetails/RecipeName.text = recipe.display_name

func _on_craft_button_pressed():

	if selected_recipe == null:
		return

	station.start_recipe(
		selected_recipe,
		inventory
	)
