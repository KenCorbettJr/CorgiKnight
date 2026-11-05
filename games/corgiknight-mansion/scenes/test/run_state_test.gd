extends Node
## Headless state test for the standalone roguelike's RunState autoload.
##
## Adapted from the Dr Fluffles state test, but for the de-islanded run
## authority: RunState owns level/room/scare/seed with NO island quest coupling.
## Asserts the run-state invariants the roguelike loop depends on, prints one
## PASS/FAIL line per check, and quits non-zero on any failure.
##
##   Godot --headless --path games/corgiknight-mansion \
##     res://scenes/test/run_state_test.tscn

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
	print("=== RunState roguelike state test ===")

	_test_rooms_for_level()
	_test_start_run_level1()
	_test_clear_room_advances_and_levels()
	_test_scare_out_resets_to_level1()
	_test_level5_upgrade()
	_test_reset()

	print("=== %d checks, %d failures ===" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_rooms_for_level() -> void:
	var ok := true
	for n in range(1, RunState.MAX_LEVEL + 1):
		if RunState.rooms_for_level(n) != n + 2:
			ok = false
	_check("1. rooms_for_level(N) == N+2 for N in 1..5 (lvl1=3 ... lvl5=7)", ok)
	_check("1b. MAX_LEVEL == 5", RunState.MAX_LEVEL == 5)


func _test_start_run_level1() -> void:
	RunState.reset()
	_check("2. fresh: no run, level 0", not RunState.run_active and RunState.level == 0)
	RunState.start_run()
	_check("2b. start_run -> level 1, active", RunState.level == 1 and RunState.run_active)
	_check("2c. nonzero generated seed for level 1", RunState.current_seed != 0)
	_check("2d. level 1 has 3 rooms, room_index 0", RunState.rooms_in_level == 3 and RunState.room_index == 0)
	_check("2e. scare meter empty at run start", RunState.scare == 0)


func _test_clear_room_advances_and_levels() -> void:
	RunState.reset()
	RunState.start_run()
	var coins0: int = RunState.coins
	RunState.clear_room(5)
	_check("3. clear_room banks coins and advances room_index", RunState.coins == coins0 + 5 and RunState.room_index == 1)

	var won := {"level": -1}
	RunState.level_cleared.connect(func(lvl: int) -> void: won["level"] = lvl, CONNECT_ONE_SHOT)
	var l1_seed: int = RunState.current_seed
	# Clear the remaining rooms of level 1 (already cleared 1 of 3).
	RunState.clear_room()
	RunState.clear_room()
	_check("3b. clearing the last room cleared level 1 (signal)", won["level"] == 1)
	_check("3c. advanced to level 2 with a NEW seed", RunState.level == 2 and RunState.current_seed != l1_seed)
	_check("3d. level 2 has 4 rooms", RunState.rooms_in_level == 4)


func _test_scare_out_resets_to_level1() -> void:
	RunState.reset()
	RunState.start_run()
	# Advance to level 2 so the reset is visible.
	for i in RunState.rooms_in_level:
		RunState.clear_room()
	_check("4-pre. at level 2 before dying", RunState.level == 2)
	var seed_before: int = RunState.current_seed

	var died := {"reached": -1}
	RunState.died.connect(func(reached: int) -> void: died["reached"] = reached, CONNECT_ONE_SHOT)
	var fatal := false
	for i in RunState.scare_max:
		fatal = RunState.add_scare()
	_check("4. filling the meter is fatal", fatal)
	_check("4b. died() reported level reached (2)", died["reached"] == 2)
	_check("4c. death reset to level 1, still active", RunState.level == 1 and RunState.run_active)
	_check("4d. fresh mansion seed on reset", RunState.current_seed != seed_before and RunState.current_seed != 0)
	_check("4e. scare meter wiped on new life", RunState.scare == 0)
	_check("4f. coins reset to 0 on death", RunState.coins == 0)


func _test_level5_upgrade() -> void:
	RunState.reset()
	RunState.start_run()
	_check("5-pre. sucker not upgraded before beating level 5", not RunState.sucker_upgraded)
	# Climb from level 1 through level 5, clearing every room.
	for lvl in range(1, RunState.MAX_LEVEL + 1):
		_check("5-climb. on level %d with %d rooms" % [lvl, lvl + 2], RunState.level == lvl and RunState.rooms_in_level == lvl + 2)
		for i in RunState.rooms_in_level:
			RunState.clear_room()
	_check("5. beating level 5 granted the permanent Ghost Sucker upgrade", RunState.sucker_upgraded)


func _test_reset() -> void:
	RunState.start_run()
	RunState.clear_room()
	RunState.reset()
	_check("R. reset: level 0, no run", RunState.level == 0 and not RunState.run_active)
	_check("R. reset: seed 0, coins 0, scare 0", RunState.current_seed == 0 and RunState.coins == 0 and RunState.scare == 0)
	_check("R. reset: sucker upgrade cleared", not RunState.sucker_upgraded)
