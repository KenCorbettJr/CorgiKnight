@tool
extends StaticBody3D
## A stone block you can stand on. Change "Size" in the Inspector and the
## block (and its collision) resizes right in the editor.
## Its origin is at the bottom, so it sits on whatever height you place it at.

@export var size := Vector3(2, 1, 2):
	set(value):
		size = value
		if is_node_ready():
			_apply_size()


func _ready() -> void:
	_apply_size()


func _apply_size() -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var shape := BoxShape3D.new()
	shape.size = size
	$Mesh.mesh = mesh
	$Mesh.position = Vector3(0, size.y / 2.0, 0)
	$CollisionShape3D.shape = shape
	$CollisionShape3D.position = Vector3(0, size.y / 2.0, 0)
