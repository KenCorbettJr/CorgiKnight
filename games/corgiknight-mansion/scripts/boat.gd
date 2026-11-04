extends Node3D
## A little sailboat that bobs gently on the waves.

var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 1.5) * 0.06
	rotation.z = sin(_time * 1.1) * 0.04
	rotation.x = sin(_time * 0.8) * 0.02
