extends CharacterBody3D
## The CorgiKnight!
##
## Handles running, jumping, the free-roaming camera, swinging the sword,
## taking damage, and equipment. The walk / attack animations are done in
## code (legs stepping, arms swinging, waddling, squash-and-stretch) so they
## work with simple shapes. Later you can swap the Model for a real animated
## 3D corgi and keep the attachment points.

signal health_changed(current: int, maximum: int)
signal equipment_changed

# --- Movement (try changing these in the Inspector!) ---
@export var walk_speed := 5.0
@export var sprint_speed := 8.5
@export var acceleration := 12.0
@export var jump_velocity := 7.0
@export var gravity := 20.0

# --- Health & combat ---
@export var max_health := 5
@export var invincible_seconds := 1.2
## Damage and reach when the corgi has no weapon (a paw swipe).
@export var base_damage := 1
@export var base_reach := 1.2
## The weapon the corgi starts with. The corgi starts with no armor.
@export var starting_weapon: PackedScene

# --- Camera ---
@export var mouse_sensitivity := 0.003
@export var stick_sensitivity := 3.0

const ARM_REST_ANGLE := 0.35
const FALL_LIMIT := -2.0

@onready var model: Node3D = $Model
@onready var hips: Node3D = $Model/Hips
@onready var arm_l: Node3D = $Model/Hips/ArmL
@onready var arm_r: Node3D = $Model/Hips/ArmR
@onready var leg_l: Node3D = $Model/LegL
@onready var leg_r: Node3D = $Model/LegR
@onready var tail: Node3D = $Model/Hips/Tail
@onready var camera_rig: Node3D = $CameraRig
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D

## Attachment points for equipment. "feet" has two (one boot per foot).
@onready var sockets := {
	"head": [$Model/Hips/Head/HeadSocket],
	"chest": [$Model/Hips/ChestSocket],
	"back": [$Model/Hips/BackSocket],
	"shield": [$Model/Hips/ArmL/HandLSocket],
	"weapon": [$Model/Hips/ArmR/HandRSocket],
	"feet": [$Model/LegL/FootLSocket, $Model/LegR/FootRSocket],
}

var health := 0
var spawn_point := Vector3.ZERO
## What the corgi is wearing right now: slot name -> EquipmentItem.
var equipped := {}

var _attacking := false
var _arm_busy := false
var _attack_cooldown := 0.0
var _hit_this_swing: Array = []
var _invincible_time := 0.0
var _stun_time := 0.0
var _walk_cycle := 0.0
var _was_on_floor := true
var _tail_phase := 0.0
var _just_grabbed_mouse := false


func _ready() -> void:
	add_to_group("player")
	health = max_health
	spawn_point = global_position
	# The camera rig follows the corgi but doesn't spin when the corgi turns.
	camera_rig.top_level = true
	camera_rig.global_position = global_position + Vector3(0, 1.0, 0)
	spring_arm.add_excluded_object(get_rid())
	arm_r.rotation.x = ARM_REST_ANGLE
	if starting_weapon:
		equip(starting_weapon)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_rotate_camera(-motion.relative.x * mouse_sensitivity, -motion.relative.y * mouse_sensitivity)
	elif event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
		# Esc frees the mouse so you can click on other windows.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Click the game window to grab the mouse again (without swinging the sword).
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_just_grabbed_mouse = true


func _rotate_camera(yaw: float, pitch: float) -> void:
	camera_rig.rotate_y(yaw)
	spring_arm.rotation.x = clampf(spring_arm.rotation.x + pitch, deg_to_rad(-70.0), deg_to_rad(20.0))


func _physics_process(delta: float) -> void:
	_invincible_time -= delta
	_stun_time -= delta
	_attack_cooldown -= delta

	# Look around with a controller's right stick.
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		_rotate_camera(-look.x * stick_sensitivity * delta, -look.y * stick_sensitivity * delta)

	# Gravity pulls us down when we're in the air.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump!
	if Input.is_action_just_pressed("jump") and is_on_floor() and _stun_time <= 0.0:
		velocity.y = jump_velocity
		_squash(Vector3(0.8, 1.25, 0.8))

	# Move relative to where the camera is looking.
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := camera_rig.global_transform.basis * Vector3(input.x, 0.0, input.y)
	direction.y = 0.0

	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	if _attacking:
		speed *= 0.5

	var target := direction * speed
	var control := acceleration
	if _stun_time > 0.0:
		# Just got bonked: slide back and ignore the controls for a moment.
		target = Vector3.ZERO
		control = 2.0
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).lerp(target, clampf(control * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()

	# Turn the corgi to face the way it's running.
	if direction.length() > 0.1 and _stun_time <= 0.0:
		var target_yaw := atan2(-direction.x, -direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, clampf(12.0 * delta, 0.0, 1.0))

	# Sword
	var wants_attack := Input.is_action_just_pressed("attack") and not _just_grabbed_mouse
	if wants_attack and _attack_cooldown <= 0.0 and _stun_time <= 0.0:
		_start_attack()
	_just_grabbed_mouse = false
	if _attacking:
		_check_sword_hits()

	# Fell into the water? Back to the start.
	if global_position.y < FALL_LIMIT:
		_fell_in_water()

	# Camera smoothly follows the corgi.
	var follow_target := global_position + Vector3(0, 1.0, 0)
	camera_rig.global_position = camera_rig.global_position.lerp(follow_target, clampf(10.0 * delta, 0.0, 1.0))


func _process(delta: float) -> void:
	_animate(delta)


# ---------------------------------------------------------------- Equipment

## Put on an item (a scene whose root has the EquipmentItem script).
## Anything already in that slot is taken off first.
func equip(item_scene: PackedScene) -> void:
	var item := item_scene.instantiate() as EquipmentItem
	if item == null:
		push_warning("equip(): that scene's root node needs the equipment_item.gd script.")
		return
	if not sockets.has(item.slot):
		push_warning("equip(): unknown slot '%s'." % item.slot)
		item.queue_free()
		return
	unequip(item.slot)
	var targets: Array = sockets[item.slot]
	for i in targets.size():
		# Boots need one copy per foot; everything else uses the first copy.
		var piece: Node = item
		if i > 0:
			piece = item_scene.instantiate()
		(targets[i] as Node3D).add_child(piece)
	equipped[item.slot] = item
	equipment_changed.emit()


## Take off whatever is in a slot ("head", "chest", "back", "shield", "weapon" or "feet").
func unequip(slot: String) -> void:
	if not sockets.has(slot):
		return
	for socket in sockets[slot]:
		for child in (socket as Node3D).get_children():
			child.queue_free()
	equipped.erase(slot)
	equipment_changed.emit()


func get_attack_damage() -> int:
	var weapon: EquipmentItem = equipped.get("weapon")
	return base_damage + (weapon.damage if weapon else 0)


func get_attack_reach() -> float:
	var weapon: EquipmentItem = equipped.get("weapon")
	return weapon.reach if weapon else base_reach


func get_defense() -> int:
	var total := 0
	for item in equipped.values():
		total += (item as EquipmentItem).defense
	return total


# ---------------------------------------------------------------- Sword

func _start_attack() -> void:
	_attack_cooldown = 0.45
	_hit_this_swing.clear()
	_arm_busy = true
	var tween := create_tween()
	# Raise the sword overhead, CHOP, then return to resting.
	tween.tween_property(arm_r, "rotation:x", 2.8, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _attacking = true)
	tween.tween_property(arm_r, "rotation:x", -0.4, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _attacking = false)
	tween.tween_property(arm_r, "rotation:x", ARM_REST_ANGLE, 0.18)
	tween.tween_callback(func() -> void: _arm_busy = false)
	_squash(Vector3(1.1, 0.92, 1.1))


func _check_sword_hits() -> void:
	var forward := -model.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var reach := get_attack_reach()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy in _hit_this_swing or not (enemy is Node3D):
			continue
		var to_enemy: Vector3 = (enemy as Node3D).global_position - global_position
		if absf(to_enemy.y) > 1.5:
			continue
		to_enemy.y = 0.0
		var distance := to_enemy.length()
		var in_front := distance < 0.6 or forward.dot(to_enemy / distance) > 0.2
		if distance <= reach and in_front:
			_hit_this_swing.append(enemy)
			if enemy.has_method("take_hit"):
				enemy.take_hit(get_attack_damage(), global_position)


# ---------------------------------------------------------------- Health

func take_damage(amount: int, from_position: Vector3) -> void:
	if _invincible_time > 0.0 or health <= 0:
		return
	# Armor blocks some damage, but a hit always hurts at least a little.
	var final_damage := maxi(amount - get_defense(), 1)
	health = maxi(health - final_damage, 0)
	health_changed.emit(health, max_health)

	# Knockback away from whatever hit us.
	var away := global_position - from_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	velocity = away * 9.0 + Vector3.UP * 4.0
	_stun_time = 0.3
	_invincible_time = invincible_seconds

	if health <= 0:
		_respawn()


func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


func _fell_in_water() -> void:
	health = maxi(health - 1, 0)
	if health <= 0:
		_respawn()
		return
	health_changed.emit(health, max_health)
	global_position = spawn_point
	velocity = Vector3.ZERO
	_invincible_time = invincible_seconds


func _respawn() -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO
	health = max_health
	_invincible_time = invincible_seconds
	health_changed.emit(health, max_health)


# ---------------------------------------------------------------- Cute animation

func _squash(amount: Vector3) -> void:
	model.scale = amount


func _animate(delta: float) -> void:
	var speed_ratio := Vector2(velocity.x, velocity.z).length() / sprint_speed
	var moving := clampf(speed_ratio * 2.0, 0.0, 1.0)
	var on_floor := is_on_floor()
	var smooth := clampf(15.0 * delta, 0.0, 1.0)

	# Stubby legs pitter-patter faster the faster we run.
	if on_floor and speed_ratio > 0.05:
		_walk_cycle += delta * (9.0 + 12.0 * speed_ratio)
	var step := sin(_walk_cycle) * 0.9 * moving

	if on_floor:
		leg_l.rotation.x = lerpf(leg_l.rotation.x, step, smooth)
		leg_r.rotation.x = lerpf(leg_r.rotation.x, -step, smooth)
		arm_l.rotation.z = lerpf(arm_l.rotation.z, 0.0, smooth)
		arm_r.rotation.z = lerpf(arm_r.rotation.z, 0.0, smooth)
	else:
		# Mid-jump: one leg tucked, arms flung out. Wheee!
		leg_l.rotation.x = lerpf(leg_l.rotation.x, -0.6, smooth)
		leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.4, smooth)
		arm_l.rotation.z = lerpf(arm_l.rotation.z, -0.9, smooth)
		arm_r.rotation.z = lerpf(arm_r.rotation.z, 0.9, smooth)

	# Arms swing opposite to the legs (the sword arm only when not attacking).
	arm_l.rotation.x = lerpf(arm_l.rotation.x, -step * 0.8, smooth)
	if not _arm_busy:
		arm_r.rotation.x = lerpf(arm_r.rotation.x, ARM_REST_ANGLE + step * 0.5, smooth)

	# Waddle side to side and bounce while running.
	hips.rotation.z = sin(_walk_cycle) * 0.1 * moving
	hips.position.y = 0.3 + absf(sin(_walk_cycle)) * 0.04 * moving

	# Tail never stops wagging. Wags faster when running.
	_tail_phase += delta * (15.0 + 20.0 * speed_ratio)
	tail.rotation.y = sin(_tail_phase) * 0.6

	# Squash-and-stretch springs back to normal.
	model.scale = model.scale.lerp(Vector3.ONE, clampf(10.0 * delta, 0.0, 1.0))
	if on_floor and not _was_on_floor:
		_squash(Vector3(1.2, 0.8, 1.2))  # landing plop
	_was_on_floor = on_floor

	# Blink while invincible after getting hit.
	if _invincible_time > 0.0:
		model.visible = int(_invincible_time * 15.0) % 2 == 0
	else:
		model.visible = true
