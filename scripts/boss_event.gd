extends Node
## The first boss battle!
##
## Once the corgi has finished Mom's quests and bought all the armor, the
## village well starts to glow. Down in the cave below is the Slime Stone.
## Taking it pulls the corgi back up... right into the evil Corgiwizard, who
## grabs the stone's power: the sky goes dark, the villagers run and hide,
## and he summons the King Slime. Beat it to break the curse and unlock
## Captain Salty's boat to the next island.
##
## main.gd starts this by calling begin() after the stone is taken.

const BOSS_SCENE := preload("res://scenes/king_slime_boss.tscn")

## Where the King Slime lands.
@export var arena_center := Vector3(0, 0, 10)
## Where the corgi stands when the Corgiwizard appears.
@export var player_spot := Vector3(0, 0.1, 5.5)
## Where the Corgiwizard floats (above the village well).
@export var wizard_spot := Vector3(0, 3.0, 13.5)
## Where the cutscene camera films from.
@export var camera_spot := Vector3(7.0, 4.0, 2.5)

@onready var main: Node3D = get_parent()
@onready var hud = $"../HUD"
@onready var player = $"../Player"
@onready var wizard = $"../Corgiwizard"
@onready var cutscene_camera: Camera3D = $"../CutsceneCamera"
@onready var env: Environment = ($"../WorldEnvironment" as WorldEnvironment).environment
@onready var sun: DirectionalLight3D = $"../Sun"

var _started := false
var _boss: Node3D
var _sky: ProceduralSkyMaterial

# Normal (sunny) and cursed (spooky) sky colors.
var _day := {}
var _night := {
	"top": Color(0.12, 0.05, 0.22),
	"horizon": Color(0.42, 0.2, 0.45),
	"ground_bottom": Color(0.08, 0.04, 0.15),
	"ground_horizon": Color(0.42, 0.2, 0.45),
	"sun_energy": 0.45,
	"sun_color": Color(0.8, 0.55, 1.0),
	"ambient": 0.45,
	"fog_color": Color(0.35, 0.2, 0.42),
	"fog_density": 0.012,
}


func _ready() -> void:
	_sky = env.sky.sky_material as ProceduralSkyMaterial
	_day = {
		"top": _sky.sky_top_color,
		"horizon": _sky.sky_horizon_color,
		"ground_bottom": _sky.ground_bottom_color,
		"ground_horizon": _sky.ground_horizon_color,
		"sun_energy": sun.light_energy,
		"sun_color": sun.light_color,
		"ambient": env.ambient_light_energy,
		"fog_color": env.fog_light_color,
		"fog_density": env.fog_density,
	}


## Start the Corgiwizard scene (only once).
func begin() -> void:
	if _started:
		return
	_start_boss_scene()


# ---------------------------------------------------------------- The big scene

func _start_boss_scene() -> void:
	_started = true
	Game.in_cutscene = true

	await hud.fade_out(0.6)
	player.place_at(player_spot, arena_center)
	cutscene_camera.look_at_from_position(camera_spot, arena_center + Vector3(0, 1.8, 1.5))
	cutscene_camera.make_current()
	_change_sky(1.0, 3.0)  # the sky goes dark...
	await hud.fade_in(0.8)
	await _wait(1.2)

	wizard.global_position = wizard_spot
	wizard.appear()
	wizard.face(player.global_position)
	await _wait(1.0)

	wizard.set_laughing(true)
	await _say("Corgiwizard", ["Mwahahaha! MWAHAHAHAHA!"])
	wizard.set_laughing(false)
	await _say("Corgiwizard", [
		"You found the Slime Stone for me! How very kind, little knight.",
		"I couldn't fit down that tiny well myself. Now its power is MINE!",
		"I am going to destroy your village and put a curse on it!",
	])

	# Everybody run!
	for villager in get_tree().get_nodes_in_group("villagers"):
		if villager.has_method("run_home"):
			villager.run_home()
	await _wait(2.4)

	# The summoning.
	wizard.set_staff_raised(true)
	await _wait(0.7)
	Effects.poof(main, arena_center + Vector3.UP, Color(0.6, 0.25, 0.9), 3.0, 24)
	_boss = BOSS_SCENE.instantiate() as Node3D
	_boss.position = arena_center + Vector3.UP * 0.3
	main.add_child(_boss)
	var boss_model := _boss.get_node("Model") as Node3D
	boss_model.scale = Vector3.ZERO
	create_tween().tween_property(boss_model, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(1.2)

	wizard.set_laughing(true)
	await _say("Corgiwizard", [
		"Rise, my KING SLIME! Crush them all!",
		"Toodle-oo, little knight! Mwahahaha!",
	])
	wizard.set_laughing(false)
	wizard.set_staff_raised(false)
	wizard.vanish()
	await _wait(0.8)

	# FIGHT!
	player.use_camera()
	Game.set_stage(Game.Stage.BOSS_FIGHT)
	hud.show_boss_bar("KING SLIME", _boss.get("max_health"))
	_boss.connect("health_changed", hud.set_boss_health)
	_boss.connect("defeated", _on_boss_defeated)
	Game.in_cutscene = false
	_boss.call("activate")
	Game.message.emit("Defeat the King Slime!")


func _on_boss_defeated() -> void:
	Game.in_cutscene = true
	hud.hide_boss_bar()
	# The King Slime's helpers go poof too.
	for minion in get_tree().get_nodes_in_group("boss_minions"):
		if minion is Node3D:
			Effects.poof(main, (minion as Node3D).global_position, Color(0.7, 0.4, 1.0), 0.8)
		minion.queue_free()
	await _wait(1.2)
	_change_sky(0.0, 3.0)  # the sun comes back out!
	Game.message.emit("The curse is broken!")
	await _wait(2.5)

	await _say("Corgiwizard (from far away)", [
		"NOOOO! My beautiful King Slime!",
		"This isn't over, little knight!|Come find me on the other islands... if you DARE! Mwahaha... ha...",
	])

	for villager in get_tree().get_nodes_in_group("villagers"):
		if villager.has_method("come_out"):
			villager.come_out()
	await _wait(1.5)

	await _say("Old Barnaby", [
		"You did it! You saved Corgi Village!",
		"With the curse broken, Captain Salty's boat can sail again.|Find him at the dock on the north side of the island!",
	])
	Game.set_stage(Game.Stage.SET_SAIL)
	Game.in_cutscene = false
	if is_instance_valid(_boss):
		_boss.queue_free()


# ---------------------------------------------------------------- Helpers

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Show a conversation and wait until it's finished.
func _say(speaker: String, lines: Array) -> void:
	var state := {"done": false}
	Game.say(speaker, lines, func() -> void: state["done"] = true)
	while not state["done"]:
		await get_tree().process_frame


## Fade the sky between sunny (0.0) and cursed (1.0).
func _change_sky(to: float, seconds: float) -> void:
	var from := 1.0 - to
	create_tween().tween_method(_apply_sky, from, to, seconds)


func _apply_sky(t: float) -> void:
	_sky.sky_top_color = (_day["top"] as Color).lerp(_night["top"], t)
	_sky.sky_horizon_color = (_day["horizon"] as Color).lerp(_night["horizon"], t)
	_sky.ground_bottom_color = (_day["ground_bottom"] as Color).lerp(_night["ground_bottom"], t)
	_sky.ground_horizon_color = (_day["ground_horizon"] as Color).lerp(_night["ground_horizon"], t)
	sun.light_energy = lerpf(_day["sun_energy"], _night["sun_energy"], t)
	sun.light_color = (_day["sun_color"] as Color).lerp(_night["sun_color"], t)
	env.ambient_light_energy = lerpf(_day["ambient"], _night["ambient"], t)
	env.fog_light_color = (_day["fog_color"] as Color).lerp(_night["fog_color"], t)
	env.fog_density = lerpf(_day["fog_density"], _night["fog_density"], t)
