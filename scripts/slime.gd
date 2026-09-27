extends CharacterBody3D
## A bouncy little slime.
##
## It hops around near its home spot. When the corgi gets close, it hops
## toward it and bonks it. Three sword hits and it goes *poof*.

signal died(slime: Node3D)

const JELLY_SCENE := preload("res://scenes/jelly_pickup.tscn")

@export var max_health := 3
@export var body_color := Color(0.45, 0.85, 0.35)
@export var hop_speed := 3.0
@export var hop_height := 5.0
@export var chase_range := 9.0
@export var wander_radius := 5.0
@export var contact_damage := 1
@export var gravity := 20.0
## Seconds before a bonked slime comes back (so there's always more jelly).
@export var respawn_seconds := 25.0

@onready var model: Node3D = $Model
@onready var body_mesh: MeshInstance3D = $Model/Body

var health := 0
var _home := Vector3.ZERO
var _hop_timer := 0.0
var _stun_time := 0.0
var _dead := false
var _material: StandardMaterial3D
var _player: Node3D


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_home = global_position
	_hop_timer = randf_range(0.3, 1.5)
	# Give each slime its own copy of the material so they can have
	# different colors and flash white separately when hit.
	_material = body_mesh.material_override.duplicate() as StandardMaterial3D
	_material.albedo_color = body_color
	body_mesh.material_override = _material


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D

	_stun_time -= delta

	if is_on_floor():
		# Slimes are sticky: they stop sliding when they land.
		velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
		if _stun_time <= 0.0:
			_hop_timer -= delta
			if _hop_timer <= 0.0:
				_hop()
	else:
		velocity.y -= gravity * delta

	move_and_slide()

	# Bonk the corgi if we touch it.
	if _player and _stun_time <= 0.0 and global_position.distance_to(_player.global_position) < 0.95:
		if _player.has_method("take_damage"):
			_player.call("take_damage", contact_damage, global_position)

	# Squash and stretch: tall when flying up, flat when landing.
	var stretch := clampf(velocity.y * 0.045, -0.3, 0.35)
	var target_scale := Vector3(1.0 - stretch * 0.5, 1.0 + stretch, 1.0 - stretch * 0.5)
	model.scale = model.scale.lerp(target_scale, clampf(12.0 * delta, 0.0, 1.0))

	# Fell off the island? Pop back home.
	if global_position.y < -2.0:
		global_position = _home + Vector3.UP
		velocity = Vector3.ZERO
	# Knocked far away from home (like off the lookout)? Wobble back home.
	elif global_position.distance_to(_home) > wander_radius + chase_range * 2.0:
		global_position = _home + Vector3.UP
		velocity = Vector3.ZERO


func _hop() -> void:
	var direction := Vector3.ZERO
	var chasing := _player != null and global_position.distance_to(_player.global_position) < chase_range
	# Don't leap off a ledge after a corgi that's far below. Make it climb up!
	if chasing and _player.global_position.y < global_position.y - 1.0:
		chasing = false

	if chasing:
		direction = _player.global_position - global_position
		_hop_timer = randf_range(0.45, 0.8)
	else:
		var to_home := _home - global_position
		to_home.y = 0.0
		if to_home.length() > wander_radius:
			direction = to_home
		else:
			direction = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		_hop_timer = randf_range(1.0, 2.5)

	direction.y = 0.0
	direction = direction.normalized()
	var boost := 1.3 if chasing else 1.0
	velocity = direction * hop_speed * boost
	velocity.y = hop_height * (1.0 if chasing else 0.75)
	if direction.length() > 0.1:
		model.rotation.y = atan2(-direction.x, -direction.z)
	model.scale = Vector3(1.35, 0.65, 1.35)  # squish down before the jump


## Called by the corgi's sword.
func take_hit(amount: int, from_position: Vector3) -> void:
	if _dead:
		return
	health -= amount

	var away := global_position - from_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	velocity = away * 7.0 + Vector3.UP * 4.5
	_stun_time = 0.6
	_hop_timer = 0.6

	# Flash white.
	_material.albedo_color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(_material, "albedo_color", body_color, 0.25)

	if health <= 0:
		_die()


func _die() -> void:
	_dead = true
	remove_from_group("enemies")
	collision_layer = 0
	died.emit(self)
	_drop_jelly()
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3(1.7, 0.2, 1.7), 0.12)
	tween.tween_property(model, "scale", Vector3.ZERO, 0.18)
	tween.tween_interval(respawn_seconds)
	tween.tween_callback(_respawn)


func _drop_jelly() -> void:
	var jelly := JELLY_SCENE.instantiate() as Node3D
	jelly.set("color", body_color)
	jelly.position = global_position + Vector3.UP * 0.3
	get_tree().current_scene.add_child(jelly)


func _respawn() -> void:
	global_position = _home
	velocity = Vector3.ZERO
	health = max_health
	_stun_time = 0.0
	_hop_timer = 1.0
	_material.albedo_color = body_color
	collision_layer = 4
	add_to_group("enemies")
	_dead = false
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
