extends Node
## Acceptance test for the standalone Haunted Mansion roguelike loop.
##
## Proves the three roguelike invariants the owner asked for, headless, with
## PASS:/FAIL: lines and a nonzero exit on any failure:
##
##   (a) LEVEL 1 IS A GENERATED MANSION — starting a run generates level 1 as a
##       procedurally generated mansion (real room geometry exists, built from a
##       nonzero level-derived seed), with NO island / dock / quest dependency.
##   (b) A RUN ADVANCES LEVELS — clearing every room of a level increments the
##       run level and generates the NEXT mansion with a different seed/layout.
##   (c) DEATH RESETS TO LEVEL 1 — filling the scare meter (the death hook)
##       resets the run to level 1 with a freshly generated mansion.
##
## The loop is driven directly off the RunState autoload + a MansionRoguelike
## node (no rendering/input), so a given level's mansion is reproducible and the
## assertions are deterministic.
##
## Run it as the main scene so the autoloads (Game, RunState) boot:
##   Godot --headless --path games/corgiknight-mansion \
##     res://scenes/test/roguelike_loop_test.tscn

const MANSION := preload("res://scripts/mansion_roguelike.gd")

var _failures := 0
var _checks := 0


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if ok:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)


func _run() -> void:
	print("=== Haunted Mansion roguelike loop test ===")

	# A MansionRoguelike node rebuilds itself whenever RunState generates a
	# level. We don't begin_simulation(), so no ghosts/tweens — pure, fast,
	# deterministic generation + state.
	var mansion: Node3D = MANSION.new()
	add_child(mansion)
	await get_tree().process_frame

	_test_level1_is_generated_mansion(mansion)
	_test_run_advances_levels(mansion)
	_test_death_resets_to_level1(mansion)
	_test_no_island_quest_dependency()

	print("=== %d checks, %d failures ===" % [_checks, _failures])
	mansion.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


# ---- (a) LEVEL 1 IS A GENERATED MANSION -------------------------------------
func _test_level1_is_generated_mansion(mansion: Node3D) -> void:
	print("--- (a) level 1 is a generated mansion ---")
	RunState.reset()
	_check("a0. before start: no run active, level 0", not RunState.run_active and RunState.level == 0)

	RunState.start_run()
	# start_run must put us on level 1 with a nonzero, level-derived seed.
	_check("a1. start_run makes it level 1", RunState.level == 1)
	_check("a2. run is active", RunState.run_active)
	_check("a3. level-1 mansion has a nonzero generated seed", RunState.current_seed != 0)
	_check("a4. level 1 has 3 rooms (N+2)", RunState.rooms_in_level == 3)

	# The generator (listening to level_generated) built a real room: structural
	# geometry (floor + 4 walls) exists, and the room was seeded.
	_check("a5. a mansion room was built for level 1", mansion.room_node_count() == 1)
	_check("a6. the level-1 room has procedural structure (floor + walls)", mansion.room_structure_count() >= 5)
	_check("a7. the room layout was built from a nonzero seed", mansion.room_seed() != 0)


# ---- (b) A RUN ADVANCES LEVELS ----------------------------------------------
func _test_run_advances_levels(mansion: Node3D) -> void:
	print("--- (b) a run advances levels ---")
	RunState.reset()
	RunState.start_run()
	_check("b0. starting at level 1", RunState.level == 1)
	var l1_seed: int = RunState.current_seed
	var l1_room_seed: int = mansion.room_seed()

	var advanced := {"to": -1}
	RunState.level_cleared.connect(func(lvl: int) -> void: advanced["to"] = lvl, CONNECT_ONE_SHOT)

	# Clear every room of level 1 to beat the level.
	var rooms: int = RunState.rooms_in_level
	for i in rooms:
		# Mark the current room's challenge done, then walk through the exit.
		mansion.complete_current_challenge()
		mansion.advance_through_exit()

	_check("b1. clearing all rooms cleared level 1 (signal)", advanced["to"] == 1)
	_check("b2. run advanced to level 2", RunState.level == 2)
	_check("b3. level 2 has 4 rooms (N+2)", RunState.rooms_in_level == 4)
	_check("b4. a NEW mansion was generated for level 2 (seed changed)", RunState.current_seed != l1_seed)
	_check("b5. the level-2 room layout differs from level 1 (different seed)", mansion.room_seed() != l1_room_seed)
	_check("b6. a mansion room exists for the new level", mansion.room_node_count() == 1)
	_check("b7. the new room has procedural structure", mansion.room_structure_count() >= 5)

	# One more advance proves it keeps climbing, not just 1->2.
	var rooms2: int = RunState.rooms_in_level
	for i in rooms2:
		mansion.complete_current_challenge()
		mansion.advance_through_exit()
	_check("b8. clearing level 2 advances to level 3", RunState.level == 3)
	_check("b9. level 3 has 5 rooms", RunState.rooms_in_level == 5)


# ---- (c) DEATH RESETS TO LEVEL 1 --------------------------------------------
func _test_death_resets_to_level1(mansion: Node3D) -> void:
	print("--- (c) death resets to level 1 ---")
	RunState.reset()
	RunState.start_run()

	# Climb to level 3 so the reset is clearly a reset, not a no-op at level 1.
	for _lvl in 2:
		var rooms: int = RunState.rooms_in_level
		for i in rooms:
			mansion.complete_current_challenge()
			mansion.advance_through_exit()
	_check("c0. climbed to level 3 before dying", RunState.level == 3)
	var pre_death_seed: int = RunState.current_seed

	var died := {"reached": -1}
	RunState.died.connect(func(reached: int) -> void: died["reached"] = reached, CONNECT_ONE_SHOT)

	# Fill the scare meter — the death hook. add_scare caps at scare_max and the
	# final pip triggers the death/reset.
	var fatal := false
	for i in RunState.scare_max:
		mansion._scare_grace = 0.0  # ignore the grace debounce in the test
		fatal = RunState.add_scare()
	_check("c1. filling the scare meter is fatal (death fired)", fatal)
	_check("c2. died() reported the level reached (3)", died["reached"] == 3)
	_check("c3. death reset the run to level 1", RunState.level == 1)
	_check("c4. run is still active after the reset (new life)", RunState.run_active)
	_check("c5. level 1 again has 3 rooms", RunState.rooms_in_level == 3)
	_check("c6. a FRESH mansion was generated on death (new seed)", RunState.current_seed != pre_death_seed and RunState.current_seed != 0)
	_check("c7. the reset mansion has a real room with structure", mansion.room_node_count() == 1 and mansion.room_structure_count() >= 5)
	_check("c8. the scare meter was wiped on the new life", RunState.scare == 0)


# ---- de-island proof: the roguelike loop touches NO island quest state ------
func _test_no_island_quest_dependency() -> void:
	print("--- de-island: run is independent of the island quest machine ---")
	# The island quest machine (Game) must be irrelevant to the roguelike. Put
	# Game into its most hostile starting state (fresh game, not on the haunted
	# island, portal intact) and confirm a run still starts and generates L1.
	Game.reset()
	Game.area = "home"
	Game.portal_gone = false
	RunState.reset()
	RunState.start_run()
	_check("d1. run starts a generated level 1 regardless of Game.area", RunState.level == 1 and RunState.current_seed != 0)
	_check("d2. no portal/quest gate: run is active with portal intact", RunState.run_active and not Game.portal_gone)
	# RunState exposes none of the island quest fields; it is its own authority.
	_check("d3. RunState owns the run (has its own level/seed/scare state)",
		("level" in RunState) and ("current_seed" in RunState) and ("scare" in RunState))
