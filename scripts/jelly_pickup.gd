extends Node3D
## A wobbly blob of Slime Jelly dropped by a slime. Walk into it to pick it up!

@export var color := Color(0.45, 0.85, 0.35)
@export var pickup_range := 1.1

@onready var blob: MeshInstance3D = $Blob

var _time := 0.0
var _ground_y := 0.0
var _collected := false
var _player: Node3D


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.emission_enabled = true
	mat.emission = color * 0.35
	blob.material_override = mat
	_ground_y = _find_ground()
	# Pop out of the slime with a little bounce.
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
	blob.rotation.y += delta * 1.5
	blob.scale = Vector3(1.0 + sin(_time * 6.0) * 0.08, 1.0 - sin(_time * 6.0) * 0.08, 1.0 + sin(_time * 6.0) * 0.08)

	if _collected or _time < 0.4:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player and global_position.distance_to(_player.global_position + Vector3.UP * 0.4) < pickup_range:
		_collect()


func _collect() -> void:
	_collected = true
	Game.add_jelly(1)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.5, 0.08)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.15)
	tween.tween_callback(queue_free)
