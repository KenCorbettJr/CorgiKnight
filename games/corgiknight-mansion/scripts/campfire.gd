extends Node3D
## A cozy flickering campfire.

@onready var flame: Node3D = $Flame
@onready var light: OmniLight3D = $Light

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	var flicker := sin(_time * 13.0) * 0.5 + sin(_time * 7.3) * 0.5
	light.light_energy = 2.2 + flicker * 0.5
	flame.scale = Vector3(1.0, 1.0 + flicker * 0.12, 1.0)
