extends Node

signal player_profile_changed

@export var player_name: String = "Avery Vega":
	set(value):
		player_name = value
		player_profile_changed.emit()

@export var player_title: String = "Graduate Researcher":
	set(value):
		player_title = value
		player_profile_changed.emit()

@export var player_level: int = 1:
	set(value):
		player_level = max(value, 1)
		player_profile_changed.emit()

@export var portrait: Texture2D = preload("res://assets/entities/characters/character.png"):
	set(value):
		portrait = value
		player_profile_changed.emit()
