extends CharacterBody2D
class_name PlayerCharacter

signal interaction_target_changed(interactable: Interactable)
signal hotbar_selection_changed(selected_slot: int)
signal equipped_item_changed(item: ItemData, selected_slot: int)

@export var tile_size: int = 32
@export var move_speed: float = 200.0

var player_id: int = -1
var current_level: int = 0

var is_moving: bool = false
var target_position: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.DOWN
var current_interactable: Node = null
var selected_hotbar_slot: int = 0
var equipped_item: ItemData = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var camera: Camera2D = $FollowCamera

enum InteractionMode {
	PRIMARY,
	PICKUP
}

func _ready() -> void:
	_ensure_hotbar_input_actions()

	add_to_group("player")

	print(
		name,
		" authority=",
		get_multiplayer_authority(),
		" local=",
		multiplayer.get_unique_id()
	)

	if is_multiplayer_authority():

		print("I am authority")

		if camera:
			camera.make_current()
		if InventoryManager != null:
			InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_update_equipped_item()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if InventoryManager != null and InventoryManager.is_inventory_open:
		return
	if _is_placement_active():
		return
	if event is InputEventMouseButton \
	and event.pressed \
	and not event.echo \
	and event.button_index == MOUSE_BUTTON_LEFT:
		_try_use_equipped_item()

	_register_energy_state()


func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	_handle_hotbar_input()

	if Input.is_action_just_pressed("use_item"):
		_try_use_equipped_item()

	if Input.is_action_just_pressed("interact"):
		print("[DEBUG] interact pressed")
		if not _try_use_equipped_item():
			_handle_interaction_input(InteractionMode.PRIMARY)

	if Input.is_action_just_pressed("pick_up"):
		print("[INPUT] PICKUP pressed")
		_handle_interaction_input(InteractionMode.PICKUP)

		
	if Input.is_action_just_pressed("inventory_toggle"):

		print("Pressed inventory")

		if InventoryManager != null:

			print("Calling inventory manager")

			InventoryManager.toggle_inventory()

	_update_interaction_target()

	if InventoryManager != null and InventoryManager.is_inventory_open:

		velocity = Vector2.ZERO
		_play_idle()

		return

	if is_moving:
		_move_towards_target()
	else:
		_handle_movement_input()



# ==================================================
# MOVEMENT INPUT
# ==================================================

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


# ==================================================
# MOVEMENT
# ==================================================

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

	velocity = to_target.normalized() * get_move_speed()

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


# ==================================================
# ANIMATION
# ==================================================

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


# ==================================================
# INTERACTION SYSTEM
# ==================================================

func _update_interaction_target() -> void:
	var nearest := _get_nearest_interactable()

	if nearest != current_interactable:
		print("[INTERACT] target changed ->", nearest)

	current_interactable = nearest
	interaction_target_changed.emit(current_interactable)


func _get_nearest_interactable() -> InteractableComponent:

	if interaction_area == null:
		print("[INTERACT] NO interaction_area")
		return null

	var overlapping := interaction_area.get_overlapping_areas()


	if overlapping.is_empty():
		return null

	var best_component: InteractableComponent = null
	var best_priority := -INF
	var best_distance := INF

	for area in overlapping:


		# IMPORTANT: we no longer assume area IS Interactable
		# instead we look for a component inside the entity

		var components := area.get_children()

		for c in components:

			if c is InteractableComponent:

				var interactable := c as InteractableComponent

				if not interactable.can_interact(self):
					print("[INTERACT] ignored component on:", area.name)
					continue

				var priority := float(interactable.priority)
				var distance := global_position.distance_squared_to(area.global_position)

				if best_component == null \
				or priority > best_priority \
				or (priority == best_priority and distance < best_distance):

					best_component = interactable
					best_priority = priority
					best_distance = distance

	if best_component != null:
		return best_component

	return null

func _get_interactable_from_entity(entity: Node) -> Node:
	for child in entity.get_children():
		if child.has_method("interact"):
			return child
	return null


func _handle_interaction_input(mode: int = InteractionMode.PRIMARY) -> void:
	print("[INTERACT] input received by player:", player_id, " mode=", mode)

	var interactable := current_interactable
	if interactable == null:
		print("[INTERACT] no interactable in range")
		return

	var entity := interactable.get_parent()
	if entity == null:
		print("[INTERACT] interactable has no parent entity")
		return

	var best_component = null
	var best_priority := -INF

	print("[INTERACT] scanning entity:", entity.name)

	for c in entity.get_children():
		print(
				"[SCAN]",
				c.name,
				" script=",
				c.get_script()
			)
		if not c.has_method("interact"):
			continue

		var mode_ok := true

		if "allowed_mode" in c:
			if c.allowed_mode != mode:
				mode_ok = false

		if not mode_ok:
			continue

		var priority := 0
		if "priority" in c:
			priority = c.priority

		if best_component == null or priority > best_priority:
			best_component = c
			best_priority = priority

	if best_component == null:
		print("[INTERACT] no valid component for mode")
		return

	print("[INTERACT] using component:", best_component.name)

	best_component.interact(self)


func _handle_hotbar_input() -> void:
	var hotbar_size := 8
	if InventoryManager != null:
		hotbar_size = InventoryManager.HOTBAR_SIZE

	for i in range(hotbar_size):
		var action_name := "hotbar_%d" % (i + 1)
		if Input.is_action_just_pressed(action_name):
			set_selected_hotbar_slot(i)
			return

	if Input.is_action_just_pressed("hotbar_next"):
		set_selected_hotbar_slot(selected_hotbar_slot + 1)
		return

	if Input.is_action_just_pressed("hotbar_previous"):
		set_selected_hotbar_slot(selected_hotbar_slot - 1)


func _ensure_hotbar_input_actions() -> void:
	var keycodes := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]
	for i in range(keycodes.size()):
		var action_name := "hotbar_%d" % (i + 1)
		_ensure_action(action_name)
		_ensure_key_binding(action_name, keycodes[i])

	_ensure_action("hotbar_next")
	_ensure_action("hotbar_previous")
	_ensure_mouse_wheel_binding("hotbar_next", MOUSE_BUTTON_WHEEL_DOWN)
	_ensure_mouse_wheel_binding("hotbar_previous", MOUSE_BUTTON_WHEEL_UP)

	_ensure_action("use_item")
	_ensure_key_binding("use_item", KEY_F)


func _ensure_action(action_name: StringName) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)


func _ensure_key_binding(action_name: StringName, keycode: Key) -> void:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.keycode == keycode:
			return

	var key_event := InputEventKey.new()
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, key_event)


func _ensure_mouse_wheel_binding(action_name: StringName, button_index: MouseButton) -> void:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and event.button_index == button_index:
			return

	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = button_index
	InputMap.action_add_event(action_name, mouse_event)


func set_selected_hotbar_slot(slot_index: int) -> void:
	var hotbar_size := 8
	if InventoryManager != null:
		hotbar_size = InventoryManager.HOTBAR_SIZE
	if hotbar_size <= 0:
		return

	var wrapped_slot := wrapi(slot_index, 0, hotbar_size)
	if selected_hotbar_slot == wrapped_slot:
		_update_equipped_item()
		return

	selected_hotbar_slot = wrapped_slot
	hotbar_selection_changed.emit(selected_hotbar_slot)
	_update_equipped_item()


func get_equipped_item() -> ItemData:
	return equipped_item


func _try_use_equipped_item() -> bool:
	if InventoryManager == null:
		return false
	if InventoryManager.is_inventory_open:
		return false
	if _is_placement_active():
		return false

	var item := equipped_item
	if item == null:
		return false

	if item.placeable:
		if PlacementManager == null:
			return false
		return PlacementManager.begin_placement(item, selected_hotbar_slot)

	if item.consumable:
		InventoryManager.use_item(selected_hotbar_slot, self)
		return true

	return false


func _is_placement_active() -> bool:
	if PlacementManager == null:
		return false
	if not PlacementManager.has_method("is_placement_active"):
		return false
	return bool(PlacementManager.is_placement_active())


func _on_inventory_changed() -> void:
	_update_equipped_item()


func _update_equipped_item() -> void:
	var next_item: ItemData = null

	if InventoryManager != null:
		var slot_data: Variant = InventoryManager.get_hotbar_slot(selected_hotbar_slot)
		if slot_data is Dictionary:
			var slot_dict := slot_data as Dictionary
			var raw_item: Variant = slot_dict.get("item")
			if raw_item is ItemData:
				next_item = raw_item as ItemData

	var item_changed := equipped_item != next_item
	equipped_item = next_item
	if item_changed:
		equipped_item_changed.emit(equipped_item, selected_hotbar_slot)


# ==================================================
# LEVEL SYSTEM
# ==================================================

func set_current_level(lvl: int) -> void:

	current_level = lvl

func get_status_effect_component() -> StatusEffectComponent:

	for child in get_children():

		if child is StatusEffectComponent:
			return child

	return null

func get_move_speed() -> float:

	var final_speed := move_speed
	var energy_player_id := _resolve_energy_player_id()

	var status = get_status_effect_component()

	if status != null:

		if status.has_effect("coffee_speed"):
			final_speed *= 1.5

	if EnergyManager != null and energy_player_id >= 0:
		final_speed *= EnergyManager.get_movement_speed_multiplier(energy_player_id)

	return final_speed


func consume_energy(amount: float) -> bool:
	if EnergyManager == null:
		return true
	var energy_player_id := _resolve_energy_player_id()
	if energy_player_id < 0:
		return true
	return EnergyManager.consume_energy(energy_player_id, amount)


func recover_energy(amount: float) -> void:
	if EnergyManager == null:
		return
	var energy_player_id := _resolve_energy_player_id()
	if energy_player_id < 0:
		return
	EnergyManager.recover_energy(energy_player_id, amount)


func _register_energy_state() -> void:
	if EnergyManager == null:
		return
	var energy_player_id := _resolve_energy_player_id()
	if energy_player_id < 0:
		return
	if not EnergyManager.has_player(energy_player_id):
		EnergyManager.register_player(energy_player_id)


func _resolve_energy_player_id() -> int:
	if player_id >= 0:
		return player_id
	var authority := get_multiplayer_authority()
	if authority > 0:
		return authority
	return -1


func get_saveable_id() -> String:
	return "player_%s" % str(player_id)


func save_state() -> Dictionary:
	var status_effects: Dictionary = {}
	var status := get_status_effect_component()
	if status != null and status.has_method("save_state"):
		status_effects = status.save_state()

	return {
		"player_id": player_id,
		"current_level": current_level,
		"selected_hotbar_slot": selected_hotbar_slot,
		"position": {
			"x": global_position.x,
			"y": global_position.y,
		},
		"status_effects": status_effects,
	}


func load_state(data: Dictionary) -> void:
	player_id = int(data.get("player_id", player_id))
	current_level = int(data.get("current_level", current_level))
	set_selected_hotbar_slot(int(data.get("selected_hotbar_slot", selected_hotbar_slot)))

	var position_data: Variant = data.get("position", {})
	if position_data is Dictionary:
		var pos_dict: Dictionary = position_data as Dictionary
		var loaded_position: Vector2 = Vector2(float(pos_dict.get("x", global_position.x)), float(pos_dict.get("y", global_position.y)))
		global_position = loaded_position
		target_position = loaded_position
		is_moving = false

	var status := get_status_effect_component()
	var saved_status: Variant = data.get("status_effects", {})
	if status != null and status.has_method("load_state") and saved_status is Dictionary:
		status.load_state(saved_status)
