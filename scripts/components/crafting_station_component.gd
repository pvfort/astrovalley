class_name CraftingStationComponent
extends InteractableComponent

signal crafting_started(recipe_id: String)
signal crafting_completed(recipe_id: String)
signal crafting_failed(message: String)

const CRAFTING_PRIORITY := 18

@export var station_id: String = "crafting_station"
@export var station_tags: Array[String] = []
@export var available_recipes: Array[RecipeData] = []

var active_jobs: Array[CraftingJob] = []


func _ready() -> void:
	priority = max(priority, CRAFTING_PRIORITY)
	set_process(true)
	available_recipes = _validated_recipes(available_recipes)


func can_use_recipe(recipe: RecipeData) -> bool:
	if recipe == null:
		return false

	for required_tag in recipe.required_station_tags:
		if not station_tags.has(required_tag):
			return false

	return true


func interact(player: PlayerCharacter) -> void:
	if player == null:
		return

	var ui := _resolve_crafting_ui()
	if ui == null:
		crafting_failed.emit("Crafting UI unavailable.")
		return

	if EventBus != null:
		EventBus.station_used.emit(player.player_id, station_id)

	if ui.has_method("open_for_station"):
		ui.open_for_station(self, InventoryManager)


func start_recipe(recipe: RecipeData, inventory) -> bool:
	if recipe == null:
		crafting_failed.emit("Recipe missing.")
		return false

	if not can_use_recipe(recipe):
		crafting_failed.emit("Wrong station.")
		return false

	if not CraftingManager.can_craft(recipe, inventory):
		crafting_failed.emit("Missing ingredients.")
		return false

	if not CraftingManager.consume_ingredients(recipe, inventory):
		crafting_failed.emit("Could not consume ingredients.")
		return false

	crafting_started.emit(recipe.id)

	if recipe.craft_time <= 0.0:
		if _complete_recipe(recipe, inventory):
			return true
		crafting_failed.emit("Could not add crafted item.")
		return false

	create_job(recipe, inventory)
	return true


func create_job(recipe: RecipeData, inventory) -> void:
	var job := CraftingJob.new()
	job.recipe = recipe
	job.remaining_time = recipe.craft_time
	job.inventory = inventory
	active_jobs.append(job)


func _process(delta: float) -> void:
	var completed_jobs: Array[CraftingJob] = []

	for job in active_jobs:
		job.remaining_time -= delta
		if job.remaining_time <= 0.0:
			completed_jobs.append(job)

	for job in completed_jobs:
		finish_job(job)


func finish_job(job: CraftingJob) -> void:
	active_jobs.erase(job)
	if job == null or job.recipe == null:
		return

	if not _complete_recipe(job.recipe, job.inventory):
		crafting_failed.emit("Could not add crafted item.")


func get_active_job_summaries() -> Array[String]:
	var summaries: Array[String] = []
	for job in active_jobs:
		if job == null or job.recipe == null:
			continue
		summaries.append("%s (%.1fs)" % [job.recipe.display_name, maxf(job.remaining_time, 0.0)])
	return summaries


func _complete_recipe(recipe: RecipeData, inventory) -> bool:
	var completed := CraftingManager.complete_recipe(recipe, inventory)
	if completed:
		crafting_completed.emit(recipe.id)
	return completed


func _resolve_crafting_ui() -> CraftingUI:
	var ui_nodes := get_tree().get_nodes_in_group("crafting_ui")
	if ui_nodes.is_empty():
		return null

	var ui := ui_nodes[0]
	if ui is CraftingUI:
		return ui as CraftingUI
	return null


func _validated_recipes(recipes: Array[RecipeData]) -> Array[RecipeData]:
	var valid_recipes: Array[RecipeData] = []
	for recipe in recipes:
		if recipe == null:
			push_warning("[CraftingStation] Skipping null recipe on %s." % station_id)
			continue
		if recipe.id.is_empty() or recipe.display_name.is_empty():
			push_warning("[CraftingStation] Skipping malformed recipe on %s." % station_id)
			continue
		if recipe.outputs.is_empty():
			push_warning("[CraftingStation] Recipe %s has no outputs." % recipe.id)
			continue
		valid_recipes.append(recipe)
	return valid_recipes
