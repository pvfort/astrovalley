extends CharacterBody2D

@export var tile_size: int = 32
@export var move_speed: float = 200.0

@onready var sprite = $AnimatedSprite2D

var current_level: int = 0

var is_moving: bool = false
var target_position: Vector2
var input_direction: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.DOWN


func _ready():
	add_to_group("player")


func _physics_process(delta):
	if is_moving:
		move_towards_target(delta)
		return

	handle_input()


# --------------------------------------------------
# INPUT
# --------------------------------------------------
func handle_input():
	var dir = get_input_direction()

	if dir == Vector2.ZERO:
		play_idle()
		return

	if not can_move(dir):
		play_idle()
		return

	start_move(dir)

func get_input_direction() -> Vector2:
	var dir = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down")  - Input.get_action_strength("ui_up")
	)

	if abs(dir.x) > 0:
		dir.y = 0
	elif abs(dir.y) > 0:
		dir.x = 0

	return dir
# --------------------------------------------------
# MOVEMENT
# --------------------------------------------------
func start_move(dir: Vector2):
	is_moving = true
	input_direction = dir
	last_direction = dir

	target_position = global_position + dir * tile_size

	play_walk(dir)


func move_towards_target(delta):
	var to_target = target_position - global_position
	var direction = to_target.normalized()

	velocity = direction * move_speed
	move_and_slide()

	# --- FAIL SAFE: if velocity is near zero, we hit something ---
	if velocity.length() < 1.0:
		is_moving = false
		velocity = Vector2.ZERO
		play_idle()
		return

	if to_target.length() < 2.0:
		global_position = target_position
		velocity = Vector2.ZERO
		is_moving = false

		var dir = get_input_direction()

		if dir == Vector2.ZERO or not can_move(dir):
			play_idle()
		else:
			start_move(dir)



func can_move(dir: Vector2) -> bool:
	var space = get_world_2d().direct_space_state

	var from = global_position
	var to = global_position + dir * tile_size

	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space.intersect_ray(query)

	return result.is_empty()

# --------------------------------------------------
# ANIMATION
# --------------------------------------------------
func play_walk(dir: Vector2):
	if dir == Vector2.RIGHT:
		sprite.play("walk_right")
	elif dir == Vector2.LEFT:
		sprite.play("walk_left")
	elif dir == Vector2.UP:
		sprite.play("walk_up")
	elif dir == Vector2.DOWN:
		sprite.play("walk_down")


func play_idle():
	sprite.play("idle")


# --------------------------------------------------
# LEVEL SWITCHING (CRITICAL FOR STAIRS)
# --------------------------------------------------
func set_level(lvl: int):
	current_level = lvl

	var main = get_tree().get_first_node_in_group("main_room")
	if main:
		main.set_current_level(lvl)
