extends Node3D
## MansionRoot — the standalone Haunted Mansion roguelike's main scene.
##
## This REPLACES the old island main.gd. There is no island, no Mom intro, no
## docks, no Captain Salty, no sailing, no quest. Booting this scene starts a
## roguelike run immediately: RunState.start_run() generates a LEVEL 1 mansion,
## MansionRoguelike builds its first room, and the corgi is dropped inside with
## the Ghost Sucker already equipped. Clear a level and the next mansion is
## generated; get scared out and you restart at a freshly generated level 1.

@onready var player = $Player
@onready var hud = $HUD
@onready var mansion: Node3D = $Mansion
@onready var env: Environment = ($WorldEnvironment as WorldEnvironment).environment


func _ready() -> void:
	Game.reset()
	RunState.reset()

	# Spooky mansion ambience (no bright island day).
	_set_spooky_sky()

	player.health_changed.connect(hud.set_health)
	hud.set_health(player.health, player.max_health)
	player.interact_target_changed.connect(_on_interact_target_changed)

	# React to the roguelike loop: every freshly generated level (L1, advances,
	# and death-resets) drops the corgi into the new mansion's entry.
	RunState.level_generated.connect(_on_level_generated)
	RunState.died.connect(_on_died)
	RunState.level_cleared.connect(_on_level_cleared)

	# Straight into a generated level 1 — no island, no intro.
	RunState.start_run()
	mansion.begin_simulation(player)
	_drop_into_entry()
	hud.show_banner("Haunted Mansion — Level 1", 2.0)
	print("BOOT: standalone roguelike started at level %d (seed %d, %d rooms, no island)" % [
		RunState.level, RunState.current_seed, RunState.rooms_in_level])


func _on_level_generated(level: int, _seed: int) -> void:
	# The mansion node rebuilt itself for the new level; move the corgi to the
	# new entry on the next frame (after the room's geometry exists).
	_drop_into_entry.call_deferred()
	if level > 1:
		hud.show_banner("Level %d" % level, 1.6)


func _on_level_cleared(level: int) -> void:
	hud.show_banner("Level %d cleared!" % level, 1.6)


func _on_died(level_reached: int) -> void:
	hud.show_banner("Scared out on level %d! Back to level 1..." % level_reached, 2.0)


func _drop_into_entry() -> void:
	var spot: Vector3 = mansion.player_entry_point()
	player.place_at(spot, spot + Vector3(0, 0, -4.0))


func _on_interact_target_changed(target: Node3D) -> void:
	hud.set_prompt(str(target.get("prompt_text")) if target else "")


func _set_spooky_sky() -> void:
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	if sky_mat == null:
		return
	sky_mat.sky_top_color = Color(0.06, 0.05, 0.12)
	sky_mat.sky_horizon_color = Color(0.2, 0.28, 0.25)
	sky_mat.ground_bottom_color = Color(0.05, 0.08, 0.07)
	sky_mat.ground_horizon_color = Color(0.2, 0.28, 0.25)
	env.ambient_light_energy = 0.45
	env.fog_light_color = Color(0.3, 0.42, 0.35)
	env.fog_density = 0.03
