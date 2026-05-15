extends Resource
class_name CharacterProfile

@export var character_id: String = ""
@export var character_name: String = ""
@export var office_number: String = ""
@export var creation_date: String = ""

@export var inventory_data: Array = []
@export var equipped_data: Dictionary = {}
@export var skill_data: Dictionary = {}

@export var funds: int = 0
@export var world_time_stats: Dictionary = {}
@export var player_stats: Dictionary = {}
@export var current_level: int = 1
