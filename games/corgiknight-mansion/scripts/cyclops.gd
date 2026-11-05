extends CharacterBody3D
## A mini cyclops from the Whispering Woods.
##
## It wanders around, chases the corgi when it sees it, and when it gets
## close it raises its club high... then SMASHES it down. That hurts more
## than a slime bonk! Watch for the wind-up and get out of the way (or hit
## it first: a bonk on the head interrupts its swing).

const TOOTH_SCENE := preload("res://scenes/tooth_pickup.tscn")
const COIN_SCENE := preload("res://scenes/coin_pickup.tscn")

enum State { WANDER, CHASE, WINDUP, SWING, RECOVER, STUNNED, DEAD }

@export var max_health := 5
@export var skin_color := Color(0.55, 0.78, 0.45)
@export var walk_speed := 1.6
@export var chase_speed := 3.4
@export var chase_range := 10.0
@export var attack_range := 1.7
@export var club_damage := 2
@export var windup_seconds := 0.65
@export var wander_radius := 5.0
@export var gravity := 20.0
## Seconds before it comes back after being defeated (below 0 = never).
@export var respawn_seconds := 40.0
## How big it is, for sword reach.
@export var hit_radius := 0.35

@onready var model: Node3D = $Model
@onready var hips: Node3D = $Model/Hips
@onready var arm_r: Node3D = $Model/Hips/ArmR
@onready var arm_l: Node3D = $Model/Hips/ArmL
@onready var leg_l: Node3D = $Model/LegL
@onready var leg_r: Node3D = $Model/LegR

var health := 0
var state: State = State.WANDER
var _home := Vector3.ZERO
var _wander_target := Vector3.ZERO
var _timer := 0.0
var _walk_cycle := 0.0
var _player: Node3D
var _skin: StandardMaterial3D


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_home = global_position
	_wander_target = _home
	_timer = randf_range(0.5, 2.0)
	# Give each cyclops its own skin color (so it can flash when hit).
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		if mi.material_override and mi.material_override.resource_path.ends_with("cyclops_skin.tres"):
			if _skin == null:
				_skin = mi.material_override.duplicate() as StandardMaterial3D
				_skin.albedo_color = skin_color
			mi.material_override = _skin


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if not is_on_floor():
		velocity.y -= gravity * delta
	_timer -= delta

	var move := Vector3.ZERO
	var awake := Game.can_play()
	var to_player := Vector3.ZERO
	var distance := 999.0
	if _player:
		to_player = _player.global_position - global_position
		to_player.y = 0.0
		distance = to_player.length()

	match state:
		State.WANDER:
			var to_target := _wander_target - global_position
			to_target.y = 0.0
			if to_target.length() > 0.5:
				move = to_target.normalized() * walk_speed
			if _timer <= 0.0:
				_timer = randf_range(2.0, 4.0)
				_wander_target = _home + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * wander_radius
			if awake and distance < chase_range and absf(_player.global_position.y - global_position.y) < 3.0:
				state = State.CHASE
		State.CHASE:
			if distance > 0.1:
				move = to_player / distance * chase_speed
			if not awake or distance > chase_range * 1.6:
				state = State.WANDER
			elif distance < attack_range:
				state = State.WINDUP
				_timer = windup_seconds
		State.WINDUP:
			_face(to_player)
			if _timer <= 0.0:
				_swing()
		State.SWING:
			if _timer <= 0.0:
				state = State.RECOVER
				_timer = 0.6
		State.RECOVER:
			if _timer <= 0.0:
				state = State.CHASE
		State.STUNNED:
			if _timer <= 0.0:
				state = State.CHASE

	if state == State.STUNNED:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	else:
		velocity.x = move.x
		velocity.z = move.z
		if move.length() > 0.1:
			_face(move)
	move_and_slide()

	# Fell off the island? Walk back home.
	if global_position.y < minf(_home.y, 0.0) - 3.0:
		global_position = _home + Vector3.UP
		velocity = Vector3.ZERO

	_animate(delta, move.length())


func _face(direction: Vector3) -> void:
	if direction.length() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.x, -direction.z), 0.25)


## SMASH! Hurts the corgi if it's standing in front.
func _swing() -> void:
	state = State.SWING
	_timer = 0.25
	if _player == null or not Game.can_play():
		return
	var forward := -model.global_transform.basis.z
	forward.y = 0.0
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var in_front := to_player.length() < 0.6 or forward.normalized().dot(to_player.normalized()) > 0.3
	if to_player.length() < attack_range + 0.5 and in_front:
		_player.call("take_damage", club_damage, global_position)


## Called by the corgi's sword.
func take_hit(amount: int, from_position: Vector3) -> void:
	if state == State.DEAD:
		return
	health -= amount
	var away := global_position - from_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	velocity = away * 6.0 + Vector3.UP * 3.0
	state = State.STUNNED
	_timer = 0.45
	if _skin:
		_skin.albedo_color = Color.WHITE
		create_tween().tween_property(_skin, "albedo_color", skin_color, 0.25)
	if health <= 0:
		_die()


func _die() -> void:
	state = State.DEAD
	remove_from_group("enemies")
	collision_layer = 0
	Game.enemy_defeated(global_position)
	_drop(TOOTH_SCENE, Vector3(-0.4, 0, 0))
	_drop(COIN_SCENE, Vector3(0.4, 0, 0))
	Effects.poof(get_tree().current_scene, global_position + Vector3.UP * 0.8, Color(0.7, 0.9, 0.6), 1.0)
	var tween := create_tween()
	tween.tween_property(model, "rotation:x", -PI / 2.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.4)
	tween.tween_property(model, "scale", Vector3.ZERO, 0.3)
	if respawn_seconds < 0.0:
		tween.tween_callback(queue_free)
		return
	tween.tween_interval(respawn_seconds)
	tween.tween_callback(_respawn)


func _drop(scene: PackedScene, offset: Vector3) -> void:
	var loot := scene.instantiate() as Node3D
	loot.position = global_position + offset + Vector3.UP * 0.4
	get_tree().current_scene.add_child(loot)


func _respawn() -> void:
	global_position = _home
	velocity = Vector3.ZERO
	health = max_health
	state = State.WANDER
	model.rotation.x = 0.0
	if _skin:
		_skin.albedo_color = skin_color
	collision_layer = 4
	add_to_group("enemies")
	create_tween().tween_property(model, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- Stompy animation

func _animate(delta: float, speed: float) -> void:
	var moving := clampf(speed / chase_speed, 0.0, 1.0)
	if moving > 0.05:
		_walk_cycle += delta * (6.0 + 6.0 * moving)
	var step := sin(_walk_cycle) * 0.7 * moving
	leg_l.rotation.x = step
	leg_r.rotation.x = -step
	arm_l.rotation.x = -step * 0.6
	hips.position.y = 0.45 + absf(sin(_walk_cycle)) * 0.05 * moving
	hips.rotation.z = sin(_walk_cycle) * 0.06 * moving

	# Club: raised high during the wind-up, smashed down on the swing.
	var arm_target := 0.3
	match state:
		State.WINDUP:
			arm_target = 2.7
		State.SWING, State.RECOVER:
			arm_target = -0.3
	var arm_speed := 25.0 if state == State.SWING else 8.0
	arm_r.rotation.x = lerpf(arm_r.rotation.x, arm_target, clampf(arm_speed * delta, 0.0, 1.0))
