extends Node3D
## A little sandbox for playing with the ghosts and the Ghost Sucker.
##
## This is a TEST scene (not part of the real game). Run it directly from the
## editor (or `--main-scene res://scenes/test/ghost_test.tscn`) to:
##   * walk around with WASD + mouse
##   * press J / left-click to SWING the sword (swings right through ghosts)
##   * press Q to swap to the Ghost Sucker, then HOLD J / left-click to vacuum
##   * hold a ghost in the beam ~1s to slurp it up
##
## Worker A's island does the real equipping/spawning; this just mirrors it so
## the ghost + vacuum can be felt by hand on this branch alone.

const SWORD := preload("res://scenes/equipment/basic_sword.tscn")
const VACUUM := preload("res://scenes/equipment/ghost_vacuum.tscn")
const GHOST := preload("res://scenes/ghost.tscn")

@onready var player: Node = $Player


func _ready() -> void:
	# Give the corgi a sword first (so Q-swapping has something to swap to),
	# then the Ghost Sucker — exactly the calls A's island makes.
	player.call("give_weapon", SWORD)
	player.call("give_weapon", VACUUM)

	# Sprinkle some ghosts around to practice on.
	for i in 6:
		var ghost := GHOST.instantiate() as Node3D
		var angle := TAU * i / 6.0
		ghost.position = Vector3(cos(angle) * 4.0, 1.0, sin(angle) * 4.0 - 3.0)
		add_child(ghost)

	Game.message.emit("Hold J / click to vacuum ghosts. Press Q to swap weapons.")
	print("[ghost_test] sword + Ghost Sucker given, 6 ghosts spawned.")
