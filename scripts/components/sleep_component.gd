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

    if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
        rpc_id(1, "server_request_sleep", player.player_id)
        return

    _perform_sleep(player)

@rpc("any_peer", "reliable")
func server_request_sleep(player_id: int) -> void:
    if not multiplayer.is_server():
        return

    var sender_id := multiplayer.get_remote_sender_id()
    if sender_id != player_id:
        return

    var target_player := _find_player_by_id(player_id)
    if target_player == null:
        return

    _perform_sleep(target_player)

func _perform_sleep(player: PlayerCharacter) -> void:
    if clear_temporary_effects:
        _clear_player_temporary_effects(player)

    var summary_data := WorldClock.get_daily_summary_data()
    WorldClock.daily_summary_requested.emit(summary_data)
    WorldClock.skip_to_next_morning(next_day_hour)
    WorldClock.reset_daily_summary_data()
    sleep_finished.emit(player.player_id)

func _find_player_by_id(player_id: int) -> PlayerCharacter:
    for node in get_tree().get_nodes_in_group("player"):
        if node is PlayerCharacter and node.player_id == player_id:
            return node
    return null

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
    var scene_root := get_tree().current_scene
    if scene_root == null:
        return
    scene_root.add_child(layer)

    var fade := TextureRect.new()
    fade.anchor_right = 1.0
    fade.anchor_bottom = 1.0
    fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fade.texture = fade_texture
    fade.stretch_mode = TextureRect.STRETCH_SCALE
    fade.modulate = Color(1.0, 1.0, 1.0, 0.0)
    layer.add_child(fade)

    var tween := scene_root.create_tween()
    tween.tween_property(fade, "modulate:a", 1.0, fade_duration)
    tween.tween_property(fade, "modulate:a", 0.0, fade_duration)
    tween.finished.connect(func(): layer.queue_free())
