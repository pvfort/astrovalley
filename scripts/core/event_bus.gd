# EventBus.gd
extends Node

signal item_collected(player_id, item_id, amount)
signal item_consumed(player_id, item_id)
signal item_purchased(player_id, item_id, amount, cost)
signal station_used(player_id, station_id)
signal npc_talked_to(player_id, npc_id)
signal skill_xp_gained(player_id, skill_id, amount)
signal day_started(day)
signal task_started(player_id, task_id)
signal task_completed(player_id, task_id)
signal location_entered(player_id, location_id)
