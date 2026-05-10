extends CharacterBody2D
class_name PlayerCharacter

signal interaction_target_changed(interactable: Interactable)

@export var tile_size: int = 32
@export var move_speed: float = 200.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea

var current_level: int = 0
var is_moving: bool = false
var target_position: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.DOWN
var current_interactable: Interactable = null

func _ready() -> void:
    add_to_group("player")

func _physics_process(_delta: float) -> void:
    if is_moving:
        _move_towards_target()
    else:
        _handle_movement_input()

    _update_interaction_target()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact"):
        _handle_interaction_input()
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("inventory_toggle"):
        if InventoryManager != null:
            InventoryManager.toggle_inventory()
            get_viewport().set_input_as_handled()

func _handle_movement_input() -> void:
    var dir := _get_input_direction()
    if dir == Vector2.ZERO:
        _play_idle()
        return

    if not _can_move(dir):
        _play_idle()
        return

    _start_move(dir)

func _get_input_direction() -> Vector2:
    var dir := Vector2(
        Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
        Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
    )

    if absf(dir.x) > 0.0:
        dir.y = 0.0
    elif absf(dir.y) > 0.0:
        dir.x = 0.0

    return dir

func _start_move(dir: Vector2) -> void:
    is_moving = true
    last_direction = dir
    target_position = global_position + (dir * tile_size)
    _play_walk(dir)

func _move_towards_target() -> void:
    var to_target := target_position - global_position
    if to_target.length_squared() <= 4.0:
        global_position = target_position
        velocity = Vector2.ZERO
        is_moving = false
        var next_dir := _get_input_direction()
        if next_dir == Vector2.ZERO or not _can_move(next_dir):
            _play_idle()
        else:
            _start_move(next_dir)
        return

    velocity = to_target.normalized() * move_speed
    move_and_slide()

    if velocity.length() < 1.0:
        is_moving = false
        velocity = Vector2.ZERO
        _play_idle()

func _can_move(dir: Vector2) -> bool:
    var space := get_world_2d().direct_space_state
    var from := global_position
    var to := global_position + (dir * tile_size)

    var query := PhysicsRayQueryParameters2D.create(from, to)
    query.collide_with_areas = false
    query.collide_with_bodies = true
    query.exclude = [self]

    var result := space.intersect_ray(query)
    return result.is_empty()

func _play_walk(dir: Vector2) -> void:
    if dir == Vector2.RIGHT:
        sprite.play(&"walk_right")
    elif dir == Vector2.LEFT:
        sprite.play(&"walk_left")
    elif dir == Vector2.UP:
        sprite.play(&"walk_up")
    elif dir == Vector2.DOWN:
        sprite.play(&"walk_down")

func _play_idle() -> void:
    sprite.play(&"idle")

func _update_interaction_target() -> void:
    var nearest := _get_nearest_interactable()
    if nearest == current_interactable:
        return

    current_interactable = nearest
    interaction_target_changed.emit(current_interactable)

func _get_nearest_interactable() -> Interactable:
    if interaction_area == null:
        return null

    var overlapping := interaction_area.get_overlapping_areas()
    if overlapping.is_empty():
        return null

    var best: Interactable = null
    var best_priority: float = 0.0
    var best_distance: float = 0.0

    for area in overlapping:
        if not (area is Interactable):
            continue

        var interactable := area as Interactable
        if not interactable.can_interact(self):
            continue

        var priority := float(interactable.interaction_priority)
        var distance := global_position.distance_squared_to(interactable.global_position)

        if best == null:
            best = interactable
            best_priority = priority
            best_distance = distance
            continue

        if priority > best_priority or (priority == best_priority and distance < best_distance):
            best = interactable
            best_priority = priority
            best_distance = distance

    return best

func _handle_interaction_input() -> void:
    var interactable := current_interactable
    if interactable != null:
        interactable.interact(self)
        return

    if InventoryManager != null:
        InventoryManager.toggle_inventory()

func set_current_level(lvl: int) -> void:
    current_level = lvl
