extends "res://scripts/villager.gd"
## Captain Salty sails the corgi between islands... once the Corgiwizard's
## curse is broken. The same script works on both docks: he always offers
## to take you to the island you're NOT on.


func interact(_player_node: Node) -> void:
	_talking = true
	if Game.stage < Game.Stage.SET_SAIL:
		Game.say(npc_name, [
			"Ahoy there, little matey! I'm Captain Salty.",
			"I'd love to sail ye to the next island...|but a dark curse hangs over these waters. Something wicked is coming, I can feel it in me whiskers!",
		], _done_talking)
	elif Game.stage == Game.Stage.BOSS2_FIGHT:
		Game.say(npc_name, ["Not now, matey! There be a GIANT cyclops stompin' about!"], _done_talking)
	elif Game.area == "forest":
		var lines := ["Ready to sail back home, matey? Hop aboard!"]
		if Game.stage == Game.Stage.FOREST_DONE:
			lines = [
				"Ye beat the Giant Cyclops! Arr, what a knight!",
				"The seas beyond be too stormy for now... but I can take ye home!",
			]
		Game.say(npc_name, lines, _sail_to.bind("home"))
	else:
		Game.say(npc_name, [
			"Arr! The curse be broken and the seas be calm!",
			"All aboard for the Whispering Woods!",
		], _sail_to.bind("forest"))


func _sail_to(destination: String) -> void:
	_done_talking()
	Game.travel_requested.emit(destination)
