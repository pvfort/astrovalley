extends Area2D
class_name Interactable

signal interaction_available_changed(is_available: bool)

# Shared priorities let the player interaction resolver stay generic.
const PRIORITY_NPC: int = 100
const PRIORITY_ITEM: int = 200
const PRIORITY_DOOR: int = 300

@export var interaction_name: StringName = &"Interact"
@export var interaction_priority: int = 0
@export var interaction_enabled: bool = true : set = set_interaction_enabled

func _ready() -> void:
    monitoring = true
    monitorable = true

func set_interaction_enabled(value: bool) -> void:
    if interaction_enabled == value:
        return
    interaction_enabled = value
    interaction_available_changed.emit(interaction_enabled)

func can_interact(_player: Node) -> bool:
    return interaction_enabled

func interact(_player: Node) -> void:
    push_warning("Interact called on base Interactable: %s" % name)
