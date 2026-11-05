extends "res://scripts/pickup.gd"
## A floating heart that refills one heart of health.

@export var heal_amount := 1


func _give() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.call("heal", heal_amount)
	Game.message.emit("+%d heart" % heal_amount)
