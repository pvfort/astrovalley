extends Control

# MainMenu: Handles host/join/quit actions before entering the gameplay scene.

const GAMEPLAY_SCENE = "res://scenes/main.tscn"
const DEFAULT_PORT = 4242

@onready var port_field: LineEdit = $VBoxContainer/PortField
@onready var ip_field: LineEdit = $VBoxContainer/JoinRow/IPField
@onready var status_label: Label = $VBoxContainer/StatusLabel

func _on_host_pressed() -> void:
	var port = int(port_field.text) if port_field.text.is_valid_int() else DEFAULT_PORT
	var ok = NetworkManager.host_game(port)
	if ok:
		get_tree().change_scene_to_file(GAMEPLAY_SCENE)
	else:
		status_label.text = "Failed to host on port %d" % port

func _on_join_pressed() -> void:
	var ip = ip_field.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Please enter a server IP address."
		return
	var port = int(port_field.text) if port_field.text.is_valid_int() else DEFAULT_PORT
	var ok = NetworkManager.join_game(ip, port)
	if ok:
		get_tree().change_scene_to_file(GAMEPLAY_SCENE)
	else:
		status_label.text = "Failed to join %s:%d" % [ip, port]

func _on_quit_pressed() -> void:
	get_tree().quit()
