extends Node3D
## The Whispering Woods: a thick forest island full of mini cyclopses.
## This script scatters trees, mushrooms and rocks, but leaves open spaces
## for the camp, the path and the shrine.

const TREE_SCENE := preload("res://scenes/tree.tscn")
const ROCK_SCENE := preload("res://scenes/rock.tscn")
const DARK_LEAVES := preload("res://materials/dark_leaves.tres")

@export var tree_count := 85
@export var rock_count := 14
@export var mushroom_count := 45
@export var island_radius := 31.0
@export var world_seed := 21
## Open spaces to keep free of trees: x, radius, z (in this island's space).
@export var clearings: Array[Vector3] = [
	Vector3(0, 9.0, 21),     # camp
	Vector3(0, 6.0, 31),     # dock
	Vector3(0, 10.5, -23),   # shrine
	Vector3(0, 4.0, 13),     # the path through the woods...
	Vector3(-1, 4.0, 9.5),
	Vector3(-2, 4.0, 6),
	Vector3(-0.5, 4.0, 2.5),
	Vector3(1, 4.0, -1),
	Vector3(0, 4.0, -4.5),
	Vector3(-1, 4.0, -8),
	Vector3(-0.5, 4.0, -11),
	Vector3(0, 4.0, -14),
	Vector3(7.5, 3.5, -10),  # where the boss-scene camera stands
]

@onready var scenery: Node3D = $Scenery

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = world_seed
	_scatter()


func _is_clear(spot: Vector3) -> bool:
	for c in clearings:
		if Vector2(spot.x - c.x, spot.z - c.z).length() < c.y:
			return false
	# Don't put trees right on top of the cyclopses.
	for child in get_children():
		if child is CharacterBody3D:
			var p := (child as Node3D).position
			if Vector2(spot.x - p.x, spot.z - p.z).length() < 2.0:
				return false
	return true


func _random_spot() -> Vector3:
	var angle := _rng.randf() * TAU
	var distance := sqrt(_rng.randf()) * island_radius
	return Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)


func _scatter() -> void:
	var placed := 0
	var tries := 0
	while placed < tree_count and tries < 2000:
		tries += 1
		var spot := _random_spot()
		if not _is_clear(spot):
			continue
		var tree := TREE_SCENE.instantiate() as Node3D
		scenery.add_child(tree)
		tree.position = spot
		tree.rotation.y = _rng.randf() * TAU
		tree.scale = Vector3.ONE * _rng.randf_range(0.9, 1.6)
		# Darker, deep-forest leaves.
		for leaves in ["Top/Leaves", "Top/Leaves2", "Top/Leaves3"]:
			var mi := tree.get_node(leaves) as MeshInstance3D
			if mi:
				mi.material_override = DARK_LEAVES
		placed += 1

	placed = 0
	tries = 0
	while placed < rock_count and tries < 500:
		tries += 1
		var spot := _random_spot()
		if not _is_clear(spot):
			continue
		var rock := ROCK_SCENE.instantiate() as Node3D
		scenery.add_child(rock)
		rock.position = spot
		rock.scale = Vector3.ONE * _rng.randf_range(0.7, 1.5)
		placed += 1

	# Cute spotted mushrooms (no collision, just for looks).
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.05
	stem_mesh.bottom_radius = 0.07
	stem_mesh.height = 0.2
	stem_mesh.radial_segments = 8
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.14
	cap_mesh.height = 0.14
	cap_mesh.is_hemisphere = true
	cap_mesh.radial_segments = 12
	cap_mesh.rings = 4
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.025
	dot_mesh.height = 0.05
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.98, 0.95, 0.88)
	stem_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	var cap_mat := load("res://materials/mushroom_red.tres") as Material
	for i in mushroom_count:
		var spot := _random_spot()
		if not _is_clear(spot):
			continue
		var mushroom := Node3D.new()
		scenery.add_child(mushroom)
		mushroom.position = spot
		mushroom.scale = Vector3.ONE * _rng.randf_range(0.8, 1.8)
		var stem := MeshInstance3D.new()
		stem.mesh = stem_mesh
		stem.material_override = stem_mat
		stem.position = Vector3(0, 0.1, 0)
		mushroom.add_child(stem)
		var cap := MeshInstance3D.new()
		cap.mesh = cap_mesh
		cap.material_override = cap_mat
		cap.position = Vector3(0, 0.19, 0)
		mushroom.add_child(cap)
		for d in 3:
			var dot := MeshInstance3D.new()
			dot.mesh = dot_mesh
			dot.material_override = stem_mat
			var a := TAU * d / 3.0 + _rng.randf()
			dot.position = Vector3(cos(a) * 0.08, 0.28, sin(a) * 0.08)
			mushroom.add_child(dot)
