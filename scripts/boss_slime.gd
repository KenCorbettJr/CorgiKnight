extends CharacterBody3D
## THE KING SLIME. The first boss!
##
## It hops after the corgi. Every few hops it leaps high into the air and
## SLAMS down, sending out a shockwave: jump to dodge it! When it's down to
## half health it gets angry (turns red, hops faster) and calls in two
## little slimes to help.

signal health_changed(current: int, maximum: int)
signal defeated

const MINION_SCENE := preload("res://scenes/slime.tscn")

@export var max_health := 16
@export var body_color := Color(0.35, 0.3, 0.9)
@export var angry_color := Color(0.9, 0.25, 0.3)
@export var hop_speed := 4.5
@export var hop_height := 6.0
@export var slam_height := 12.0
@export var slam_every := 3
@export var shockwave_radius := 4.5
@export var contact_damage := 2
@export var gravity := 20.0
## How big the King Slime is, for sword reach (the corgi can hit it from farther away).
@export var hit_radius := 1.2

@onready var model: Node3D = $Model
@onready var body_mesh: MeshInstance3D = $Model/Body

var health := 0
var active := false
var _hops := 0
var _hop_timer := 1.0
var _stun_time := 0.0
var _invincible_time := 0.0
var _slamming := false
var _angry := false
var _dead := false
var _told_about_jumping := false
var _was_on_floor := true
var _material: StandardMaterial3D
var _player: Node3D
var _arena_center := Vector3.ZERO


func _ready() -> void:
	health = max_health
	_arena_center = global_position
	_material = body_mesh.material_override.duplicate() as StandardMaterial3D
	_material.albedo_color = body_color
	body_mesh.material_override = _material


## Start the fight!
func activate() -> void:
	active = true
	add_to_group("enemies")
	_hop_timer = 1.0


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D

	_stun_time -= delta
	_invincible_time -= delta

	var on_floor := is_on_floor()
	if on_floor:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		if not _was_on_floor and _slamming:
			_land_slam()
		if active and _stun_time <= 0.0 and Game.can_play():
			_hop_timer -= delta
			if _hop_timer <= 0.0:
				_hop()
	else:
		velocity.y -= gravity * delta
	_was_on_floor = on_floor

	move_and_slide()

	# Squished corgi! Touching the King Slime hurts.
	if active and _player and _stun_time <= 0.0 and Game.can_play():
		var to_player := _player.global_position - global_position
		to_player.y *= 0.5
		if to_player.length() < hit_radius + 0.35:
			_player.call("take_damage", contact_damage, global_position)

	# Squash and stretch, just like the little slimes (but bigger).
	var stretch := clampf(velocity.y * 0.03, -0.25, 0.3)
	var target_scale := Vector3(1.0 - stretch * 0.5, 1.0 + stretch, 1.0 - stretch * 0.5)
	model.scale = model.scale.lerp(target_scale, clampf(10.0 * delta, 0.0, 1.0))

	# Fell in the water? Back to the middle of the fight.
	if global_position.y < -3.0:
		global_position = _arena_center + Vector3.UP * 2.0
		velocity = Vector3.ZERO


func _hop() -> void:
	if _player == null:
		return
	_hops += 1
	var direction := _player.global_position - global_position
	direction.y = 0.0
	var distance := direction.length()
	direction = direction.normalized()
	model.rotation.y = atan2(-direction.x, -direction.z)

	var speed_boost := 1.35 if _angry else 1.0
	if _hops % slam_every == 0:
		# BIG JUMP aimed right at the corgi.
		_slamming = true
		var air_time := 2.0 * slam_height / gravity
		velocity = direction * minf(distance / air_time, hop_speed * 2.0)
		velocity.y = slam_height
		model.scale = Vector3(1.4, 0.6, 1.4)
		_hop_timer = 1.6 / speed_boost
	else:
		velocity = direction * hop_speed * speed_boost
		velocity.y = hop_height
		model.scale = Vector3(1.25, 0.75, 1.25)
		_hop_timer = randf_range(0.7, 1.1) / speed_boost


func _land_slam() -> void:
	_slamming = false
	model.scale = Vector3(1.5, 0.5, 1.5)
	Effects.shockwave(get_tree().current_scene, global_position, Color(1, 0.6, 1, 0.8), shockwave_radius)
	if _player == null:
		return
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var player_body := _player as CharacterBody3D
	var grounded := player_body != null and player_body.is_on_floor()
	if to_player.length() < shockwave_radius and grounded and Game.can_play():
		_player.call("take_damage", contact_damage, global_position)
	if not _told_about_jumping:
		_told_about_jumping = true
		Game.message.emit("Jump to dodge the shockwave!")


## Called by the corgi's sword.
func take_hit(amount: int, from_position: Vector3) -> void:
	if _dead or not active or _invincible_time > 0.0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	_invincible_time = 0.3
	_stun_time = 0.35

	# A little wobble back (it's too heavy to fly far).
	var away := global_position - from_position
	away.y = 0.0
	if away.length() > 0.01 and is_on_floor():
		velocity = away.normalized() * 3.0 + Vector3.UP * 2.0

	# Flash white.
	var color := angry_color if _angry else body_color
	_material.albedo_color = Color.WHITE
	create_tween().tween_property(_material, "albedo_color", color, 0.2)

	if health <= 0:
		_die()
	elif not _angry and health <= max_health / 2:
		_get_angry()


func _get_angry() -> void:
	_angry = true
	Game.message.emit("The King Slime is getting angry!")
	create_tween().tween_property(_material, "albedo_color", angry_color, 0.5)
	# Call for help!
	for side: float in [-1.0, 1.0]:
		var minion := MINION_SCENE.instantiate() as Node3D
		minion.set("respawn_seconds", -1.0)
		minion.set("body_color", Color(0.55, 0.45, 1.0))
		minion.set("chase_range", 30.0)
		var offset := global_transform.basis.x * side * 2.5
		minion.position = global_position + offset + Vector3.UP * 1.0
		minion.add_to_group("boss_minions")
		get_tree().current_scene.add_child(minion)
		Effects.poof(get_tree().current_scene, minion.position, Color(0.7, 0.4, 1.0), 0.8)


func _die() -> void:
	_dead = true
	active = false
	remove_from_group("enemies")
	collision_layer = 0
	var tween := create_tween()
	# Wobble, wobble... SPLAT!
	for i in 3:
		tween.tween_property(model, "scale", Vector3(1.3, 0.7, 1.3), 0.12)
		tween.tween_property(model, "scale", Vector3(0.8, 1.2, 0.8), 0.12)
	tween.tween_callback(func() -> void: Effects.poof(get_tree().current_scene, global_position + Vector3.UP, Color(0.75, 0.5, 1.0), 2.5, 24))
	tween.tween_property(model, "scale", Vector3(2.0, 0.1, 2.0), 0.15)
	tween.tween_property(model, "scale", Vector3.ZERO, 0.2)
	tween.tween_callback(_drop_treasure)
	tween.tween_callback(func() -> void: defeated.emit())


## Drops a pile of jelly and coins' worth of goodies.
func _drop_treasure() -> void:
	var jelly_scene := load("res://scenes/jelly_pickup.tscn") as PackedScene
	for i in 6:
		var jelly := jelly_scene.instantiate() as Node3D
		jelly.set("color", Color(0.6, 0.5, 1.0))
		var angle := TAU * i / 6.0
		jelly.position = global_position + Vector3(cos(angle), 0.5, sin(angle)) * 1.8
		get_tree().current_scene.add_child(jelly)
	# And hearts to heal up after the big fight.
	var heart_scene := load("res://scenes/heart_pickup.tscn") as PackedScene
	for i in 3:
		var heart := heart_scene.instantiate() as Node3D
		var angle := TAU * i / 3.0 + 0.5
		heart.position = global_position + Vector3(cos(angle) * 1.0, 0.5, sin(angle) * 1.0)
		get_tree().current_scene.add_child(heart)
	Game.add_coins(50)
	Game.message.emit("+50 coins!")
