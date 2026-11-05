extends "res://scripts/pickup.gd"
## A shiny spinning coin.

@export var value := 5


func _give() -> void:
	Game.add_coins(value)
	Game.message.emit("+%d coins" % value)
