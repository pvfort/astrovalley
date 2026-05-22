class_name RecipeData
extends Resource

@export var id: String
@export var display_name: String

@export var ingredients: Array[IngredientData]
@export var outputs: Array[IngredientData]

@export var craft_time: float = 0.0

@export var required_station_tags: Array[String] = []

@export var required_skill: String = ""
@export var required_level: int = 0

@export var unlock_conditions: Array[String] = []
