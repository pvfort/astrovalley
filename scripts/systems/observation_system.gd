extends Node

# ObservationSystem: Handles observation tasks

func start_observe(player_id: int):
	if TaskManager.start_task(player_id, "observe"):
		print("Player ", player_id, " started observing")
	else:
		print("Cannot start observe for player ", player_id)