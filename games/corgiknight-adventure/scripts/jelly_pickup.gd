extends "res://scripts/pickup.gd"
## A wobbly blob of Slime Jelly, tinted the same color as the slime that dropped it.

@export var color := Color(0.45, 0.85, 0.35)


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.emission_enabled = true
	mat.emission = color * 0.35
	($Visual as MeshInstance3D).material_override = mat
	super()
