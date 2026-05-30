extends Node

# Global kill tracker
static var kills: int = 0

static func register_kill() -> bool:
	kills += 1
	var is_special = kills % 3 == 0
	
	if is_special:
		# Heal player by 1 HP every 3rd kill
		var player = _get_player()
		if player and player.has_method("heal"):
			player.heal(1)
	
	return is_special

static func _get_player():
	var tree = Engine.get_main_loop()
	if tree and tree.has_method("get_first_node_in_group"):
		return tree.get_first_node_in_group("player")
	return null
