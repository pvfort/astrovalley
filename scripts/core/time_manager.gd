extends Node

# TimeManager: Manages global synchronized day cycle
# Server authoritative

signal phase_changed(new_phase: String)

enum Phase { MORNING, AFTERNOON, NIGHT }

var current_phase: Phase = Phase.MORNING
var phase_duration: float = 180.0  # seconds
var timer: Timer

func _ready():
	timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(_on_phase_timeout)
	
	# Load config
	var config = load_json("res://data/config.json")
	if config and config.has("phase_duration"):
		phase_duration = config["phase_duration"]
	
	if multiplayer.is_server():
		start_cycle()

func start_cycle():
	timer.start(phase_duration)

func _on_phase_timeout():
	if not multiplayer.is_server():
		return
	
	# Advance phase
	current_phase = (current_phase + 1) % 3
	var phase_name = get_phase_name(current_phase)
	phase_changed.emit(phase_name)
	
	# Sync to clients
	rpc("sync_phase", current_phase)
	
	# Restart timer
	timer.start(phase_duration)

func get_phase_name(phase: Phase) -> String:
	match phase:
		Phase.MORNING: return "morning"
		Phase.AFTERNOON: return "afternoon"
		Phase.NIGHT: return "night"
	return "unknown"

@rpc("authority", "call_local")
func sync_phase(phase: int):
	current_phase = phase
	var phase_name = get_phase_name(current_phase)
	phase_changed.emit(phase_name)

func get_current_phase() -> String:
	return get_phase_name(current_phase)

func load_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			return json.data
	return {}