extends Node
## Headless boot smoke test for the standalone island adventure.
##
## Run it as the main scene (so the project's autoloads — InputSetup, Game —
## boot) to prove that after the monorepo split every top-level scene still
## loads and instantiates with ZERO load errors and no dangling res:// refs:
##   Godot --headless --path games/corgiknight-adventure \
##         --main-scene res://scenes/test/boot_smoke_test.tscn
##
## It asserts:
##   * the autoloads named in project.godot exist and are reachable,
##   * the configured main scene (title) loads,
##   * the real gameplay scene (main.tscn) + HUD load and instantiate,
##   * every .tscn under scenes/ loads and instantiates (catches a broken
##     ext_resource / missing resource the move might have exposed).
## Prints PASS/FAIL lines and quits non-zero on any failure.

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
	print("=== Boot smoke test (standalone adventure) ===")

	_test_autoloads()
	_test_main_scene_configured()
	_test_key_scenes_instantiate()
	_test_all_scenes_load()

	print("=== %d checks, %d failures ===" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---- the autoloads project.godot declares are live ----
func _test_autoloads() -> void:
	var root := get_tree().root
	_check("autoload InputSetup is live", root.get_node_or_null("InputSetup") != null)
	_check("autoload Game is live", root.get_node_or_null("Game") != null)
	# Game must expose the island state machine the adventure relies on.
	var game := root.get_node_or_null("Game")
	_check("Game exposes reset()", game != null and game.has_method("reset"))
	_check("Game exposes add_coins()", game != null and game.has_method("add_coins"))


# ---- the configured main scene resolves and loads ----
func _test_main_scene_configured() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	_check("project.godot declares a main scene", main_scene != "")
	_check("main scene resource exists (%s)" % main_scene, ResourceLoader.exists(main_scene))
	var packed := load(main_scene)
	_check("main scene loads as PackedScene", packed is PackedScene)


# ---- title -> gameplay -> HUD all load AND instantiate cleanly ----
func _test_key_scenes_instantiate() -> void:
	for path in [
		"res://scenes/title.tscn",
		"res://scenes/main.tscn",
		"res://scenes/hud.tscn",
	]:
		_check("exists %s" % path, ResourceLoader.exists(path))
		var packed := load(path) as PackedScene
		_check("loads %s" % path, packed != null)
		if packed != null:
			var inst := packed.instantiate()
			_check("instantiates %s" % path, inst != null)
			if inst != null:
				inst.free()


# ---- every top-level .tscn under scenes/ loads + instantiates ----
func _test_all_scenes_load() -> void:
	var scenes := _collect_scenes("res://scenes")
	_check("found gameplay scenes to check", scenes.size() > 0)
	for path in scenes:
		var packed := load(path) as PackedScene
		if packed == null:
			_check("loads %s" % path, false)
			continue
		var inst := packed.instantiate()
		_check("loads+instantiates %s" % path, inst != null)
		if inst != null:
			inst.free()


## Recursively gather every .tscn under `dir`, skipping the test/ folder so the
## smoke test never tries to instantiate the other test scenes (which spawn
## ghosts / drive timers).
func _collect_scenes(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if name != "test":
				out.append_array(_collect_scenes(full))
		elif name.ends_with(".tscn"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
