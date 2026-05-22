class_name CraftingManager
extends Node

signal recipe_completed(recipe: RecipeData)

static func can_craft(recipe: RecipeData, inventory) -> bool:
	if recipe == null or inventory == null:
		return false

	for ingredient in recipe.ingredients:
		if ingredient == null:
			return false
		if not inventory.has_method("count_item"):
			return false
		if inventory.count_item(ingredient.item_id) < ingredient.quantity:
			return false

	return true


static func consume_ingredients(recipe: RecipeData, inventory) -> bool:
	if recipe == null or inventory == null:
		return false

	for ingredient in recipe.ingredients:
		if ingredient == null:
			return false
		if not inventory.has_method("remove_items_by_id"):
			return false
		if not inventory.remove_items_by_id(ingredient.item_id, ingredient.quantity):
			return false

	return true


static func complete_recipe(recipe: RecipeData, inventory) -> bool:
	if recipe == null or inventory == null:
		return false

	for output in recipe.outputs:
		if output == null:
			return false
		if not inventory.has_method("try_insert_item_id"):
			return false
		var remaining: int = inventory.try_insert_item_id(output.item_id, output.quantity)
		if remaining > 0:
			return false

	return true
