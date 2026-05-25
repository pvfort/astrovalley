class_name PlayerTradeComponent
extends InteractableComponent

const PLAYER_TRADE_PRIORITY := 40


func _ready() -> void:
	priority = max(priority, PLAYER_TRADE_PRIORITY)


func can_interact(player: PlayerCharacter) -> bool:
	if player == null:
		return false

	var target_player := _target_player()
	if target_player == null:
		return false

	if target_player == player:
		return false

	if target_player.player_id <= 0:
		return false

	if TradeManager != null and TradeManager.has_method("is_trade_active"):
		if TradeManager.is_trade_active():
			return false

	return true


func interact(player: PlayerCharacter) -> void:
	if player == null:
		return

	var target_player := _target_player()
	if target_player == null:
		return

	if TradeManager == null or not TradeManager.has_method("request_trade_with"):
		return

	TradeManager.request_trade_with(target_player.player_id)


func _target_player() -> PlayerCharacter:
	var area := get_parent()
	if area == null:
		return null
	if not (area.get_parent() is PlayerCharacter):
		return null
	return area.get_parent() as PlayerCharacter
