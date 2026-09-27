@tool
extends StaticBody3D
## A solid block you can stand on: stone steps, walls, floors, beds...
## Change "Size" in the Inspector and the block (and its collision) resizes
## right in the editor. Set "Material" to make it wood, roof tiles, etc.
## Its origin is at the bottom, so it sits on whatever height you place it at.

@export var size := Vector3(2, 1, 2):
	set(value):
		size = value
		if is_node_ready():
			_apply()

## Leave empty for stone.
@export var material: Material:
	set(value):
		material = value
		if is_node_ready():
			_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var shape := BoxShape3D.new()
	shape.size = size
	$Mesh.mesh = mesh
	$Mesh.position = Vector3(0, size.y / 2.0, 0)
	if material:
		$Mesh.material_override = material
	$CollisionShape3D.shape = shape
	$CollisionShape3D.position = Vector3(0, size.y / 2.0, 0)
