class_name CraftingStationComponent
extends Node

@export var station_tags: Array[String] = []
@export var available_recipes: Array[RecipeData] = []

var active_jobs: Array[CraftingJob] = []


func _ready() -> void:
	set_process(true)


func can_use_recipe(recipe: RecipeData) -> bool:

	for required_tag in recipe.required_station_tags:

		if !station_tags.has(required_tag):
			return false

	return true


func start_recipe(recipe: RecipeData, inventory) -> bool:

	if !can_use_recipe(recipe):
		return false

	if !CraftingManager.can_craft(recipe, inventory):
		return false

	CraftingManager.consume_ingredients(
		recipe,
		inventory
	)

	if recipe.craft_time <= 0.0:

		CraftingManager.complete_recipe(
			recipe,
			inventory
		)

	else:

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

	CraftingManager.complete_recipe(
		job.recipe,
		job.inventory
	)

	active_jobs.erase(job)
