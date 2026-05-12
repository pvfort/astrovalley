class_name ProximitySensor
extends Area2D

signal player_entered(player: PlayerCharacter)
signal player_exited(player: PlayerCharacter)

func _ready():
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body):
	if body is PlayerCharacter:
		player_entered.emit(body)


func _on_exit(body):
	if body is PlayerCharacter:
		player_exited.emit(body)
