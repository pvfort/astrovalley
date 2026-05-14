extends CanvasLayer

@export var max_night_alpha: float = 0.65
@export var max_stars_alpha: float = 0.5
@export var night_overlay_texture: Texture2D = preload("res://assets/environment/night_overlay.png")
@export var stars_overlay_texture: Texture2D = preload("res://assets/environment/stars_overlay.png")
@export var rain_overlay_texture: Texture2D
@export var cloud_overlay_texture: Texture2D

var _night_overlay: TextureRect
var _stars_overlay: TextureRect
var _rain_overlay: TextureRect
var _cloud_overlay: TextureRect

func _ready() -> void:
    layer = 5
    _night_overlay = _build_overlay("NightOverlay", night_overlay_texture)
    _stars_overlay = _build_overlay("StarsOverlay", stars_overlay_texture)
    _rain_overlay = _build_overlay("RainOverlay", rain_overlay_texture)
    _cloud_overlay = _build_overlay("CloudOverlay", cloud_overlay_texture)
    WorldClock.time_changed.connect(_on_time_changed)
    _on_time_changed(WorldClock.current_hour, WorldClock.current_minute)

func _build_overlay(node_name: String, texture_value: Texture2D) -> TextureRect:
    var node := TextureRect.new()
    node.name = node_name
    node.anchor_right = 1.0
    node.anchor_bottom = 1.0
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    node.stretch_mode = TextureRect.STRETCH_SCALE
    node.modulate = Color(1.0, 1.0, 1.0, 0.0)
    node.texture = texture_value
    add_child(node)
    return node

func _on_time_changed(hour: int, minute: int) -> void:
    var t := float(hour) + (float(minute) / 60.0)
    var night_alpha := _compute_night_alpha(t)
    var stars_alpha := _compute_stars_alpha(t)
    _night_overlay.modulate.a = night_alpha
    _stars_overlay.modulate.a = stars_alpha
    if _rain_overlay.texture == null:
        _rain_overlay.visible = false
    if _cloud_overlay.texture == null:
        _cloud_overlay.visible = false

func _compute_night_alpha(time_value: float) -> float:
    if time_value >= 22.0 or time_value < 6.0:
        return max_night_alpha
    if time_value >= 18.0 and time_value < 22.0:
        return lerpf(0.0, max_night_alpha, (time_value - 18.0) / 4.0)
    if time_value >= 6.0 and time_value < 8.0:
        return lerpf(max_night_alpha, 0.0, (time_value - 6.0) / 2.0)
    return 0.0

func _compute_stars_alpha(time_value: float) -> float:
    if time_value >= 22.0 or time_value < 5.0:
        return max_stars_alpha
    if time_value >= 20.0 and time_value < 22.0:
        return lerpf(0.0, max_stars_alpha, (time_value - 20.0) / 2.0)
    if time_value >= 5.0 and time_value < 6.0:
        return lerpf(max_stars_alpha, 0.0, time_value - 5.0)
    return 0.0
