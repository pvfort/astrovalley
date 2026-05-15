extends Node

# Compatibility wrapper for legacy systems that still depend on TimeManager.
signal phase_changed(new_phase: String)

enum Phase { MORNING, AFTERNOON, NIGHT }

var current_phase: Phase = Phase.MORNING

func _ready() -> void:
	if WorldClock != null:
		WorldClock.phase_changed.connect(_on_world_phase_changed)
		_on_world_phase_changed(WorldClock.get_phase_name())

func start_cycle() -> void:
	# WorldClock handles progression automatically.
	pass

func _on_world_phase_changed(phase_name: String) -> void:
	match phase_name:
		"Morning":
			current_phase = Phase.MORNING
		"Afternoon":
			current_phase = Phase.AFTERNOON
		"Evening":
			current_phase = Phase.NIGHT
		_:
			current_phase = Phase.NIGHT

	phase_changed.emit(get_phase_name(current_phase))

func get_phase_name(phase: Phase) -> String:
	match phase:
		Phase.MORNING:
			return "morning"
		Phase.AFTERNOON:
			return "afternoon"
		Phase.NIGHT:
			return "night"
	return "night"

func sync_phase(phase: int) -> void:
	current_phase = phase
	phase_changed.emit(get_phase_name(current_phase))

func get_current_phase() -> String:
	return get_phase_name(current_phase)
