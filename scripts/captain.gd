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
	elif Game.area == "haunted":
		# On the haunted island Salty only offers the ride home.
		Game.say(npc_name, [
			"Had enough of the spooks, matey? Climb aboard!",
			"I'll sail ye back to safe waters.",
		], _sail_to.bind("home"))
	elif Game.area == "forest":
		# From the forest dock: sail home, and (once the curse is broken) you
		# can choose the haunted island instead.
		_offer_routes("home", "the Whispering Woods")
	else:
		# The home dock: the Whispering Woods is the usual route.
		_offer_routes("forest", "home")


## Offer the normal route, plus (once the forest is reached) the optional
## haunted-island trip. If both are open the corgi gets to pick which one.
func _offer_routes(normal_destination: String, here_name: String) -> void:
	if Game.haunted_available():
		# Salty tells the spooky tale, then lets the corgi pick a destination.
		var normal_label := "Back to the Whispering Woods" if normal_destination == "forest" else "Take me home"
		Game.say(npc_name, [
			"The seas be cursed, matey... but I can take ye to a haunted island!",
			"Cute little ghosts, a spooky old mansion... where to?",
		], _ask_destination.bind(normal_destination, normal_label))
	elif normal_destination == "forest":
		Game.say(npc_name, [
			"Arr! The curse be broken and the seas be calm!",
			"All aboard for the Whispering Woods!",
		], _sail_to.bind("forest"))
	else:
		Game.say(npc_name, ["Ready to sail back to %s, matey? Hop aboard!" % here_name], _sail_to.bind("home"))


## Show a little two-button chooser: the normal route or the haunted island.
func _ask_destination(normal_destination: String, normal_label: String) -> void:
	_done_talking()
	Game.choose("Where to, matey?", [
		{"text": normal_label, "value": normal_destination},
		{"text": "To the haunted island!", "value": "haunted"},
		{"text": "Never mind", "value": ""},
	], _on_destination_chosen)


func _on_destination_chosen(destination: String) -> void:
	if destination == "":
		return  # the corgi changed their mind
	_sail_to(destination)


func _sail_to(destination: String) -> void:
	_done_talking()
	Game.travel_requested.emit(destination)
