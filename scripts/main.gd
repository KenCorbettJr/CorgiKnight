extends Node3D
## Sets up the island (scatters trees, rocks and flowers), connects the HUD
## to the corgi, and plays the wake-up-in-bed intro.

const TREE_SCENE := preload("res://scenes/tree.tscn")
const ROCK_SCENE := preload("res://scenes/rock.tscn")

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

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	Game.reset()
	_rng.seed = world_seed
	_scatter_scenery()

	player.health_changed.connect(hud.set_health)
	hud.set_health(player.health, player.max_health)
	player.interact_target_changed.connect(_on_interact_target_changed)

	_play_intro()


func _on_interact_target_changed(target: Node3D) -> void:
	hud.set_prompt(str(target.get("prompt_text")) if target else "")


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


## True if a spot is inside (or right next to) the house.
func _near_building(spot: Vector3) -> bool:
	var house := $House as Node3D
	var local := spot - house.global_position
	return absf(local.x) < 4.3 and absf(local.z) < 3.9


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
