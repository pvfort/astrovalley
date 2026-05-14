class_name SleepComponent
extends InteractableComponent

signal sleep_started(player_id: int)
signal sleep_finished(player_id: int)

const SLEEP_PRIORITY := 20

@export var next_day_hour: int = 8
@export var clear_temporary_effects: bool = true
@export var fade_duration: float = 0.35
@export var fade_texture: Texture2D = preload("res://assets/ui/time/sleep_fade.png")

func _ready() -> void:
    priority = max(priority, SLEEP_PRIORITY)

func interact(player: PlayerCharacter) -> void:
    if player == null:
        return

    sleep_started.emit(player.player_id)
    _apply_sleep_fade(player)

    if clear_temporary_effects:
        _clear_player_temporary_effects(player)

    var summary_data := WorldClock.get_daily_summary_data()
    WorldClock.skip_to_next_morning(next_day_hour)
    WorldClock.daily_summary_requested.emit(summary_data)
    WorldClock.reset_daily_summary_data()

    sleep_finished.emit(player.player_id)

func _clear_player_temporary_effects(player: PlayerCharacter) -> void:
    var status := player.get_status_effect_component()
    if status == null:
        return
    if status.has_method("clear_temporary_effects"):
        status.clear_temporary_effects()

func _apply_sleep_fade(player: PlayerCharacter) -> void:
    if fade_texture == null:
        return

    var layer := CanvasLayer.new()
    layer.layer = 50
    player.add_child(layer)

    var fade := TextureRect.new()
    fade.anchor_right = 1.0
    fade.anchor_bottom = 1.0
    fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fade.texture = fade_texture
    fade.stretch_mode = TextureRect.STRETCH_SCALE
    fade.modulate = Color(1.0, 1.0, 1.0, 0.0)
    layer.add_child(fade)

    var tween := player.create_tween()
    tween.tween_property(fade, "modulate:a", 1.0, fade_duration)
    tween.tween_property(fade, "modulate:a", 0.0, fade_duration)
    tween.finished.connect(func(): layer.queue_free())
