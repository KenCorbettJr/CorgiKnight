extends Node3D
## Sets up the island (scatters trees, rocks and flowers), connects the HUD
## to the corgi, and plays the wake-up-in-bed intro.

const TREE_SCENE := preload("res://scenes/tree.tscn")
const ROCK_SCENE := preload("res://scenes/rock.tscn")
const HEART_SCENE := preload("res://scenes/heart_pickup.tscn")

@export var tree_count := 40
@export var rock_count := 18
@export var flower_count := 120
@export var island_radius := 27.0
## Change this number to get a different layout of trees and rocks.
@export var world_seed := 7

@onready var player = $Player
@onready var hud = $HUD
@onready var mom = $House/Mom
@onready var zzz: Label3D = $House/Zzz
@onready var scenery: Node3D = $Scenery
@onready var cave: Node3D = $Cave
@onready var forest: Node3D = $ForestIsland
@onready var env: Environment = ($WorldEnvironment as WorldEnvironment).environment

## Where the corgi arrives at each dock.
const HOME_DOCK_SPOT := Vector3(0, 0.1, -27.0)

var _rng := RandomNumberGenerator.new()
## Light and fog for each area, filled in when the game starts.
var _area_light := {}
## Where the corgi sleeps (and wakes up after dying) on each island.
var _beds := {}
var _visited_forest := false


func _ready() -> void:
	Game.reset()
	_rng.seed = world_seed
	_scatter_scenery()

	var sunny := {
		"ambient": env.ambient_light_energy,
		"fog_color": env.fog_light_color,
		"fog_density": env.fog_density,
	}
	_area_light = {
		"home": sunny,
		"cave": {"ambient": 0.3, "fog_color": Color(0.12, 0.12, 0.22), "fog_density": 0.05},
		"forest": {"ambient": 0.75, "fog_color": Color(0.55, 0.75, 0.55), "fog_density": 0.014},
	}
	_beds = {"home": player.spawn_point, "forest": forest.get_node("CampBed").global_position}

	player.health_changed.connect(hud.set_health)
	hud.set_health(player.health, player.max_health)
	player.interact_target_changed.connect(_on_interact_target_changed)
	Game.travel_requested.connect(_on_travel_requested)
	player.died.connect(_on_player_died)
	Game.heart_drop.connect(_on_heart_drop)
	player.fell_in_water.connect(_on_fell_in_water)

	_play_intro()


func _on_interact_target_changed(target: Node3D) -> void:
	hud.set_prompt(str(target.get("prompt_text")) if target else "")


## Every few defeated enemies, a heart pops out.
func _on_heart_drop(where: Vector3) -> void:
	var heart := HEART_SCENE.instantiate() as Node3D
	heart.position = where + Vector3.UP * 0.4
	add_child(heart)


## Which island's bed the corgi wakes up in.
func _bed_area() -> String:
	return "forest" if Game.area == "forest" else "home"


## Out of hearts: show "You died!", wait, then wake up in bed.
func _on_player_died() -> void:
	await get_tree().create_timer(0.8).timeout
	await hud.show_death_screen()
	_set_area(_bed_area())
	player.respawn_in_bed()
	await hud.hide_death_screen()
	await player.finish_respawn()
	Game.in_cutscene = false


func _on_fell_in_water() -> void:
	_set_area(_bed_area())


# ---------------------------------------------------------------- Areas

## Switch the light, fog, sea level and respawn bed for an area.
func _set_area(area: String) -> void:
	Game.area = area
	# (During a boss fight the sky stays spooky, so leave the light alone.)
	var boss_fight := Game.stage == Game.Stage.BOSS_FIGHT or Game.stage == Game.Stage.BOSS2_FIGHT
	if not boss_fight:
		var light: Dictionary = _area_light[area]
		env.ambient_light_energy = light["ambient"]
		env.fog_light_color = light["fog_color"]
		env.fog_density = light["fog_density"]
	player.fall_limit = cave.global_position.y - 5.0 if area == "cave" else -2.0
	if _beds.has(area):
		player.spawn_point = _beds[area]
	Game.notify_owned()  # refresh the quest text


# ---------------------------------------------------------------- The well cave

## Climb down the village well into the cave.
func enter_cave() -> void:
	Game.in_cutscene = true
	await hud.fade_out(0.5)
	_set_area("cave")
	player.place_at(cave.get_node("EntrySpot").global_position, cave.get_node("LookHere").global_position)
	await hud.fade_in(0.7)
	hud.show_banner("The Well Cave", 2.0)
	Game.in_cutscene = false


## Climb back up the rope to the village.
func exit_cave() -> void:
	Game.in_cutscene = true
	await hud.fade_out(0.5)
	_set_area("home")
	player.place_at(Vector3(0, 0.1, 12.2), Vector3(0, 0.1, 6.0))
	await hud.fade_in(0.7)
	Game.in_cutscene = false


## Show a conversation and wait until it's finished.
func _say(speaker: String, lines: Array) -> void:
	var state := {"done": false}
	Game.say(speaker, lines, func() -> void: state["done"] = true)
	while not state["done"]:
		await get_tree().process_frame


## The corgi grabbed the Slime Stone! It yanks the corgi back up to the
## village... where someone has been waiting for it.
func take_artifact() -> void:
	Game.in_cutscene = true
	Game.artifact_found = true
	await get_tree().create_timer(1.2).timeout
	await _say("", [
		"The Slime Stone glows brighter... and brighter...",
		"Whoa! It's pulling you up out of the cave!",
	])
	Effects.poof(self, player.global_position + Vector3.UP, Color(0.7, 0.4, 1.0), 1.5, 16)
	await hud.fade_out(0.8)
	_set_area("home")
	player.place_at(Vector3(0, 0.1, 12.2), Vector3(0, 0.1, 6.0))
	# The Corgiwizard's big scene takes it from here (it fades back in).
	$BossEvent.call("begin")
	Game.in_cutscene = false


## The corgi found the Golden Acorn in the forest shrine. Guess who's back...
func take_forest_artifact() -> void:
	Game.in_cutscene = true
	await get_tree().create_timer(1.2).timeout
	await _say("", [
		"The Golden Acorn hums with magic...",
		"Uh oh. The air is getting cold... and you hear an angry grumble.",
	])
	$ForestBossEvent.call("begin")
	Game.in_cutscene = false


# ---------------------------------------------------------------- Sailing

## Captain Salty sails the corgi between the islands.
func _on_travel_requested(destination: String) -> void:
	Game.in_cutscene = true
	await hud.fade_out(0.8)
	var going_to_forest := destination == "forest"
	hud.set_fade_text("Sailing to the Whispering Woods..." if going_to_forest else "Sailing home...")
	await get_tree().create_timer(2.2).timeout
	hud.set_fade_text("")
	if going_to_forest:
		_set_area("forest")
		player.place_at(forest.get_node("ArrivalSpot").global_position, forest.get_node("ArrivalLook").global_position)
		if Game.stage == Game.Stage.SET_SAIL:
			Game.set_stage(Game.Stage.FOREST)
	else:
		_set_area("home")
		player.place_at(HOME_DOCK_SPOT, Vector3(0, 0.1, 0))
	await hud.fade_in(0.8)
	hud.show_banner("The Whispering Woods" if going_to_forest else "Home Island", 2.0)
	if going_to_forest and not _visited_forest:
		_visited_forest = true
		await _say("Captain Salty", [
			"Land ho! Welcome to the Whispering Woods, matey!",
			"Ranger Rowan runs the camp up ahead. Mind the cyclopses: their clubs hurt!|I'll wait here with the boat whenever ye want to sail home.",
		])
	Game.in_cutscene = false


## The corgi is asleep in bed... then wakes up and Mom says good morning.
func _play_intro() -> void:
	Game.controls_locked = true
	player.lie_down()

	# Floating "z Z z" above the bed.
	zzz.visible = true
	var snore := create_tween().set_loops()
	snore.tween_property(zzz, "position:y", zzz.position.y + 0.25, 1.0).set_trans(Tween.TRANS_SINE)
	snore.tween_property(zzz, "position:y", zzz.position.y, 1.0).set_trans(Tween.TRANS_SINE)

	await hud.fade_in(2.0)
	hud.show_banner("CorgiKnight", 1.8)
	await get_tree().create_timer(3.0).timeout

	snore.kill()
	zzz.visible = false
	await player.wake_up()
	await get_tree().create_timer(0.4).timeout

	Game.controls_locked = false
	Game.set_stage(Game.Stage.TALK_TO_MOM)
	mom.greet()


# ---------------------------------------------------------------- Scenery

## Places we keep clear of trees so there's room to play.
func _is_clear_spot(spot: Vector3) -> bool:
	if spot.length() < 6.0:
		return false  # the corgi's starting meadow
	for marker in get_tree().get_nodes_in_group("keep_clear"):
		var m := marker as Node3D
		var flat := Vector2(spot.x - m.global_position.x, spot.z - m.global_position.z)
		if flat.length() < 7.0:
			return false
	return true


## True if a spot is inside (or right next to) a house, shop or well.
func _near_building(spot: Vector3) -> bool:
	for building in get_tree().get_nodes_in_group("building"):
		var b := building as Node3D
		if b and Vector2(spot.x - b.global_position.x, spot.z - b.global_position.z).length() < 5.0:
			return true
	return false


func _random_spot(min_radius: float) -> Vector3:
	var angle := _rng.randf() * TAU
	var distance := sqrt(_rng.randf_range((min_radius / island_radius) ** 2, 1.0)) * island_radius
	return Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)


func _scatter_scenery() -> void:
	var placed := 0
	var tries := 0
	while placed < tree_count and tries < 1000:
		tries += 1
		var spot := _random_spot(6.0)
		if not _is_clear_spot(spot):
			continue
		var tree := TREE_SCENE.instantiate() as Node3D
		scenery.add_child(tree)
		tree.position = spot
		tree.rotation.y = _rng.randf() * TAU
		tree.scale = Vector3.ONE * _rng.randf_range(0.8, 1.35)
		placed += 1

	placed = 0
	tries = 0
	while placed < rock_count and tries < 1000:
		tries += 1
		var spot := _random_spot(5.0)
		if not _is_clear_spot(spot):
			continue
		var rock := ROCK_SCENE.instantiate() as Node3D
		scenery.add_child(rock)
		rock.position = spot
		rock.rotation.y = _rng.randf() * TAU
		rock.scale = Vector3.ONE * _rng.randf_range(0.6, 1.4)
		placed += 1

	# Little flowers everywhere. No collision, just for cuteness.
	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.09
	flower_mesh.height = 0.14
	flower_mesh.radial_segments = 8
	flower_mesh.rings = 4
	var colors := [Color(1, 0.95, 0.5), Color(1, 0.6, 0.75), Color(0.75, 0.7, 1), Color(1, 1, 1)]
	var materials: Array[StandardMaterial3D] = []
	for c in colors:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		materials.append(mat)
	for i in flower_count:
		var flower := MeshInstance3D.new()
		flower.mesh = flower_mesh
		flower.material_override = materials[_rng.randi() % materials.size()]
		flower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var spot := _random_spot(1.5)
		while _near_building(spot):
			spot = _random_spot(1.5)
		scenery.add_child(flower)
		flower.position = spot + Vector3(0, 0.05, 0)
