@tool
extends Node3D
## A little village cottage. Pick wall and roof materials in the Inspector
## to make each one look different.

@export var wall_material: Material:
	set(value):
		wall_material = value
		if is_node_ready():
			_apply()
@export var roof_material: Material:
	set(value):
		roof_material = value
		if is_node_ready():
			_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	for child in get_children():
		var n := String(child.name)
		var mat: Material = null
		if n.begins_with("Roof"):
			mat = roof_material
		elif n.begins_with("Wall") or n == "DoorTop":
			mat = wall_material
		elif n.begins_with("Gable"):
			if wall_material and child is MeshInstance3D:
				(child as MeshInstance3D).material_override = wall_material
			continue
		if mat and "material" in child:
			child.set("material", mat)
