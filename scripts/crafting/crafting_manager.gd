class_name CraftingManager
extends Node

signal recipe_completed(recipe: RecipeData)

func can_craft(recipe: RecipeData, inventory) -> bool:

	for ingredient in recipe.ingredients:

		if !inventory.has_item(
			ingredient.item_id,
			ingredient.quantity
		):
			return false

	return true


func consume_ingredients(recipe: RecipeData, inventory) -> void:

	for ingredient in recipe.ingredients:

		inventory.remove_item(
			ingredient.item_id,
			ingredient.quantity
		)


func complete_recipe(recipe: RecipeData, inventory) -> void:

	for output in recipe.outputs:

		inventory.add_item(
			output.item_id,
			output.quantity
		)

	recipe_completed.emit(recipe)
