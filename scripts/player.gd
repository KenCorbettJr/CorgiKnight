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
## Emitted when something you can talk to / use comes in or out of range.
signal interact_target_changed(target: Node3D)
## Emitted when the corgi runs out of hearts.
signal died
## Emitted when the corgi splashes into the sea (and pops back home).
signal fell_in_water

enum CameraMode {
	BEHIND,  ## Camera stays behind the corgi's head. W/S = forward/back, A/D (or mouse) = turn.
	FREE,    ## Look around freely with the mouse. WASD moves the way the camera faces.
}

# --- Movement (try changing these in the Inspector!) ---
@export var walk_speed := 5.0
@export var sprint_speed := 8.5
@export var acceleration := 12.0
@export var jump_velocity := 7.0
@export var gravity := 20.0

# --- Health & combat ---
@export var max_health := 5
@export var invincible_seconds := 1.2
## Extra damage on top of the weapon's damage.
@export var base_damage := 0
## The weapon the corgi starts with. Empty = no weapon (Mom gives you one!).
@export var starting_weapon: PackedScene
## How close you need to be to talk to someone.
@export var interact_range := 2.0

# --- Camera ---
@export var mouse_sensitivity := 0.003
@export var stick_sensitivity := 3.0
## Which camera the game starts with. Press C (or click the right stick) to switch.
@export var camera_mode: CameraMode = CameraMode.BEHIND
## How fast A/D turn the corgi in Behind mode (radians per second).
@export var turn_speed := 2.8

const ARM_REST_ANGLE := 0.35
## Fall below this and you've splashed into the sea. (The cave lowers it.)
var fall_limit := -2.0

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
var _interact_target: Node3D
## Every weapon the corgi owns. Press Q to switch between them.
var weapons: Array[PackedScene] = []
var _weapon_index := 0
var _base_max_health := 0
var _hint_cooldown := 0.0
## Speedy Boots and friends make this bigger than 1.
var _speed_multiplier := 1.0
var _fainted := false


func _ready() -> void:
	add_to_group("player")
	_base_max_health = max_health
	health = max_health
	spawn_point = global_position
	# The camera rig follows the corgi but doesn't spin when the corgi turns.
	camera_rig.top_level = true
	camera_rig.global_position = global_position + Vector3(0, 1.0, 0)
	spring_arm.add_excluded_object(get_rid())
	arm_r.rotation.x = ARM_REST_ANGLE
	if starting_weapon:
		give_weapon(starting_weapon)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_look(-motion.relative.x * mouse_sensitivity, -motion.relative.y * mouse_sensitivity)
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


## Mouse / right stick: in Behind mode, left-right turns the corgi itself.
func _look(yaw: float, pitch: float) -> void:
	if camera_mode == CameraMode.BEHIND:
		if Game.can_play():
			model.rotation.y += yaw
		_rotate_camera(0.0, pitch)
	else:
		_rotate_camera(yaw, pitch)


func toggle_camera_mode() -> void:
	if camera_mode == CameraMode.BEHIND:
		camera_mode = CameraMode.FREE
		Game.message.emit("Camera: free look")
	else:
		camera_mode = CameraMode.BEHIND
		Game.message.emit("Camera: behind the corgi")


func _physics_process(delta: float) -> void:
	_invincible_time -= delta
	_stun_time -= delta
	_attack_cooldown -= delta
	_hint_cooldown -= delta

	# Look around with a controller's right stick.
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		_look(-look.x * stick_sensitivity * delta, -look.y * stick_sensitivity * delta)

	if Input.is_action_just_pressed("camera_toggle"):
		toggle_camera_mode()

	# Gravity pulls us down when we're in the air.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# While talking (or in a cutscene) the corgi stands still.
	var can_act := Game.can_play() and _stun_time <= 0.0 and not _fainted

	# Jump!
	if Input.is_action_just_pressed("jump") and is_on_floor() and can_act:
		velocity.y = jump_velocity
		_squash(Vector3(0.8, 1.25, 0.8))

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if not Game.can_play() or _fainted:
		input = Vector2.ZERO
	var direction := Vector3.ZERO
	if camera_mode == CameraMode.BEHIND:
		# A/D turn the corgi, W/S walk forward and back. The camera stays behind.
		if can_act:
			model.rotation.y -= input.x * turn_speed * delta
		var facing := -model.global_transform.basis.z
		facing.y = 0.0
		facing = facing.normalized()
		var forward := -input.y
		direction = facing * forward * (1.0 if forward > 0.0 else 0.6)
		if Game.can_play():
			camera_rig.rotation.y = lerp_angle(camera_rig.rotation.y, model.rotation.y, clampf(6.0 * delta, 0.0, 1.0))
	else:
		# Move relative to where the camera is looking.
		direction = camera_rig.global_transform.basis * Vector3(input.x, 0.0, input.y)
		direction.y = 0.0

	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	speed *= _speed_multiplier
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

	# Turn the corgi to face the way it's running (free-look camera only).
	if camera_mode == CameraMode.FREE and direction.length() > 0.1 and _stun_time <= 0.0:
		var target_yaw := atan2(-direction.x, -direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, clampf(12.0 * delta, 0.0, 1.0))

	# Sword
	var wants_attack := Input.is_action_just_pressed("attack") and not _just_grabbed_mouse
	if wants_attack and _attack_cooldown <= 0.0 and can_act and equipped.has("weapon"):
		_start_attack()
	_just_grabbed_mouse = false
	if _attacking and not _fainted:
		_check_sword_hits()

	# Switch between sword and axe.
	if Input.is_action_just_pressed("switch_weapon") and can_act and not _arm_busy:
		_switch_weapon()

	# Talk to whoever is nearby.
	_update_interact_target()
	if Input.is_action_just_pressed("interact") and can_act and _interact_target:
		_interact_target.call("interact", self)

	# Fell into the water? Back to the start.
	if global_position.y < fall_limit:
		if _fainted:
			velocity = Vector3.ZERO  # don't keep sinking behind the "You died!" screen
			global_position.y = fall_limit
		else:
			_fell_in_water()

	# Camera smoothly follows the corgi.
	var follow_target := global_position + Vector3(0, 1.0, 0)
	camera_rig.global_position = camera_rig.global_position.lerp(follow_target, clampf(10.0 * delta, 0.0, 1.0))


func _process(delta: float) -> void:
	_animate(delta)


# ---------------------------------------------------------------- Equipment

## Put on an item (a scene whose root has the EquipmentItem script).
## Anything already in that slot is taken off first.
func equip(item_scene: PackedScene) -> EquipmentItem:
	var item := item_scene.instantiate() as EquipmentItem
	if item == null:
		push_warning("equip(): that scene's root node needs the equipment_item.gd script.")
		return null
	if not sockets.has(item.slot):
		push_warning("equip(): unknown slot '%s'." % item.slot)
		item.queue_free()
		return null
	unequip(item.slot)
	var targets: Array = sockets[item.slot]
	for i in targets.size():
		# Boots need one copy per foot; everything else uses the first copy.
		var piece: Node = item
		if i > 0:
			piece = item_scene.instantiate()
		(targets[i] as Node3D).add_child(piece)
	equipped[item.slot] = item
	_recalculate_stats()
	return item


## Add a weapon to the corgi's collection and hold it right away.
func give_weapon(weapon_scene: PackedScene) -> EquipmentItem:
	if not weapons.has(weapon_scene):
		weapons.append(weapon_scene)
	_weapon_index = weapons.find(weapon_scene)
	return equip(weapon_scene)


func _switch_weapon() -> void:
	if weapons.size() < 2:
		return
	_weapon_index = (_weapon_index + 1) % weapons.size()
	var item := equip(weapons[_weapon_index])
	if item:
		Game.message.emit(item.display_name)


## Take off whatever is in a slot ("head", "chest", "back", "shield", "weapon" or "feet").
func unequip(slot: String) -> void:
	if not sockets.has(slot):
		return
	for socket in sockets[slot]:
		for child in (socket as Node3D).get_children():
			child.queue_free()
	equipped.erase(slot)
	_recalculate_stats()


## Update hearts when gear with bonus hearts goes on or comes off.
func _recalculate_stats() -> void:
	var bonus := 0
	var speed_bonus := 0.0
	for item in equipped.values():
		bonus += (item as EquipmentItem).bonus_hearts
		speed_bonus += (item as EquipmentItem).speed_bonus
	_speed_multiplier = 1.0 + speed_bonus
	var old_max := max_health
	max_health = _base_max_health + bonus
	if max_health > old_max:
		health += max_health - old_max  # new hearts come filled in
	health = mini(health, max_health)
	health_changed.emit(health, max_health)
	equipment_changed.emit()


func get_attack_damage() -> int:
	var weapon: EquipmentItem = equipped.get("weapon")
	return base_damage + (weapon.damage if weapon else 0)


func get_attack_reach() -> float:
	var weapon: EquipmentItem = equipped.get("weapon")
	return weapon.reach if weapon else 1.0


func get_defense() -> int:
	var total := 0
	for item in equipped.values():
		total += (item as EquipmentItem).defense
	return total


# ---------------------------------------------------------------- Talking

func _update_interact_target() -> void:
	var best: Node3D = null
	var best_distance := interact_range
	if Game.can_play():
		for thing in get_tree().get_nodes_in_group("interactable"):
			var node := thing as Node3D
			if node == null:
				continue
			var distance := global_position.distance_to(node.global_position)
			if distance < best_distance:
				best = node
				best_distance = distance
	if best != _interact_target:
		_interact_target = best
		interact_target_changed.emit(best)


# ---------------------------------------------------------------- Cutscenes

## Switch back to the corgi's own camera (after a cutscene camera).
func use_camera() -> void:
	($CameraRig/SpringArm3D/Camera3D as Camera3D).make_current()


## Move the corgi to a spot and face something (used by cutscenes).
func place_at(spot: Vector3, look_at_point: Vector3) -> void:
	global_position = spot
	velocity = Vector3.ZERO
	var to := look_at_point - spot
	model.rotation.y = atan2(-to.x, -to.z)
	camera_rig.global_position = spot + Vector3(0, 1.0, 0)
	camera_rig.rotation.y = model.rotation.y


# ---------------------------------------------------------------- Sleeping

## Lie down in bed (used at the very start of the game).
func lie_down() -> void:
	model.rotation = Vector3(0.0, PI, -PI / 2.0)
	model.position = Vector3(0.45, 0.28, 0.0)
	camera_rig.rotation.y = PI * 0.25


## Wake up, stretch, and hop to your feet. Use with `await`.
func wake_up() -> void:
	var tween := create_tween()
	tween.tween_property(model, "rotation:z", -PI / 2.0 + 0.25, 0.15)
	tween.tween_property(model, "rotation:z", -PI / 2.0, 0.15)
	tween.tween_interval(0.3)
	tween.tween_property(model, "rotation", Vector3(0.0, PI, 0.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(model, "position", Vector3.ZERO, 0.35)
	await tween.finished
	_squash(Vector3(0.8, 1.25, 0.8))
	velocity.y = 3.5


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
	var weapon: EquipmentItem = equipped.get("weapon")
	var can_chop := weapon != null and weapon.can_chop

	# Slimes and other enemies.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy in _hit_this_swing or not _in_swing(enemy, forward, reach):
			continue
		_hit_this_swing.append(enemy)
		if enemy.has_method("take_hit"):
			enemy.take_hit(get_attack_damage(), global_position)

	# Trees (only an axe can chop them).
	for tree in get_tree().get_nodes_in_group("choppable"):
		if tree in _hit_this_swing or not _in_swing(tree, forward, reach + 0.4):
			continue
		_hit_this_swing.append(tree)
		if can_chop:
			tree.chop(global_position)
		elif Game.stage == Game.Stage.CHOP_WOOD and _hint_cooldown <= 0.0:
			_hint_cooldown = 4.0
			Game.message.emit("Press Q to switch to your axe!")


## Is this thing close enough and in front of the corgi to get hit?
func _in_swing(thing: Node, forward: Vector3, reach: float) -> bool:
	var node := thing as Node3D
	if node == null:
		return false
	var to_thing := node.global_position - global_position
	if absf(to_thing.y) > 1.5:
		return false
	to_thing.y = 0.0
	# Big things (like a boss) can be hit from farther away.
	var hit_radius: float = node.get("hit_radius") if "hit_radius" in node else 0.0
	var distance := to_thing.length()
	var in_front := distance < 0.6 + hit_radius or forward.dot(to_thing / distance) > 0.2
	return distance <= reach + hit_radius and in_front


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
		_faint()


func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


func _fell_in_water() -> void:
	if _fainted:
		return
	health = maxi(health - 1, 0)
	if health <= 0:
		health_changed.emit(health, max_health)
		velocity = Vector3.ZERO
		global_position = spawn_point
		_faint()
		return
	health_changed.emit(health, max_health)
	global_position = spawn_point
	velocity = Vector3.ZERO
	_invincible_time = invincible_seconds
	fell_in_water.emit()


## Out of hearts! The corgi flops over. (main.gd shows the "You died!"
## screen and then calls respawn_in_bed().)
func _faint() -> void:
	if _fainted:
		return
	_fainted = true
	Game.in_cutscene = true
	_attacking = false
	var tween := create_tween()
	tween.tween_property(model, "rotation:z", PI / 2.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	died.emit()


## Back home in bed with full hearts. Use with `await` (waits for the wake-up).
func respawn_in_bed() -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO
	_stun_time = 0.0
	health = max_health
	health_changed.emit(health, max_health)
	lie_down()
	camera_rig.global_position = global_position + Vector3(0, 1.0, 0)


## Finish getting up after respawn_in_bed().
func finish_respawn() -> void:
	await wake_up()
	_fainted = false
	_invincible_time = invincible_seconds


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
