extends Node3D
## The evil Corgiwizard! He floats, cackles, waves his glowing staff,
## and vanishes in a puff of purple smoke.

@export var fur_color := Color(0.36, 0.32, 0.42)

@onready var model: Node3D = $Model
@onready var arm_r: Node3D = $Model/Hips/ArmR
@onready var arm_l: Node3D = $Model/Hips/ArmL

var _time := 0.0
var _laughing := false
var _staff_up := false


func _ready() -> void:
	visible = false
	# Robe hides his legs; he floats instead of walking.
	($Model/LegL as Node3D).visible = false
	($Model/LegR as Node3D).visible = false
	var fur: StandardMaterial3D = null
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		if mi.material_override and mi.material_override.resource_path.ends_with("corgi_orange.tres"):
			if fur == null:
				fur = mi.material_override.duplicate() as StandardMaterial3D
				fur.albedo_color = fur_color
			mi.material_override = fur


func _process(delta: float) -> void:
	_time += delta
	# Spooky floating.
	model.position.y = 0.5 + sin(_time * 2.0) * 0.12
	# Cackling shakes his whole body.
	model.rotation.z = sin(_time * 40.0) * 0.07 if _laughing else lerpf(model.rotation.z, 0.0, 0.2)
	var arm_target := 2.9 if _staff_up else 0.4
	arm_r.rotation.x = lerpf(arm_r.rotation.x, arm_target, clampf(8.0 * delta, 0.0, 1.0))
	arm_l.rotation.z = lerpf(arm_l.rotation.z, -0.9 if _laughing else 0.0, clampf(8.0 * delta, 0.0, 1.0))


## Poof! He appears out of nowhere.
func appear() -> void:
	visible = true
	scale = Vector3.ZERO
	Effects.poof(get_tree().current_scene, global_position + Vector3.UP, Color(0.6, 0.25, 0.9), 1.5, 16)
	create_tween().tween_property(self, "scale", Vector3.ONE * 1.15, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_laughing(on: bool) -> void:
	_laughing = on


func set_staff_raised(on: bool) -> void:
	_staff_up = on


## Turn to look at something.
func face(point: Vector3) -> void:
	var to := point - global_position
	model.rotation.y = atan2(-to.x, -to.z) - global_rotation.y


## Poof! Gone.
func vanish() -> void:
	Effects.poof(get_tree().current_scene, global_position + Vector3.UP, Color(0.6, 0.25, 0.9), 1.5, 16)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.25)
	tween.tween_callback(func() -> void: visible = false)
