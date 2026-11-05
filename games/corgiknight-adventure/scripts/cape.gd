extends EquipmentItem
## A cape that hangs from the corgi's shoulders, drapes out over its fluffy
## tail, and flies out behind it the faster it runs.

## How far the cape flares out when standing still (radians). Big enough to
## clear the tail.
@export var rest_flare := 0.6
## Extra flare at full sprint.
@export var run_flare := 0.45

@onready var cloth: Node3D = $Cloth

var _time := 0.0
var _player: CharacterBody3D


func _process(delta: float) -> void:
	_time += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	var speed := 0.0
	if _player:
		speed = Vector2(_player.velocity.x, _player.velocity.z).length()
	var flow := clampf(speed / 8.0, 0.0, 1.0)
	var flutter := sin(_time * (4.0 + flow * 8.0)) * (0.02 + flow * 0.08)
	# Negative = the bottom of the cape swings out behind the corgi.
	var target := -(rest_flare + flow * run_flare + flutter)
	cloth.rotation.x = lerpf(cloth.rotation.x, target, clampf(10.0 * delta, 0.0, 1.0))
