class_name ItemDatabase
extends Node

var items: Dictionary = {}

func get_item(id: String) -> ItemData:
	return items.get(id)
