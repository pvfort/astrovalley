extends CanvasLayer

@export var max_night_alpha: float = 0.65
@export var max_stars_alpha: float = 0.5
@export var night_overlay_texture: Texture2D = preload("res://assets/environment/night_overlay.png")
@export var stars_overlay_texture: Texture2D = preload("res://assets/environment/stars_overlay.png")
@export var rain_overlay_texture: Texture2D
@export var cloud_overlay_texture: Texture2D
@export var rain_particle_texture: Texture2D

var _night_overlay: TextureRect
var _stars_overlay: TextureRect
var _rain_overlay: TextureRect
var _cloud_overlay: TextureRect
var _weather_tint: ColorRect
var _rain_particles: CPUParticles2D
var _weather_light_multiplier: float = 1.0


func _ready() -> void:
	layer = 5
	_night_overlay = _build_overlay("NightOverlay", night_overlay_texture)
	_stars_overlay = _build_overlay("StarsOverlay", stars_overlay_texture)
	_rain_overlay = _build_overlay("RainOverlay", _resolve_rain_overlay_texture())
	_cloud_overlay = _build_overlay("CloudOverlay", _resolve_cloud_overlay_texture())
	_weather_tint = _build_weather_tint()
	_rain_particles = _build_rain_particles()
	WorldClock.time_changed.connect(_on_time_changed)
	_on_time_changed(WorldClock.current_hour, WorldClock.current_minute)
	_connect_weather_signals()
	_update_particle_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_particle_layout()


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
	node.visible = texture_value != null
	add_child(node)
	return node


func _build_weather_tint() -> ColorRect:
	var node := ColorRect.new()
	node.name = "WeatherTint"
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.color = Color(1.0, 1.0, 1.0, 0.0)
	add_child(node)
	return node


func _build_rain_particles() -> CPUParticles2D:
	var node := CPUParticles2D.new()
	node.name = "RainParticles"
	node.amount = 300
	node.lifetime = 1.25
	node.preprocess = 1.0
	node.speed_scale = 1.0
	node.emitting = false
	node.direction = Vector2(0.2, 1.0)
	node.spread = 8.0
	node.gravity = Vector2(180.0, 1200.0)
	node.initial_velocity_min = 720.0
	node.initial_velocity_max = 1080.0
	node.scale_amount_min = 0.4
	node.scale_amount_max = 0.7
	node.color = Color(0.86, 0.9, 1.0, 0.55)
	node.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	node.texture = _resolve_rain_particle_texture()
	add_child(node)
	return node


func _on_time_changed(hour: int, minute: int) -> void:
	var t := float(hour) + (float(minute) / 60.0)
	var night_alpha := _compute_night_alpha(t) * _weather_light_multiplier
	var stars_alpha := _compute_stars_alpha(t)
	_night_overlay.modulate.a = clampf(night_alpha, 0.0, 1.0)
	_stars_overlay.modulate.a = stars_alpha


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


func _connect_weather_signals() -> void:
	if WeatherManager == null:
		return
	if WeatherManager.has_signal("weather_changed"):
		if not WeatherManager.weather_changed.is_connected(_on_weather_changed):
			WeatherManager.weather_changed.connect(_on_weather_changed)
	_on_weather_changed(WeatherManager.current_weather, WeatherManager.get_current_weather_data())


func _on_weather_changed(_weather_name: String, weather_data: Dictionary) -> void:
	var tint := weather_data.get("ambience_tint", Color(1.0, 1.0, 1.0, 0.0))
	var rain_intensity := clampf(float(weather_data.get("precipitation_intensity", 0.0)), 0.0, 1.0)
	var cloud_coverage := clampf(float(weather_data.get("cloud_coverage", 0.0)), 0.0, 1.0)
	_weather_light_multiplier = clampf(float(weather_data.get("ambient_light_multiplier", 1.0)), 0.0, 1.2)

	_weather_tint.color = tint
	_rain_overlay.modulate.a = rain_intensity * 0.55
	_cloud_overlay.modulate.a = cloud_coverage * 0.5
	_rain_particles.emitting = rain_intensity > 0.05
	_rain_particles.amount = int(180 + rain_intensity * 320.0)
	_rain_particles.color.a = 0.3 + (rain_intensity * 0.45)

	_on_time_changed(WorldClock.current_hour, WorldClock.current_minute)


func _update_particle_layout() -> void:
	if _rain_particles == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_rain_particles.position = Vector2(viewport_size.x * 0.5, -16.0)
	_rain_particles.emission_rect_extents = Vector2(maxf(4.0, viewport_size.x * 0.55), 24.0)


func _resolve_rain_overlay_texture() -> Texture2D:
	if rain_overlay_texture != null:
		return rain_overlay_texture
	return _create_solid_texture(Color(0.70, 0.78, 0.90, 1.0))


func _resolve_cloud_overlay_texture() -> Texture2D:
	if cloud_overlay_texture != null:
		return cloud_overlay_texture
	return _create_solid_texture(Color(0.84, 0.88, 0.94, 1.0))


func _resolve_rain_particle_texture() -> Texture2D:
	if rain_particle_texture != null:
		return rain_particle_texture
	var image := Image.create(2, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.86, 0.90, 1.0, 0.9))
	return ImageTexture.create_from_image(image)


func _create_solid_texture(color: Color) -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
