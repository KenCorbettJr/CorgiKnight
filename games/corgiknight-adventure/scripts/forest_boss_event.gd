extends Node
## The second boss battle!
##
## Taking the Golden Acorn from the forest shrine brings the Corgiwizard
## back, and he is NOT happy that the corgi keeps finding his hidden
## treasures. He summons the Giant Cyclops. main.gd starts this by calling
## begin() after the acorn is taken.

const BOSS_SCENE := preload("res://scenes/boss_cyclops.tscn")

## These are all measured from the middle of the forest shrine.
@export var arena_offset := Vector3(0, 0, 4.5)
@export var player_offset := Vector3(0, 0.1, 10.5)
@export var wizard_offset := Vector3(0, 3.2, 0)
@export var camera_offset := Vector3(7.5, 5.0, 13.0)

@onready var main: Node3D = get_parent()
@onready var hud = $"../HUD"
@onready var player = $"../Player"
@onready var wizard = $"../Corgiwizard"
@onready var cutscene_camera: Camera3D = $"../CutsceneCamera"
@onready var shrine: Node3D = $"../ForestIsland/Shrine"
@onready var sky_event = $"../BossEvent"

var _started := false
var _boss: Node3D


## Start the Giant Cyclops scene (only once).
func begin() -> void:
	if _started:
		return
	_started = true
	_run()


func _run() -> void:
	Game.in_cutscene = true
	var center := shrine.global_position
	var arena := center + arena_offset

	await hud.fade_out(0.5)
	player.place_at(center + player_offset, center)
	cutscene_camera.look_at_from_position(center + camera_offset, center + Vector3(0, 2.0, 3.0))
	cutscene_camera.make_current()
	sky_event.call("_change_sky", 1.0, 3.0)
	await hud.fade_in(0.8)
	await _wait(1.0)

	wizard.global_position = center + wizard_offset
	wizard.appear()
	wizard.face(player.global_position)
	await _wait(1.0)

	await _say("Corgiwizard", [
		"YOU AGAIN?!",
		"That's MY Golden Acorn! I hid it in the deepest, darkest woods!",
		"First my Slime Stone, now this?! How do you keep FINDING my things?!",
	])
	wizard.set_laughing(true)
	await _say("Corgiwizard", ["Grrr... fine! Let's see you handle my biggest, grumpiest friend!"])
	wizard.set_laughing(false)

	# The summoning.
	wizard.set_staff_raised(true)
	await _wait(0.7)
	Effects.poof(main, arena + Vector3.UP * 2.0, Color(0.6, 0.25, 0.9), 4.0, 28)
	_boss = BOSS_SCENE.instantiate() as Node3D
	_boss.position = arena + Vector3.UP * 0.3
	main.add_child(_boss)
	var boss_model := _boss.get_node("Model") as Node3D
	boss_model.scale = Vector3.ZERO
	boss_model.rotation.y = PI  # turn around to face the corgi
	create_tween().tween_property(boss_model, "scale", Vector3.ONE * 2.6, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(1.4)

	await _say("Corgiwizard", [
		"Behold... the GIANT CYCLOPS!",
		"Smash that pesky pup! Mwahahaha!",
	])
	wizard.set_staff_raised(false)
	wizard.vanish()
	await _wait(0.8)

	# FIGHT!
	player.use_camera()
	Game.set_stage(Game.Stage.BOSS2_FIGHT)
	hud.show_boss_bar("GIANT CYCLOPS", _boss.get("max_health"))
	_boss.connect("health_changed", hud.set_boss_health)
	_boss.connect("defeated", _on_boss_defeated)
	Game.in_cutscene = false
	_boss.call("activate")
	Game.message.emit("Defeat the Giant Cyclops!")


func _on_boss_defeated() -> void:
	Game.in_cutscene = true
	hud.hide_boss_bar()
	for minion in get_tree().get_nodes_in_group("boss_minions"):
		if minion is Node3D:
			Effects.poof(main, (minion as Node3D).global_position, Color(0.7, 0.4, 1.0), 0.8)
		minion.queue_free()
	await _wait(1.2)
	sky_event.call("_change_sky", 0.0, 3.0)
	Game.message.emit("The Whispering Woods are safe!")
	await _wait(3.2)
	main.call("_set_area", "forest")  # put the forest's own fog back

	await _say("Corgiwizard (from far away)", [
		"NOOOO! Not my Giant Cyclops too!",
		"You'll NEVER find what I've hidden on the next island!|NEVER! Do you hear me?! Mwaha... ugh.",
	])
	Game.set_stage(Game.Stage.FOREST_DONE)
	Game.in_cutscene = false
	if is_instance_valid(_boss):
		_boss.queue_free()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _say(speaker: String, lines: Array) -> void:
	var state := {"done": false}
	Game.say(speaker, lines, func() -> void: state["done"] = true)
	while not state["done"]:
		await get_tree().process_frame
