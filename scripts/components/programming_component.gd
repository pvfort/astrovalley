class_name ProgrammingComponent
extends InteractableComponent

signal programming_started(player_id: int)
signal programming_completed(player_id: int)

@export var skill_id: String = "programming"
@export var xp_gain: int = 15
@export var time_advance_minutes: int = 45
@export var consume_energy: bool = false
@export var energy_cost: float = 5.0
@export var active_texture: Texture2D = preload("res://assets/entities/furniture/computer_on.png")

var _original_texture: Texture2D

func _ready() -> void:
    priority = max(priority, 10)

func interact(player: PlayerCharacter) -> void:
    if player == null:
        return

    programming_started.emit(player.player_id)
    _set_computer_visual(true)

    if skill_id != "":
        SkillManager.add_xp(skill_id, xp_gain)
        WorldClock.add_daily_skill_xp(skill_id, xp_gain)

    WorldClock.add_minutes(time_advance_minutes)
    WorldClock.add_programming_progress(time_advance_minutes)
    _attempt_energy_spend(player)

    await get_tree().create_timer(0.2).timeout
    _set_computer_visual(false)
    programming_completed.emit(player.player_id)

func _attempt_energy_spend(player: PlayerCharacter) -> void:
    if not consume_energy:
        return

    if player.has_method("consume_energy"):
        player.consume_energy(energy_cost)
        return

    var status := player.get_status_effect_component()
    if status != null and status.has_method("apply"):
        status.apply("programming_fatigue", energy_cost, {"temporary": true, "source": "programming"})

func _set_computer_visual(active: bool) -> void:
    var sprite := get_parent().get_node_or_null("Sprite2D") as Sprite2D
    if sprite == null:
        return

    if _original_texture == null:
        _original_texture = sprite.texture

    if active and active_texture != null:
        sprite.texture = active_texture
    else:
        sprite.texture = _original_texture
