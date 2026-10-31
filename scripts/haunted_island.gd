extends Node3D
## The Haunted Island: a foggy night-time island with a cute-spooky mansion,
## a glowing portal the ghosts pour out of, and the Requiem Bell up in the
## mansion. The optional Luigi's-Mansion-style side-adventure lives here.
##
## This script scatters bare spooky trees and little tombstones (leaving the
## dock, path and mansion clear), equips the Ghost Sucker backpack when you
## arrive, and plays the big finale when the portal is destroyed.

const DEAD_TREE_SCENE := preload("res://scenes/tree.tscn")
const ROCK_SCENE := preload("res://scenes/rock.tscn")
## Worker B builds this on another branch; we guard its use with ResourceLoader.
const GHOST_VACUUM_PATH := "res://scenes/equipment/ghost_vacuum.tscn"

@export var tree_count := 55
@export var rock_count := 10
@export var tombstone_count := 16
@export var island_radius := 30.0
@export var world_seed := 66
## Open spaces to keep clear of trees: x, radius, z (in this island's space).
@export var clearings: Array[Vector3] = [
	Vector3(0, 7.0, 30),     # dock
	Vector3(0, 11.0, -20),   # the mansion
	Vector3(10, 6.0, -2),    # the portal
	Vector3(0, 4.0, 22),
	Vector3(0, 4.0, 16),
	Vector3(0, 4.0, 10),
	Vector3(0, 4.0, 4),
	Vector3(0, 4.0, -2),
	Vector3(0, 4.0, -8),
]

@onready var scenery: Node3D = $Scenery
@onready var portal: Node3D = $GhostPortal

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = world_seed
	_scatter()
	# Play the finale whenever the Requiem Bell is rung.
	Game.portal_destroyed.connect(_on_portal_destroyed)


## Equip the Ghost Sucker backpack. Returns the weapon the corgi had before
## (so main.gd can hand it back when you sail home). Called on arrival.
func give_ghost_vacuum(player: Node) -> PackedScene:
	var previous: PackedScene = null
	var held: Node = player.get("equipped").get("weapon")
	if held != null and is_instance_valid(held) and held.scene_file_path != "":
		previous = load(held.scene_file_path)
	if ResourceLoader.exists(GHOST_VACUUM_PATH):
		player.call("give_weapon", load(GHOST_VACUUM_PATH))
	else:
		# Worker B's backpack isn't on this branch — warn and carry on so the
		# island is still playable (the placeholder ghost can be "slurped"
		# with whatever weapon you're holding, or by pressing E).
		push_warning("Ghost Sucker not found at %s — using your current weapon." % GHOST_VACUUM_PATH)
	return previous


## The bell was rung: tell the portal to collapse and celebrate.
func _on_portal_destroyed() -> void:
	if portal and portal.has_method("destroy"):
		portal.call("destroy")
	Game.message.emit("The portal is destroyed! The haunted island is calm at last.")


# ---------------------------------------------------------------- Scenery

func _is_clear(spot: Vector3) -> bool:
	for c in clearings:
		if Vector2(spot.x - c.x, spot.z - c.z).length() < c.y:
			return false
	return true


func _random_spot() -> Vector3:
	var angle := _rng.randf() * TAU
	var distance := sqrt(_rng.randf()) * island_radius
	return Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)


func _scatter() -> void:
	var dark_bark := _toon(Color(0.22, 0.18, 0.2))
	var bare := _toon(Color(0.3, 0.26, 0.3))

	# Spooky bare trees (reuse the tree scene, but strip the leaves and darken).
	var placed := 0
	var tries := 0
	while placed < tree_count and tries < 2000:
		tries += 1
		var spot := _random_spot()
		if not _is_clear(spot):
			continue
		var tree := DEAD_TREE_SCENE.instantiate() as Node3D
		scenery.add_child(tree)
		tree.position = spot
		tree.rotation.y = _rng.randf() * TAU
		tree.scale = Vector3.ONE * _rng.randf_range(0.8, 1.4)
		# Hide the leafy top so it looks like a bare, dead tree.
		for leaves in ["Top/Leaves", "Top/Leaves2", "Top/Leaves3"]:
			var mi := tree.get_node_or_null(leaves) as MeshInstance3D
			if mi:
				mi.visible = false
		# Darken the trunk.
		for trunk in ["Trunk", "Top/Trunk"]:
			var mi := tree.get_node_or_null(trunk) as MeshInstance3D
			if mi:
				mi.material_override = dark_bark
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

	# Little rounded tombstones dotted around (no collision, just for spookiness).
	var stone_mat := _toon(Color(0.55, 0.55, 0.62))
	placed = 0
	tries = 0
	while placed < tombstone_count and tries < 800:
		tries += 1
		var spot := _random_spot()
		if not _is_clear(spot):
			continue
		var grave := _make_tombstone(stone_mat)
		scenery.add_child(grave)
		grave.position = spot
		grave.rotation.y = _rng.randf_range(-0.3, 0.3)
		grave.scale = Vector3.ONE * _rng.randf_range(0.8, 1.2)
		placed += 1


## A cute rounded headstone: a slab with a domed top.
func _make_tombstone(mat: Material) -> Node3D:
	var grave := Node3D.new()
	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(0.5, 0.7, 0.14)
	slab.mesh = slab_mesh
	slab.material_override = mat
	slab.position = Vector3(0, 0.45, 0)
	grave.add_child(slab)
	var dome := MeshInstance3D.new()
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 0.25
	dome_mesh.height = 0.25
	dome_mesh.is_hemisphere = true
	dome.mesh = dome_mesh
	dome.material_override = mat
	dome.position = Vector3(0, 0.8, 0)
	grave.add_child(dome)
	return grave


func _toon(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return mat
