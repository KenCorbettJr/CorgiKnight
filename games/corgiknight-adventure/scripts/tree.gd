extends StaticBody3D
## A puffy tree you can chop down with an axe.
##
## Each axe hit makes it shake. After enough hits it falls over (away from
## the corgi), drops wood, and leaves a stump. A while later it grows back.

const WOOD_SCENE := preload("res://scenes/wood_pickup.tscn")

## Axe hits needed to chop it down.
@export var chops_needed := 3
## Pieces of wood it drops.
@export var wood_dropped := 2
## Seconds until the tree grows back from its stump.
@export var regrow_seconds := 60.0

@onready var top: Node3D = $Top
@onready var stump_top: Node3D = $Stump/StumpTop
@onready var collision: CollisionShape3D = $CollisionShape3D

var _chops := 0
var _felled := false


func _ready() -> void:
	add_to_group("choppable")


## Called when the corgi hits this tree with an axe.
func chop(from_position: Vector3) -> void:
	if _felled:
		return
	_chops += 1
	if _chops >= chops_needed:
		_fall(from_position)
		return

	# Shake! Wobble back and forth.
	var shake := create_tween()
	shake.tween_property(top, "rotation:z", 0.08, 0.05)
	shake.tween_property(top, "rotation:z", -0.06, 0.08)
	shake.tween_property(top, "rotation:z", 0.0, 0.1)


func _fall(from_position: Vector3) -> void:
	_felled = true
	remove_from_group("choppable")
	collision.set_deferred("disabled", true)
	stump_top.visible = true

	# Work out which way is "away from the corgi" in the tree's own space.
	var away := global_position - from_position
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.FORWARD
	var local_away := (global_transform.basis.inverse() * away.normalized())
	local_away.y = 0.0
	local_away = local_away.normalized()
	var axis := Vector3.UP.cross(local_away).normalized()

	# Timber! Tip over, bounce, then shrink away.
	var tween := create_tween()
	# (It stops a bit short of flat so it rests on its puffy leaves.)
	var down := PI / 2.0 - 0.2
	tween.tween_method(func(angle: float) -> void: top.transform.basis = Basis(axis, angle), 0.0, down, 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(func(angle: float) -> void: top.transform.basis = Basis(axis, angle), down, down - 0.12, 0.12)
	tween.tween_method(func(angle: float) -> void: top.transform.basis = Basis(axis, angle), down - 0.12, down, 0.12)
	tween.tween_callback(_drop_wood.bind(away.normalized()))
	tween.tween_interval(0.4)
	tween.tween_property(top, "scale", Vector3.ZERO, 0.35)
	tween.tween_interval(regrow_seconds)
	tween.tween_callback(_regrow)


func _drop_wood(direction: Vector3) -> void:
	for i in wood_dropped:
		var wood := WOOD_SCENE.instantiate() as Node3D
		var side := direction.cross(Vector3.UP) * randf_range(-0.6, 0.6)
		wood.position = global_position + direction * (1.2 + i * 1.0) + side + Vector3.UP * 0.5
		get_tree().current_scene.add_child(wood)


func _regrow() -> void:
	top.transform = Transform3D.IDENTITY
	top.scale = Vector3.ZERO
	stump_top.visible = false
	collision.disabled = false
	var tween := create_tween()
	tween.tween_property(top, "scale", Vector3.ONE, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_regrow)


func _finish_regrow() -> void:
	_chops = 0
	_felled = false
	add_to_group("choppable")
