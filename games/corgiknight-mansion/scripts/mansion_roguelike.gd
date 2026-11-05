extends Node3D
## MansionRoguelike — the standalone roguelike's procedural mansion + play loop.
##
## Lifted and de-islanded from the Dr Fluffles basement: a RUN is a sequence of
## procedurally generated mansion rooms. Each room gets a seeded-random layout
## (from a small template set) and ONE random challenge. The EXIT DOOR opens
## only once the room's challenge is beaten; stepping through clears the room
## (RunState.clear_room), and clearing the last room clears the LEVEL and makes
## RunState generate the NEXT mansion. The scare meter is RunState's own; a full
## meter is DEATH and RunState restarts the run at a freshly generated level 1.
##
## CRITICAL DIFFERENCE from the island version: this reads/writes ONLY RunState,
## never the island Game quest machine. There is no island, dock, portal, or
## "sail here first" gate. Level 1 is a generated mansion exactly like every
## other level — the generator runs on RunState.level_generated, which fires for
## level 1 the instant start_run() is called.
##
## It is driven entirely by RunState signals, so it works identically headless
## (for the roguelike_loop_test) and in the live game.

const GHOST_SCENE := preload("res://scenes/ghost.tscn")

## Challenge kinds, matching the original five.
enum Challenge {
	CATCH_FIVE,      ## Suck up N ghosts.
	GOLDEN_GHOST,    ## Catch one fast golden ghost.
	SURVIVE_SWARM,   ## Stay un-scared-out for a time while ghosts spawn.
	FIND_KEY,        ## Grab a hidden key while ghosts chase you.
	LIGHT_CANDLES,   ## Light all candles before ghosts snuff them.
}

const ROOM_HALF := 9.0
const WALL_HEIGHT := 4.0
const ENTRY_LOCAL := Vector3(0, 0.2, ROOM_HALF - 2.0)
const EXIT_LOCAL := Vector3(0, 0, -ROOM_HALF)
const SCARE_GRACE := 1.0

## Emitted when the generator (re)builds a room, for anything that wants a local
## notice (the HUD, screenshot harnesses). Carries the level and room index.
signal room_built(level: int, room_index: int)

var _rng := RandomNumberGenerator.new()
var _room: Node3D
var _challenge: int = Challenge.CATCH_FIVE
var _challenge_done := false
var _exit_door: Node3D
var _exit_area: Area3D
var _room_rng_seed := 0

var _catch_target := 0
var _catch_start := 0
var _golden: Node3D
var _survive_time := 0.0
var _survive_left := 0.0
var _key: Node3D
var _has_key := false
var _candles: Array[Node3D] = []
var _candles_lit := 0

var _player: Node3D
var _ghosts: Array[Node3D] = []
var _spawn_timer := 0.0
var _max_ghosts := 4
var _ghost_speed_mult := 1.0
var _scare_grace := 0.0

var _materials := {}
## True while the loop is live (physics/process ticking, ghosts spawning). Tests
## can leave this false and drive the generator directly for determinism.
var _simulating := false


func _ready() -> void:
	_build_materials()
	_build_shell()
	set_physics_process(false)
	set_process(false)
	# Rebuild the mansion whenever RunState announces a newly generated level —
	# level 1 on start, each advance, and each death-reset.
	if Engine.has_singleton("RunState") or RunState:
		RunState.level_generated.connect(_on_level_generated)


# ------------------------------------------------------------- Public API

## Hook the live player into the loop and begin simulating (ghost spawns, scare
## contact, tweens). Call AFTER RunState.start_run() in the live game. Tests that
## only assert generation/state can skip this and stay deterministic.
func begin_simulation(player: Node3D) -> void:
	_player = player
	_simulating = true
	set_physics_process(true)
	set_process(true)


## Stop simulating (used on teardown).
func stop_simulation() -> void:
	_simulating = false
	set_physics_process(false)
	set_process(false)


## The current room's challenge kind.
func current_challenge() -> int:
	return _challenge


## Number of room child-nodes currently built (1 while a room exists). Lets the
## test prove "rooms exist" without reaching into private layout.
func room_node_count() -> int:
	return 1 if (_room != null and is_instance_valid(_room)) else 0


## How many structural pieces (walls + floor) the current room built. A positive
## count proves the procedural generator actually produced a mansion room.
func room_structure_count() -> int:
	if _room == null or not is_instance_valid(_room):
		return 0
	var n := 0
	for c in _room.get_children():
		if c is StaticBody3D:
			n += 1
	return n


## The seed the current room's layout was built from (derived from the level
## seed). Nonzero once a room is built.
func room_seed() -> int:
	return _room_rng_seed


## The corgi's world drop-in spot for the current room.
func player_entry_point() -> Vector3:
	return to_global(ENTRY_LOCAL)


## Force the current room's challenge to be marked complete (used by the live
## loop AND by the test to drive a level to completion deterministically).
func complete_current_challenge() -> void:
	_complete_challenge()


## Step through the (open) exit as if the player walked into it: clears the room
## in RunState and advances. Used by the test to drive the loop headlessly.
func advance_through_exit() -> void:
	if not _challenge_done:
		return
	_advance_room()


# --------------------------------------------------- RunState signal handlers

## A fresh mansion was generated for a level — build its first room. Because
## RunState announces this for level 1 too, the generator builds level 1 as a
## real procedural mansion with no island dependency.
func _on_level_generated(level: int, seed: int) -> void:
	# Seed the whole level from RunState's level seed so the whole mansion is
	# reproducible from that one number.
	_rng.seed = int(seed)
	_build_current_room()


# ------------------------------------------------------------- Scare (death)

## A ghost touched the corgi. Add a scare pip to RunState (respecting a grace
## window). RunState handles death (meter full -> restart at level 1).
func scare_player() -> void:
	if _scare_grace > 0.0 or not RunState.run_active:
		return
	_scare_grace = SCARE_GRACE
	RunState.add_scare()


# ------------------------------------------------------------- Frame loop

func _process(delta: float) -> void:
	if _scare_grace > 0.0:
		_scare_grace = maxf(_scare_grace - delta, 0.0)


func _physics_process(delta: float) -> void:
	if not _simulating or not RunState.run_active:
		return

	if _challenge != Challenge.GOLDEN_GHOST:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0 and _alive_ghost_count() < _max_ghosts:
			_spawn_timer = _rng.randf_range(1.2, 2.4)
			_spawn_ghost(false)

	if _player:
		for g in _ghosts:
			if not is_instance_valid(g):
				continue
			if g.global_position.distance_to(_player.global_position) < 0.95:
				scare_player()
				break

	_update_challenge(delta)


# ------------------------------------------------------------- Rooms

func _build_current_room() -> void:
	_teardown_room()
	_challenge_done = false
	_room = Node3D.new()
	_room.name = "Room%d" % RunState.room_index
	add_child(_room)

	# A fresh layout seed per room, derived from the level seed + room index so a
	# given room of a given level is reproducible.
	_room_rng_seed = int(_rng.randi()) ^ (RunState.room_index * 0x27d4eb2d)
	if _room_rng_seed == 0:
		_room_rng_seed = 1
	var layout_rng := RandomNumberGenerator.new()
	layout_rng.seed = _room_rng_seed

	_build_room_geometry(layout_rng)
	_scatter_props(layout_rng)

	var lvl: int = maxi(1, RunState.level)
	_max_ghosts = 3 + lvl
	_ghost_speed_mult = 1.0 + 0.08 * float(lvl - 1)

	_pick_challenge(layout_rng)
	_setup_challenge(layout_rng)
	_build_exit_door()
	_set_exit_open(false)

	room_built.emit(RunState.level, RunState.room_index)


func _teardown_room() -> void:
	for g in _ghosts:
		if is_instance_valid(g):
			g.queue_free()
	_ghosts.clear()
	_golden = null
	_key = null
	_has_key = false
	_candles.clear()
	_candles_lit = 0
	if _room and is_instance_valid(_room):
		_room.queue_free()
	_room = null
	_exit_door = null
	_exit_area = null


func _build_shell() -> void:
	var fill := OmniLight3D.new()
	fill.light_energy = 1.6
	fill.omni_range = 40.0
	fill.position = Vector3(0, 6, 0)
	fill.light_color = Color(0.75, 0.8, 0.95)
	add_child(fill)


func _build_room_geometry(rng: RandomNumberGenerator) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	_room.add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ROOM_HALF * 2.0, 0.4, ROOM_HALF * 2.0)
	floor_shape.shape = box
	floor_shape.position = Vector3(0, -0.2, 0)
	floor_body.add_child(floor_shape)
	var floor_mesh := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = box.size
	floor_mesh.mesh = fm
	floor_mesh.material_override = _materials["floor"]
	floor_mesh.position = Vector3(0, -0.2, 0)
	floor_body.add_child(floor_mesh)

	var wall_defs := [
		{"pos": Vector3(0, WALL_HEIGHT * 0.5, -ROOM_HALF), "size": Vector3(ROOM_HALF * 2.0, WALL_HEIGHT, 0.4)},
		{"pos": Vector3(0, WALL_HEIGHT * 0.5, ROOM_HALF), "size": Vector3(ROOM_HALF * 2.0, WALL_HEIGHT, 0.4)},
		{"pos": Vector3(-ROOM_HALF, WALL_HEIGHT * 0.5, 0), "size": Vector3(0.4, WALL_HEIGHT, ROOM_HALF * 2.0)},
		{"pos": Vector3(ROOM_HALF, WALL_HEIGHT * 0.5, 0), "size": Vector3(0.4, WALL_HEIGHT, ROOM_HALF * 2.0)},
	]
	for d in wall_defs:
		_add_wall(d["pos"], d["size"])


func _add_wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Wall"
	_room.add_child(body)
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = _materials["wall"]
	body.add_child(mesh)


func _scatter_props(rng: RandomNumberGenerator) -> void:
	var template := rng.randi() % 3
	var spots: Array[Vector3] = []
	match template:
		0:
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					spots.append(Vector3(sx * (ROOM_HALF - 2.5), 0, sz * (ROOM_HALF - 2.5)))
		1:
			var n := 4 + rng.randi() % 4
			for i in n:
				spots.append(Vector3(rng.randf_range(-ROOM_HALF + 2.0, ROOM_HALF - 2.0), 0,
					rng.randf_range(-ROOM_HALF + 3.0, ROOM_HALF - 3.0)))
		2:
			var n := 3 + rng.randi() % 3
			for i in n:
				var a := rng.randf() * TAU
				var r := rng.randf_range(1.5, 4.0)
				spots.append(Vector3(cos(a) * r, 0, sin(a) * r))

	for s in spots:
		if s.distance_to(ENTRY_LOCAL) < 2.2 or s.distance_to(EXIT_LOCAL) < 2.5:
			continue
		_add_prop(s, rng)


func _add_prop(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	body.name = "Prop"
	_room.add_child(body)
	var h := rng.randf_range(0.8, 1.8)
	body.position = pos + Vector3(0, h * 0.5, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, h, 0.9)
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mesh.mesh = bm
	mesh.material_override = _materials["prop"]
	body.add_child(mesh)


# ------------------------------------------------------------- Exit door

func _build_exit_door() -> void:
	_exit_door = Node3D.new()
	_exit_door.name = "ExitDoor"
	_room.add_child(_exit_door)
	_exit_door.position = EXIT_LOCAL + Vector3(0, WALL_HEIGHT * 0.5, 0.25)

	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.4, WALL_HEIGHT - 0.4, 0.3)
	mesh.mesh = bm
	mesh.material_override = _materials["door"]
	_exit_door.add_child(mesh)

	_exit_area = Area3D.new()
	_exit_area.name = "ExitTrigger"
	_room.add_child(_exit_area)
	_exit_area.position = EXIT_LOCAL + Vector3(0, 1.0, 1.4)
	var acol := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(2.4, 2.0, 1.6)
	acol.shape = abox
	_exit_area.add_child(acol)
	_exit_area.body_entered.connect(_on_exit_entered)


func _set_exit_open(open: bool) -> void:
	if _exit_door == null:
		return
	var y := (WALL_HEIGHT - 0.4) if open else WALL_HEIGHT * 0.5
	if _simulating:
		var tween := create_tween()
		tween.tween_property(_exit_door, "position:y", y, 0.4).set_trans(Tween.TRANS_SINE)
	else:
		_exit_door.position.y = y


func _on_exit_entered(body: Node) -> void:
	if not _challenge_done or body != _player:
		return
	_advance_room()


# ------------------------------------------------------------- Challenges

func _pick_challenge(rng: RandomNumberGenerator) -> void:
	_challenge = rng.randi() % Challenge.size()


func _setup_challenge(rng: RandomNumberGenerator) -> void:
	var lvl: int = maxi(1, RunState.level)
	match _challenge:
		Challenge.CATCH_FIVE:
			_catch_target = 5
			_catch_start = 0
		Challenge.GOLDEN_GHOST:
			if _simulating:
				_spawn_golden()
		Challenge.SURVIVE_SWARM:
			_survive_time = 20.0 + 3.0 * float(lvl)
			_survive_left = _survive_time
			_max_ghosts = 4 + lvl
		Challenge.FIND_KEY:
			_spawn_key(rng)
		Challenge.LIGHT_CANDLES:
			_spawn_candles(rng, 3 + mini(lvl, 3))


func _update_challenge(delta: float) -> void:
	if _challenge_done:
		return
	match _challenge:
		Challenge.SURVIVE_SWARM:
			_survive_left -= delta
			if _survive_left <= 0.0:
				_complete_challenge()
		Challenge.FIND_KEY:
			if _key and is_instance_valid(_key) and _player and not _has_key:
				if _key.global_position.distance_to(_player.global_position) < 1.4:
					_has_key = true
					_key.queue_free()
					_complete_challenge()
		Challenge.LIGHT_CANDLES:
			_tick_candles(delta)
			if _candles_lit >= _candles.size() and _candles.size() > 0:
				_complete_challenge()
		Challenge.GOLDEN_GHOST:
			if _golden == null or not is_instance_valid(_golden):
				if _simulating:
					_complete_challenge()


func _complete_challenge() -> void:
	if _challenge_done:
		return
	_challenge_done = true
	_set_exit_open(true)


func _advance_room() -> void:
	# RunState clears the room (banks coins + advances), and clears the LEVEL
	# (generating the next mansion via level_generated) when the last room falls.
	RunState.clear_room()


# ------------------------------------------------------------- Ghosts

func _spawn_ghost(golden: bool) -> Node3D:
	var g := GHOST_SCENE.instantiate() as Node3D
	if g == null:
		return null
	_room.add_child(g)
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(3.0, ROOM_HALF - 2.0)
	g.global_position = to_global(Vector3(cos(a) * r, 0.1, sin(a) * r))
	if "wander_speed" in g:
		g.wander_speed *= _ghost_speed_mult
	if "chase_speed" in g:
		g.chase_speed *= _ghost_speed_mult
	if golden:
		if "wander_speed" in g:
			g.wander_speed *= 1.8
		if "chase_speed" in g:
			g.chase_speed *= 1.8
	_ghosts.append(g)
	return g


func _spawn_golden() -> void:
	_golden = _spawn_ghost(true)


func _alive_ghost_count() -> int:
	var n := 0
	for g in _ghosts:
		if is_instance_valid(g):
			n += 1
	return n


# ------------------------------------------------------------- Key / candles

func _spawn_key(rng: RandomNumberGenerator) -> void:
	_key = Node3D.new()
	_room.add_child(_key)
	var a := rng.randf() * TAU
	var r := rng.randf_range(4.0, ROOM_HALF - 2.0)
	_key.position = Vector3(cos(a) * r, 1.0, sin(a) * r)
	var mesh := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.12
	tm.outer_radius = 0.22
	mesh.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.7, 0.1)
	mesh.material_override = mat
	_key.add_child(mesh)


func _spawn_candles(rng: RandomNumberGenerator, count: int) -> void:
	_candles.clear()
	_candles_lit = 0
	for i in count:
		var c := Node3D.new()
		_room.add_child(c)
		var a := TAU * float(i) / float(count)
		var r := ROOM_HALF - 3.0
		c.position = Vector3(cos(a) * r, 0.6, sin(a) * r)
		var stick := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.12
		cm.bottom_radius = 0.12
		cm.height = 0.8
		stick.mesh = cm
		stick.material_override = _materials["candle"]
		c.add_child(stick)
		var flame := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.12
		fm.height = 0.24
		flame.mesh = fm
		flame.position = Vector3(0, 0.55, 0)
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = Color(1.0, 0.7, 0.2)
		fmat.emission_enabled = true
		fmat.emission = Color(1.0, 0.6, 0.1)
		flame.material_override = fmat
		flame.name = "Flame"
		flame.visible = false
		c.add_child(flame)
		c.set_meta("lit", false)
		c.set_meta("snuff_t", rng.randf_range(2.0, 5.0))
		_candles.append(c)


func _tick_candles(delta: float) -> void:
	_candles_lit = 0
	for c in _candles:
		if not is_instance_valid(c):
			continue
		var lit: bool = c.get_meta("lit", false)
		if lit:
			var t: float = c.get_meta("snuff_t", 3.0) - delta
			if t <= 0.0:
				lit = false
				c.set_meta("lit", false)
				t = 3.0
				(c.get_node("Flame") as Node3D).visible = false
			c.set_meta("snuff_t", t)
		else:
			if _player and c.global_position.distance_to(_player.global_position) < 1.3:
				lit = true
				c.set_meta("lit", true)
				c.set_meta("snuff_t", randf_range(3.0, 6.0))
				(c.get_node("Flame") as Node3D).visible = true
		if lit:
			_candles_lit += 1


# ------------------------------------------------------------- Materials

func _build_materials() -> void:
	_materials["floor"] = _toon(Color(0.18, 0.16, 0.22))
	_materials["wall"] = _toon(Color(0.24, 0.2, 0.28))
	_materials["prop"] = _toon(Color(0.3, 0.26, 0.22))
	_materials["door"] = _toon(Color(0.4, 0.3, 0.5))
	_materials["candle"] = _toon(Color(0.9, 0.9, 0.85))


func _toon(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return mat
