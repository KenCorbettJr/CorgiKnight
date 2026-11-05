extends CharacterBody3D
## A cute little ghost! 👻
##
## Think of a friendly Boo from Luigi's Mansion: a round, floaty, see-through
## ghost with big eyes and a wiggly little tail. It bobs up and down, drifts
## around its home spot, sometimes says "Boo!", and every now and then floats
## toward the corgi to give it a gentle scare.
##
## Ghosts are NICE. They never hurt you — touching the corgi just startles it
## (Game.ghost_scare()) and then the ghost zips away, giggling. A sword swings
## right through them (they think it's hilarious). The only way to catch one is
## the Ghost Sucker backpack: hold it in the vacuum beam for a moment and the
## ghost gets slurped up into the tank, giving you one point of ghost energy.
##
## Worker A's island spawns these by instancing res://scenes/ghost.tscn and
## reads two things from us (the contract we must not change):
##   * we're in the group "ghosts"
##   * we have a `captured` signal
## We call Game.ghost_scare() / Game.add_ghost_energy() through has_method()
## guards so this branch still runs fine before A's game_state changes land.

## Emitted the moment this ghost gets fully slurped into the vacuum.
signal captured

# --- Floating & wandering (tweak these in the Inspector!) ---
## How fast the ghost drifts around while wandering.
@export var wander_speed := 1.6
## How fast it floats toward the corgi when it decides to spook it.
@export var chase_speed := 2.4
## How far from home it likes to roam.
@export var wander_radius := 4.0
## The corgi has to be at least this close before a ghost bothers chasing it.
@export var notice_range := 7.0
## How high above the ground the ghost likes to hover.
@export var hover_height := 1.1

# --- Getting sucked up ---
## How long the ghost has to stay inside the vacuum beam before it's caught.
## Leave the beam before this runs out and it wriggles free!
@export var capture_time := 1.0
## How hard the vacuum pulls the ghost in while it's in the beam.
@export var pull_strength := 7.0

@onready var model: Node3D = $Model
@onready var body: Node3D = $Model/Body
@onready var boo_label: Label3D = $BooLabel

## Where the ghost first appeared — it always drifts back toward here.
var _home := Vector3.ZERO
## Counts down to the next little decision (wander a new way / maybe chase).
var _think_timer := 0.0
## true while it's floating toward the corgi for a scare.
var _chasing := false
## Short cooldown after a scare so it doesn't spook you again instantly.
var _scare_cooldown := 0.0
## While > 0 the ghost is zipping away after scaring the corgi.
var _flee_time := 0.0
var _flee_dir := Vector3.ZERO
## How long the ghost has been held in the vacuum beam so far.
var _beam_held := 0.0
## true once it's been caught — stops it doing anything else while it shrinks.
var _caught := false
var _player: Node3D
var _bob_phase := 0.0
var _tail_phase := 0.0
var _base_model_scale := Vector3.ONE


func _ready() -> void:
	# The contract with worker A: ghosts live in the "ghosts" group.
	add_to_group("ghosts")
	_home = global_position
	_think_timer = randf_range(0.5, 2.0)
	# Start each ghost at its own point in the bob/wiggle so a group of them
	# doesn't float in perfect sync (that would look a bit robotic!).
	_bob_phase = randf_range(0.0, TAU)
	_tail_phase = randf_range(0.0, TAU)
	_base_model_scale = model.scale
	if boo_label:
		boo_label.visible = false


func _physics_process(delta: float) -> void:
	_bob_phase += delta * 2.5
	_tail_phase += delta * 4.0
	_scare_cooldown -= delta

	# Caught! We're being reeled into the nozzle — _capture() drives us now.
	if _caught:
		return

	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D

	# Only wander/chase/scare while the corgi is actually playing (not mid-
	# conversation or cutscene).
	var playing := not Game.has_method("can_play") or Game.can_play()

	if _flee_time > 0.0:
		# Zipping away after a scare. Whee!
		_flee_time -= delta
		velocity = velocity.lerp(_flee_dir * chase_speed * 2.2, clampf(8.0 * delta, 0.0, 1.0))
	elif playing:
		_wander_and_chase(delta)
	else:
		velocity = velocity.lerp(Vector3.ZERO, clampf(5.0 * delta, 0.0, 1.0))

	# Gently settle toward the hover height above our home's ground level.
	var want_y := _home.y + hover_height
	velocity.y = lerpf(velocity.y, (want_y - global_position.y) * 2.0, clampf(4.0 * delta, 0.0, 1.0))

	move_and_slide()

	# Scare the corgi if we bump into it (but only every so often).
	if playing and _player and _scare_cooldown <= 0.0 and _flee_time <= 0.0:
		if global_position.distance_to(_player.global_position) < 0.9:
			_scare_player()

	_animate(delta)


func _wander_and_chase(delta: float) -> void:
	_think_timer -= delta
	var target := Vector3.ZERO

	var distance_to_player := INF
	if _player:
		distance_to_player = global_position.distance_to(_player.global_position)
	_chasing = _player != null and distance_to_player < notice_range and _scare_cooldown <= 0.0

	if _think_timer <= 0.0:
		if _chasing and randf() < 0.6:
			# Decide to drift over and spook the corgi.
			_think_timer = randf_range(1.0, 2.0)
		else:
			# Otherwise pick a lazy new wander and maybe say "Boo!".
			_think_timer = randf_range(1.5, 3.5)
			if randf() < 0.35:
				_say_boo()

	if _chasing:
		target = (_player.global_position - global_position)
		target.y = 0.0
		velocity.x = move_toward(velocity.x, target.normalized().x * chase_speed, 6.0 * delta)
		velocity.z = move_toward(velocity.z, target.normalized().z * chase_speed, 6.0 * delta)
	else:
		# Mosey back toward home if we've wandered too far, else drift gently.
		var to_home := _home - global_position
		to_home.y = 0.0
		var dir := to_home.normalized() if to_home.length() > wander_radius else _wander_drift()
		velocity.x = move_toward(velocity.x, dir.x * wander_speed, 3.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * wander_speed, 3.0 * delta)

	# Face the way we're floating (ghosts always look where they're going).
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() > 0.2:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-flat.x, -flat.z), clampf(6.0 * delta, 0.0, 1.0))


## A slow, randomly-wobbling drift direction for idle wandering.
func _wander_drift() -> Vector3:
	return Vector3(sin(_bob_phase * 0.7), 0.0, cos(_bob_phase * 0.5)).normalized() * 0.6


func _scare_player() -> void:
	_scare_cooldown = 3.0
	# Tell the game the corgi got spooked (A's game_state writes this).
	if Game.has_method("ghost_scare"):
		Game.ghost_scare()
	_say_boo()
	# Zip away in the opposite direction for a moment, giggling.
	var away := global_position - _player.global_position
	away.y = 0.0
	_flee_dir = away.normalized() if away.length() > 0.1 else Vector3.BACK
	_flee_time = 0.7
	# A cheeky little spin.
	var tween := create_tween()
	tween.tween_property(model, "rotation:y", model.rotation.y + TAU, 0.5)


func _say_boo() -> void:
	if boo_label == null:
		return
	boo_label.text = ["Boo!", "Boo!", "Hee hee!", "Wooo~"].pick_random()
	boo_label.visible = true
	boo_label.modulate = Color(1, 1, 1, 1)
	boo_label.position = Vector3(0, 0.9, 0)
	var tween := create_tween()
	tween.tween_property(boo_label, "position:y", 1.4, 1.0)
	tween.parallel().tween_property(boo_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func() -> void:
		if is_instance_valid(boo_label):
			boo_label.visible = false)


# ---------------------------------------------------------------- Vacuum beam

## The Ghost Sucker calls this every physics frame while this ghost is caught
## in its beam. `source` is the nozzle tip we're being pulled toward; `delta`
## is the frame time. Return value isn't used — we free ourselves on capture.
func suck_toward(source: Vector3, delta: float) -> void:
	if _caught:
		return
	# Interrupt whatever we were doing — we're struggling in the beam now.
	_chasing = false
	_flee_time = 0.0
	_beam_held += delta

	# Yanked toward the nozzle.
	var pull := (source - global_position)
	var dist := pull.length()
	if dist > 0.05:
		velocity = velocity.lerp(pull.normalized() * pull_strength, clampf(10.0 * delta, 0.0, 1.0))

	# Shake and struggle! Little frantic wobble that grows as it's held longer.
	var shake := 0.06 + 0.05 * (_beam_held / maxf(capture_time, 0.01))
	model.position = Vector3(randf_range(-shake, shake), randf_range(-shake, shake), 0.0)
	model.rotation.z = sin(_beam_held * 40.0) * 0.35

	# Held long enough? Slurp! Into the tank it goes.
	if _beam_held >= capture_time:
		_capture(source)


## Called by the vacuum when this ghost drifts out of the beam. If it wasn't
## caught yet it recovers and goes back to floating around.
func leave_beam() -> void:
	if _caught:
		return
	_beam_held = 0.0
	model.position = Vector3.ZERO
	model.rotation.z = 0.0


func _capture(nozzle: Vector3) -> void:
	if _caught:
		return
	_caught = true
	remove_from_group("ghosts")
	# Stop colliding so it can't bonk anything on its way into the tank.
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	if boo_label:
		boo_label.visible = false

	# Shrink into the nozzle with a happy little *shloop*.
	var tween := create_tween()
	tween.tween_property(self, "global_position", nozzle, 0.18)
	tween.parallel().tween_property(model, "scale", Vector3.ZERO, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		# One energy point per ghost (A's game_state tallies it toward the bell).
		if Game.has_method("add_ghost_energy"):
			Game.add_ghost_energy(1)
		captured.emit()
		queue_free())


# ---------------------------------------------------------------- Sword

## The corgi's sword calls this (ghosts are also added to the sword's reach
## when A spawns them, or if a test puts them in "enemies"). A normal hit does
## NOTHING to a ghost — the blade passes right through and the ghost giggles.
func take_hit(_amount: int, _from_position: Vector3) -> void:
	if _caught:
		return
	Game.message.emit("The sword goes right through! The ghost giggles.")
	_say_boo()


# ---------------------------------------------------------------- Cute animation

func _animate(delta: float) -> void:
	if _caught:
		return
	# Gentle bob up and down, laid on top of the hover.
	body.position.y = sin(_bob_phase) * 0.08
	# Wiggle the squishy tail side to side.
	var tail := body.get_node_or_null("Tail") as Node3D
	if tail:
		tail.rotation.z = sin(_tail_phase) * 0.3
	# Squash-and-stretch a touch while moving so it feels alive.
	var squish := clampf(Vector2(velocity.x, velocity.z).length() * 0.03, 0.0, 0.12)
	var target_scale := _base_model_scale * Vector3(1.0 - squish, 1.0 + squish, 1.0 - squish)
	model.scale = model.scale.lerp(target_scale, clampf(8.0 * delta, 0.0, 1.0))
	# Settle the struggling-shake offset back to center when not in a beam.
	model.position = model.position.lerp(Vector3.ZERO, clampf(10.0 * delta, 0.0, 1.0))
	model.rotation.z = lerpf(model.rotation.z, 0.0, clampf(10.0 * delta, 0.0, 1.0))
