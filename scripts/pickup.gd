extends Node3D
## Something the corgi picks up just by walking into it: Slime Jelly, Wood...
##
## It pops out, floats and spins above the ground, and adds one of `kind`
## to the corgi's collection (see Game.add_item) when touched.

## What this counts as in Game.items ("jelly", "wood", ...).
@export var kind := "jelly"
@export var pickup_range := 1.1
## Squishy jelly-style wobble while floating.
@export var wobble := false

@onready var visual: Node3D = $Visual

var _time := 0.0
var _ground_y := 0.0
var _collected := false
var _player: Node3D


func _ready() -> void:
	_ground_y = _find_ground()
	# Pop out with a little bounce.
	scale = Vector3.ZERO
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _find_ground() -> float:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 20.0, 1)
	var hit := space.intersect_ray(query)
	return hit.position.y if hit else global_position.y


func _process(delta: float) -> void:
	_time += delta
	# Float, bob and spin.
	global_position.y = lerpf(global_position.y, _ground_y + 0.35 + sin(_time * 3.0) * 0.08, clampf(8.0 * delta, 0.0, 1.0))
	visual.rotation.y += delta * 1.5
	if wobble:
		var w := sin(_time * 6.0) * 0.08
		visual.scale = Vector3(1.0 + w, 1.0 - w, 1.0 + w)

	if _collected or _time < 0.4:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player and global_position.distance_to(_player.global_position + Vector3.UP * 0.4) < pickup_range:
		_collect()


func _collect() -> void:
	_collected = true
	Game.add_item(kind, 1)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.5, 0.08)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.15)
	tween.tween_callback(queue_free)
