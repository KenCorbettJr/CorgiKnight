extends CharacterBody3D
## THE GIANT CYCLOPS. The second boss!
##
## It stomps after the corgi and has two big moves:
##  * CLUB SMASH: it raises its huge club (watch for it!) and smashes the
##    ground in front of it. Get out of the way, then hit it while it's
##    pulling its club back out of the ground.
##  * BIG STOMP: it leaps into the air and lands with a shockwave. Jump!
## At half health it gets angry (red eye, faster) and calls two mini cyclopses.

signal health_changed(current: int, maximum: int)
signal defeated

const MINION_SCENE := preload("res://scenes/cyclops.tscn")

enum State { IDLE, CHASE, WINDUP, SMASH, RECOVER, STOMP_UP, STOMP_AIR, DEAD }

@export var max_health := 30
@export var skin_color := Color(0.45, 0.62, 0.4)
@export var angry_color := Color(0.8, 0.4, 0.35)
@export var walk_speed := 2.4
@export var smash_range := 3.4
@export var smash_damage := 3
@export var smash_radius := 2.3
@export var stomp_damage := 2
@export var stomp_radius := 5.0
@export var stomp_height := 11.0
@export var windup_seconds := 1.0
@export var recover_seconds := 1.2
@export var gravity := 20.0
## How big it is, for sword reach.
@export var hit_radius := 1.1

@onready var model: Node3D = $Model
@onready var hips: Node3D = $Model/Hips
@onready var arm_r: Node3D = $Model/Hips/ArmR
@onready var arm_l: Node3D = $Model/Hips/ArmL
@onready var leg_l: Node3D = $Model/LegL
@onready var leg_r: Node3D = $Model/LegR
@onready var pupil: MeshInstance3D = $Model/Hips/Head/Pupil

var health := 0
var state: State = State.IDLE
var _timer := 0.0
var _attacks := 0
var _far_time := 0.0
var _angry := false
var _invincible_time := 0.0
var _walk_cycle := 0.0
var _told_about_stomp := false
var _player: Node3D
var _skin: StandardMaterial3D
var _arena_center := Vector3.ZERO


func _ready() -> void:
	health = max_health
	_arena_center = global_position
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		if mi.material_override and mi.material_override.resource_path.ends_with("cyclops_skin.tres"):
			if _skin == null:
				_skin = mi.material_override.duplicate() as StandardMaterial3D
				_skin.albedo_color = skin_color
			mi.material_override = _skin


## Start the fight!
func activate() -> void:
	state = State.CHASE
	add_to_group("enemies")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= gravity * delta
	_timer -= delta
	_invincible_time -= delta

	var awake := Game.can_play()
	var to_player := Vector3.ZERO
	var distance := 999.0
	if _player:
		to_player = _player.global_position - global_position
		to_player.y = 0.0
		distance = to_player.length()
	var speed_boost := 1.35 if _angry else 1.0
	var move := Vector3.ZERO

	match state:
		State.CHASE:
			if awake and distance > 0.1:
				move = to_player / distance * walk_speed * speed_boost
				_face(to_player, 0.1)
				_far_time = _far_time + delta if distance > 8.0 else 0.0
				if distance < smash_range:
					state = State.WINDUP
					_timer = windup_seconds / speed_boost
				elif _far_time > 2.5 or (_attacks > 0 and _attacks % 3 == 0):
					_start_stomp(to_player, distance)
		State.WINDUP:
			_face(to_player, 0.08)
			if _timer <= 0.0:
				_smash()
		State.SMASH:
			if _timer <= 0.0:
				state = State.RECOVER
				_timer = recover_seconds / speed_boost
		State.RECOVER:
			if _timer <= 0.0:
				state = State.CHASE
		State.STOMP_UP:
			state = State.STOMP_AIR
		State.STOMP_AIR:
			if on_floor and velocity.y <= 0.0:
				_land_stomp()

	if state == State.STOMP_AIR or state == State.STOMP_UP:
		pass  # keep flying in the direction of the leap
	else:
		velocity.x = move.x
		velocity.z = move.z
	move_and_slide()

	if global_position.y < -3.0:
		global_position = _arena_center + Vector3.UP * 2.0
		velocity = Vector3.ZERO

	_animate(delta, move.length())


func _face(direction: Vector3, amount: float) -> void:
	if direction.length() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.x, -direction.z), amount)


## The club comes crashing down in front of the Giant Cyclops.
func _smash() -> void:
	state = State.SMASH
	_timer = 0.3
	_attacks += 1
	var forward := -model.global_transform.basis.z
	forward.y = 0.0
	var impact := global_position + forward.normalized() * 2.4
	Effects.shockwave(get_tree().current_scene, impact, Color(0.9, 0.8, 0.5, 0.8), smash_radius)
	if _player and Game.can_play():
		var to_impact := _player.global_position - impact
		to_impact.y = 0.0
		if to_impact.length() < smash_radius:
			_player.call("take_damage", smash_damage, global_position)


func _start_stomp(to_player: Vector3, distance: float) -> void:
	state = State.STOMP_UP
	_attacks += 1
	_far_time = 0.0
	var air_time := 2.0 * stomp_height / gravity
	var direction := to_player / maxf(distance, 0.1)
	velocity = direction * minf(distance / air_time, 9.0)
	velocity.y = stomp_height
	model.scale = Vector3(1.2, 0.8, 1.2) * 2.6


func _land_stomp() -> void:
	state = State.RECOVER
	_timer = recover_seconds * 0.8
	model.scale = Vector3(1.25, 0.75, 1.25) * 2.6
	Effects.shockwave(get_tree().current_scene, global_position, Color(0.9, 0.8, 0.5, 0.8), stomp_radius)
	if _player and Game.can_play():
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		var body := _player as CharacterBody3D
		if to_player.length() < stomp_radius and body and body.is_on_floor():
			_player.call("take_damage", stomp_damage, global_position)
	if not _told_about_stomp:
		_told_about_stomp = true
		Game.message.emit("Jump over the stomp shockwave!")


## Called by the corgi's sword.
func take_hit(amount: int, _from_position: Vector3) -> void:
	if state == State.DEAD or state == State.IDLE or _invincible_time > 0.0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	_invincible_time = 0.3
	if _skin:
		_skin.albedo_color = Color.WHITE
		create_tween().tween_property(_skin, "albedo_color", angry_color if _angry else skin_color, 0.2)
	if health <= 0:
		_die()
	elif not _angry and health <= max_health / 2:
		_get_angry()


func _get_angry() -> void:
	_angry = true
	Game.message.emit("The Giant Cyclops is furious!")
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.9, 0.1, 0.1)
	red.emission_enabled = true
	red.emission = Color(1, 0.1, 0.1)
	pupil.material_override = red
	for side: float in [-1.0, 1.0]:
		var minion := MINION_SCENE.instantiate() as Node3D
		minion.set("respawn_seconds", -1.0)
		minion.set("chase_range", 30.0)
		minion.set("skin_color", Color(0.75, 0.6, 0.4))
		minion.add_to_group("boss_minions")
		minion.position = global_position + model.global_transform.basis.x.normalized() * side * 3.0 + Vector3.UP
		get_tree().current_scene.add_child(minion)
		Effects.poof(get_tree().current_scene, minion.position, Color(0.7, 0.4, 1.0), 1.0)


func _die() -> void:
	state = State.DEAD
	remove_from_group("enemies")
	collision_layer = 0
	var tween := create_tween()
	for i in 3:
		tween.tween_property(model, "rotation:z", 0.15, 0.1)
		tween.tween_property(model, "rotation:z", -0.15, 0.1)
	tween.tween_property(model, "rotation:x", -PI / 2.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: Effects.shockwave(get_tree().current_scene, global_position, Color(1, 1, 0.8, 0.8), 5.0))
	tween.tween_interval(0.6)
	tween.tween_callback(func() -> void: Effects.poof(get_tree().current_scene, global_position + Vector3.UP * 2.0, Color(0.75, 0.5, 1.0), 3.0, 28))
	tween.tween_property(model, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(_drop_treasure)
	tween.tween_callback(func() -> void: defeated.emit())


func _drop_treasure() -> void:
	var heart_scene := load("res://scenes/heart_pickup.tscn") as PackedScene
	var tooth_scene := load("res://scenes/tooth_pickup.tscn") as PackedScene
	for i in 8:
		var scene := heart_scene if i % 2 == 0 else tooth_scene
		var loot := scene.instantiate() as Node3D
		var angle := TAU * i / 8.0
		loot.position = global_position + Vector3(cos(angle) * 2.0, 0.5, sin(angle) * 2.0)
		get_tree().current_scene.add_child(loot)
	Game.add_coins(100)
	Game.message.emit("+100 coins!")


# ---------------------------------------------------------------- Stompy animation

func _animate(delta: float, speed: float) -> void:
	var moving := clampf(speed / walk_speed, 0.0, 1.0)
	if moving > 0.05:
		_walk_cycle += delta * 5.0
	var step := sin(_walk_cycle) * 0.6 * moving
	leg_l.rotation.x = step
	leg_r.rotation.x = -step
	arm_l.rotation.x = -step * 0.5
	hips.rotation.z = sin(_walk_cycle) * 0.05 * moving
	model.scale = model.scale.lerp(Vector3.ONE * 2.6, clampf(6.0 * delta, 0.0, 1.0))

	var arm_target := 0.3
	match state:
		State.WINDUP:
			arm_target = 2.8
		State.SMASH, State.RECOVER:
			arm_target = -0.35
		State.STOMP_UP, State.STOMP_AIR:
			arm_target = 1.6
	var arm_speed := 20.0 if state == State.SMASH else 5.0
	arm_r.rotation.x = lerpf(arm_r.rotation.x, arm_target, clampf(arm_speed * delta, 0.0, 1.0))
