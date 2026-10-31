extends Node
## Headless integration test for the Haunted Island adventure.
##
## Run it as the main scene (so the project's autoloads — Game, Effects — boot):
##   Godot --headless --path <project> --main-scene res://scenes/test/haunted_integration_test.tscn
##
## It drives the Game autoload (the side-adventure's whole state machine) plus
## the REAL ghost + Ghost Sucker capture chain, and asserts every invariant the
## owner asked for. Prints PASS/FAIL lines and quits non-zero on any failure.
##
## This is a logic/wiring test: it does not render or simulate input. The 3D
## feel (beam cone, walking, camera) is exercised by hand in ghost_test.tscn.

var _failures := 0
var _checks := 0

@onready var root: Node = get_tree().root


func _ready() -> void:
	# Start after the tree finishes setting up, so add_child() into the root
	# viewport is allowed (it isn't while we're still inside _ready).
	_run.call_deferred()


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if ok:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)


func _run() -> void:
	print("=== Haunted Island integration test ===")

	_test_gating()
	_test_arrival_quest1()
	await _test_capture_adds_exactly_one()
	_test_quest1_to_quest2()
	_test_bell_thresholds()
	await _test_scare_reset_keeps_progress()
	await _test_portal_spawn_gating()
	await _test_revisit_is_calm()
	_test_no_placeholder()

	print("=== %d checks, %d failures ===" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---- stage gating: haunted available only at stage >= FOREST, not BOSS2 ----
func _test_gating() -> void:
	Game.reset()
	Game.stage = Game.Stage.DONE
	_check("not available before FOREST (stage DONE)", not Game.haunted_available())
	Game.stage = Game.Stage.BOSS_FIGHT
	_check("not available during BOSS_FIGHT", not Game.haunted_available())
	Game.stage = Game.Stage.FOREST
	_check("available at FOREST", Game.haunted_available())
	Game.stage = Game.Stage.BOSS2_FIGHT
	_check("NOT available during BOSS2_FIGHT", not Game.haunted_available())
	Game.stage = Game.Stage.FOREST_DONE
	_check("available after FOREST_DONE", Game.haunted_available())


# ---- arriving starts quest 1 fresh ----
func _test_arrival_quest1() -> void:
	Game.reset()
	Game.stage = Game.Stage.FOREST
	Game.area = "haunted"
	Game.start_haunted()
	_check("arrival -> quest 1 (CATCH)", Game.haunted_quest == Game.HauntedQuest.CATCH)
	_check("arrival -> 0 energy", Game.ghost_energy == 0)
	_check("arrival -> 0 caught", Game.ghosts_caught == 0)
	_check("arrival -> scare meter empty", Game.scare == 0)


# ---- a real ghost, fully slurped, adds EXACTLY 1 energy (no double count) ----
func _test_capture_adds_exactly_one() -> void:
	Game.reset()
	Game.stage = Game.Stage.FOREST
	Game.area = "haunted"
	Game.start_haunted()

	var ghost_scene: PackedScene = load("res://scenes/ghost.tscn")
	var ghost := ghost_scene.instantiate()
	add_child(ghost)

	# Count every `captured` signal and every energy change, so we'd catch a
	# double-count if the signal were also wired to add energy.
	var captured_count := {"n": 0}
	ghost.captured.connect(func() -> void: captured_count["n"] += 1)

	var energy_before := Game.ghost_energy
	var caught_before := Game.ghosts_caught

	# Drive the ghost's own capture path: hold it in the beam past capture_time.
	# suck_toward(nozzle, delta) accumulates _beam_held; once it passes
	# capture_time the ghost captures itself (which is what calls add_ghost_energy
	# and emits `captured`). We feed it the full hold in one big delta.
	var nozzle: Vector3 = ghost.global_position + Vector3(0, 0, 0)
	ghost.call("suck_toward", nozzle, ghost.capture_time + 0.1)

	# The capture finishes inside a ~0.22s tween callback (that's what calls
	# add_ghost_energy + emits captured). Wait it out on wall-clock.
	await _wait_seconds(0.8)

	_check("one capture adds exactly 1 energy", Game.ghost_energy == energy_before + 1)
	_check("one capture counts exactly 1 ghost", Game.ghosts_caught == caught_before + 1)
	_check("captured signal fired exactly once", captured_count["n"] == 1)

	if is_instance_valid(ghost):
		ghost.queue_free()
	await _idle_frames(2)


# ---- 8 captures flips quest 1 -> quest 2 ----
func _test_quest1_to_quest2() -> void:
	Game.reset()
	Game.stage = Game.Stage.FOREST
	Game.area = "haunted"
	Game.start_haunted()
	var goal: int = Game.ghosts_goal
	for i in goal - 1:
		Game.add_ghost_energy(1)
	_check("still quest 1 at %d/%d" % [goal - 1, goal], Game.haunted_quest == Game.HauntedQuest.CATCH)
	Game.add_ghost_energy(1)  # the 8th
	_check("quest flips to FIND_BELL at %d" % goal, Game.haunted_quest == Game.HauntedQuest.FIND_BELL)
	_check("energy banked == %d after %d catches" % [goal, goal], Game.ghost_energy == goal)


# ---- bell refuses at 9, rings at 10, destroys portal ----
func _test_bell_thresholds() -> void:
	Game.reset()
	Game.stage = Game.Stage.FOREST
	Game.area = "haunted"
	Game.start_haunted()
	var cost: int = Game.bell_energy_cost
	# Get to quest 2 with cost-1 energy banked.
	Game.haunted_quest = Game.HauntedQuest.FIND_BELL
	Game.ghost_energy = cost - 1
	_check("bell refuses at %d energy" % (cost - 1), not Game.can_ring_bell())
	_check("bell reports missing 1 at %d" % (cost - 1), Game.bell_energy_missing() == 1)

	Game.ghost_energy = cost
	_check("bell accepts at %d energy" % cost, Game.can_ring_bell())

	var portal_fired := {"n": 0}
	Game.portal_destroyed.connect(func() -> void: portal_fired["n"] += 1)
	Game.ring_bell()
	_check("ring_bell fires portal_destroyed", portal_fired["n"] == 1)
	_check("ring_bell sets quest DONE", Game.haunted_quest == Game.HauntedQuest.DONE)
	_check("ring_bell sets portal_gone", Game.portal_gone)


# ---- 5 scares (grace respected) resets haunted-only; keeps coins/gear/stage ----
func _test_scare_reset_keeps_progress() -> void:
	Game.reset()
	Game.stage = Game.Stage.FOREST
	Game.area = "haunted"
	# Stand in some coins, gear and a specific stage to prove they survive.
	Game.add_coins(42)
	Game.owned.append("res://scenes/equipment/leather_cap.tscn")
	Game.start_haunted()
	# Earn a little progress we expect to LOSE.
	Game.add_ghost_energy(3)

	var reset_fired := {"n": 0}
	Game.haunted_reset.connect(func() -> void: reset_fired["n"] += 1)

	# Grace rule: two scares back-to-back only count once (grace window blocks
	# the second). We must let the grace timer drain between scares.
	Game.ghost_scare()
	_check("scare 1 registers", Game.scare == 1)
	Game.ghost_scare()  # inside grace -> ignored
	_check("second scare inside grace is ignored", Game.scare == 1)

	# Drain the grace window, then land scares 2..5.
	for pip in range(2, Game.scare_max + 1):
		await _drain_grace()
		Game.ghost_scare()
		if pip < Game.scare_max:
			_check("scare %d registers" % pip, Game.scare == pip)

	_check("5th scare fires haunted_reset", reset_fired["n"] == 1)

	# After the reset signal, simulate main.gd's handler calling start_haunted
	# (the scene does this; here we assert the state it produces).
	Game.start_haunted()
	_check("reset -> energy back to 0", Game.ghost_energy == 0)
	_check("reset -> caught back to 0", Game.ghosts_caught == 0)
	_check("reset -> quest back to CATCH", Game.haunted_quest == Game.HauntedQuest.CATCH)
	_check("reset -> scare meter empty", Game.scare == 0)
	# The things that must survive a scare-out:
	_check("reset keeps coins (42)", Game.coins == 42)
	_check("reset keeps owned gear", Game.owned.has("res://scenes/equipment/leather_cap.tscn"))
	_check("reset keeps main Stage (FOREST)", Game.stage == Game.Stage.FOREST)


# ---- portal spawns while playing & below cap; stops once quest DONE ----
func _test_portal_spawn_gating() -> void:
	Game.reset()
	Game.stage = Game.Stage.FOREST
	Game.area = "haunted"
	Game.start_haunted()

	var island_scene: PackedScene = load("res://scenes/haunted_island.tscn")
	var island := island_scene.instantiate()
	add_child(island)
	await _idle_frames(2)

	var portal := island.get_node_or_null("GhostPortal")
	_check("island has a GhostPortal", portal != null)

	# Let the portal spawn for a while; it should produce ghosts but never
	# exceed its cap. Wait by wall-clock so the spawn_interval actually elapses
	# (headless idle frames carry tiny deltas, so frame-count waiting wouldn't).
	await _wait_seconds(portal.spawn_interval * portal.max_ghosts + 4.0)
	var ghosts := get_tree().get_nodes_in_group("ghosts")
	_check("portal spawned at least one ghost", ghosts.size() >= 1)
	_check("portal respects the max cap", ghosts.size() <= portal.max_ghosts)

	# Flip to DONE: the portal must stop spawning (quest done = calm).
	Game.haunted_quest = Game.HauntedQuest.DONE
	for g in get_tree().get_nodes_in_group("ghosts"):
		(g as Node).queue_free()
	await _idle_frames(2)
	await _wait_seconds(portal.spawn_interval * 2.0 + 2.0)
	_check("no spawns once quest is DONE", get_tree().get_nodes_in_group("ghosts").size() == 0)

	island.queue_free()
	await _idle_frames(2)


# ---- revisiting after the portal is gone is calm (no spawns) ----
func _test_revisit_is_calm() -> void:
	Game.reset()
	Game.stage = Game.Stage.FOREST
	Game.area = "haunted"
	Game.portal_gone = true  # we already beat it this run
	Game.start_haunted()
	_check("revisit -> quest starts DONE", Game.haunted_quest == Game.HauntedQuest.DONE)

	var island_scene: PackedScene = load("res://scenes/haunted_island.tscn")
	var island := island_scene.instantiate()
	add_child(island)
	await _wait_seconds(8.0)
	_check("revisit stays calm (no ghosts spawn)", get_tree().get_nodes_in_group("ghosts").size() == 0)
	island.queue_free()
	await _idle_frames(2)


# ---- the placeholder ghost is gone from the project ----
func _test_no_placeholder() -> void:
	_check("placeholder scene removed", not ResourceLoader.exists("res://scenes/placeholder_ghost.tscn"))
	_check("placeholder script removed", not ResourceLoader.exists("res://scripts/placeholder_ghost.gd"))
	_check("real ghost scene present", ResourceLoader.exists("res://scenes/ghost.tscn"))
	_check("Ghost Sucker scene present", ResourceLoader.exists("res://scenes/equipment/ghost_vacuum.tscn"))


# ---- helpers ----

## Wait n idle (process) frames so tweens, queue_free and _process run.
func _idle_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Pump idle frames until `seconds` of wall-clock have actually elapsed, so
## timers that tick on real delta (spawn_interval, scare grace) advance.
func _wait_seconds(seconds: float) -> void:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < seconds:
		await get_tree().process_frame


## Let Game's scare grace timer tick all the way down (it drains on real delta
## inside Game._process), then a hair more for safety.
func _drain_grace() -> void:
	await _wait_seconds(Game.scare_grace + 0.2)
