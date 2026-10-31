extends CharacterBody3D
## A TINY stand-in ghost, used ONLY so the haunted island works (and tests
## run) before worker B's real ghost at res://scenes/ghost.tscn exists.
##
## It copies the contract B's ghost promises: it sits in the "ghosts" group,
## emits `captured`, calls Game.ghost_scare() when it bumps the corgi, and
## Game.add_ghost_energy(1) + frees itself when "sucked up". Here, a swing of
## the corgi's weapon (or pressing E nearby) counts as a suck.
##
## The portal prefers B's real ghost whenever it's there, so this placeholder
## only shows up on its own branch.

signal captured

@export var float_speed := 1.4
@export var prompt_text := "Slurp the ghost"

var _time := 0.0
var _drift := Vector3.ZERO
var _player: Node3D
var _captured := false


func _ready() -> void:
	add_to_group("ghosts")
	add_to_group("enemies")        # so a sword swing can "slurp" it in testing
	add_to_group("interactable")   # ...or press E next to it
	_time = randf() * 10.0
	_drift = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	_paint()


## Toon white body, dark little eyes. Built in code so we don't need a .tres.
func _paint() -> void:
	var ghost_mat := StandardMaterial3D.new()
	ghost_mat.albedo_color = Color(0.92, 0.95, 1.0, 0.85)
	ghost_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for part in ["Head", "Body"]:
		var mi := get_node_or_null(part) as MeshInstance3D
		if mi:
			mi.material_override = ghost_mat
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.1, 0.06, 0.14)
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for part in ["EyeL", "EyeR"]:
		var mi := get_node_or_null(part) as MeshInstance3D
		if mi:
			mi.material_override = eye_mat


func _physics_process(delta: float) -> void:
	_time += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	# Bob and drift around lazily.
	velocity = _drift * float_speed
	velocity.y = sin(_time * 2.0) * 0.4
	if _time > 2.5:
		_time = randf() * 2.0
		_drift = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	move_and_slide()
	# Bumped into the corgi? That's a scare (never a heart).
	if _player and global_position.distance_to(_player.global_position) < 1.2:
		Game.ghost_scare()


## A sword swing counts as a slurp (matches the "enemies" take_hit contract).
func take_hit(_damage: int, _from: Vector3) -> void:
	_get_sucked_up()


## Or press E right next to it.
func interact(_player_node: Node) -> void:
	_get_sucked_up()


func _get_sucked_up() -> void:
	if _captured:
		return
	_captured = true
	remove_from_group("ghosts")
	remove_from_group("enemies")
	remove_from_group("interactable")
	Game.add_ghost_energy(1)
	captured.emit()
	Effects.poof(get_parent(), global_position, Color(0.8, 0.95, 1.0), 0.8, 8)
	queue_free()
