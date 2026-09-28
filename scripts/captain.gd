extends "res://scripts/villager.gd"
## Captain Salty, who sails the boat to the next island... once the
## Corgiwizard's curse is broken.


func interact(_player_node: Node) -> void:
	_talking = true
	if Game.stage < Game.Stage.SET_SAIL:
		Game.say(npc_name, [
			"Ahoy there, little matey! I'm Captain Salty.",
			"I'd love to sail ye to the next island...|but a dark curse hangs over these waters. Something wicked is coming, I can feel it in me whiskers!",
		], _done_talking)
	else:
		Game.say(npc_name, [
			"Arr! The curse be broken and the seas be calm!",
			"All aboard for the next island!",
		], _set_sail)


func _set_sail() -> void:
	_done_talking()
	Game.next_island_requested.emit()
