extends Node
## RunState — the standalone Haunted Mansion roguelike's OWN run authority.
##
## This autoload owns everything about a roguelike RUN and nothing about the old
## island adventure. It is deliberately INDEPENDENT of the island quest machine
## in game_state.gd (Game.stage / Game.haunted_quest / Game.area / portal_gone):
## nothing here reads or writes those. Death resets the run to level 1; clearing
## a level advances it and asks for a freshly generated next mansion.
##
## The loop lives in mansion_roguelike.gd, which listens to the signals below
## and (re)builds a procedurally generated mansion for the current level. A new
## MANSION IS GENERATED FOR EVERY LEVEL, LEVEL 1 INCLUDED — there is no island,
## no dock, no "sail here first" gate. level_generated(level, seed) is the proof
## of that: it fires with a nonzero, level-derived seed the moment a run begins.
##
## Scare meter: a run tracks its own scare pips here (not the island's). Filling
## the meter is DEATH — it resets the run to level 1 with a brand-new mansion.

## A fresh mansion was generated for `level` using `seed`. Emitted on run start
## (level 1), on every level advance, and on every death-reset. The generator
## (mansion_roguelike.gd) listens and rebuilds; tests listen to prove L1 is a
## generated mansion, that advancing regenerates, and that death resets to L1.
signal level_generated(level: int, seed: int)
## The run's scare meter changed (pips / max).
signal scare_changed(scare: int, scare_max: int)
## The corgi died this run (scare meter filled). `level_reached` is the level
## they died on, for an end-of-run message. The run has already been reset to 1.
signal died(level_reached: int)
## A level was fully cleared. `level` is the level just beaten.
signal level_cleared(level: int)
## General "run state changed" ping for HUD listeners.
signal run_changed

## The deepest level this roguelike goes. Beating it is a full win; the run then
## loops onward at MAX for an endless mode, but the permanent upgrade is granted.
const MAX_LEVEL := 5
## Rooms a level has: level 1 = 3 rooms ... level N = N + 2.
const BASE_ROOMS := 2
## How many scares end a run (death). Mirrors the island's default so the feel
## is identical, but this meter is the run's own, not the island's.
@export var scare_max := 5

## The level the active run is on (1-based). 0 means no run has started.
var level := 0
## Which room of the level we are in, 0-based.
var room_index := 0
## How many rooms the current level has.
var rooms_in_level := 0
## The scare pips taken this life. Filling it to scare_max is death.
var scare := 0
## True once start_run() has been called and the run has not been torn down.
var run_active := false
## The seed used to generate the current level's mansion. Nonzero while active;
## derived from the level so a level's layout is reproducible within a session
## but distinct from its neighbours.
var current_seed := 0
## Coins banked across this life (kept on level-clear, wiped on death/new run).
var coins := 0
## Permanent Ghost Sucker upgrade, earned by beating MAX_LEVEL. Survives death
## within a session (it is a meta reward), wiped only by reset().
var sucker_upgraded := false

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Begin a brand-new roguelike run at level 1 with a freshly generated mansion.
## This is the game's entry point — called the moment the standalone game boots
## into play. No island/quest/dock state is touched.
func start_run() -> void:
	coins = 0
	sucker_upgraded = sucker_upgraded  # meta reward persists across runs
	_begin_level(1)


## How many rooms level N holds.
func rooms_for_level(lvl: int) -> int:
	return lvl + BASE_ROOMS


## Produce a fresh, nonzero, level-derived seed for a mansion. Different levels
## get visibly different seeds (so layouts differ); a re-roll of the SAME level
## (e.g. death back to 1) still varies via the entropy salt.
func make_seed(lvl: int) -> int:
	var salt := _rng.randi()
	var s := int(hash("mansion-L%d-%d" % [lvl, salt]))
	if s == 0:
		s = 0x9E3779B9  # never hand out a zero seed
	return s


## (Re)start a level: set counts, roll a new mansion seed, announce it so the
## generator builds the rooms. Used for level 1, every advance, and death-reset.
func _begin_level(lvl: int) -> void:
	level = lvl
	room_index = 0
	rooms_in_level = rooms_for_level(lvl)
	scare = 0
	run_active = true
	current_seed = make_seed(lvl)
	scare_changed.emit(scare, scare_max)
	run_changed.emit()
	level_generated.emit(level, current_seed)


## The current room's challenge is beaten: bank coins, advance a room, and when
## the last room falls, clear the level and generate the NEXT mansion.
func clear_room(coins_awarded := 5) -> void:
	if not run_active:
		return
	coins += coins_awarded
	room_index += 1
	run_changed.emit()
	if room_index >= rooms_in_level:
		_clear_level()


## Every room of the level is done. Advance to the next level (a brand-new
## generated mansion), granting the permanent upgrade once MAX_LEVEL is beaten.
func _clear_level() -> void:
	var beaten := level
	if beaten >= MAX_LEVEL:
		sucker_upgraded = true  # permanent, granted once
	level_cleared.emit(beaten)
	# Advance into the next, freshly generated mansion. Past the max we loop at
	# MAX_LEVEL so the roguelike is endless but doesn't overflow the difficulty.
	var next_level := mini(beaten + 1, MAX_LEVEL) if beaten >= MAX_LEVEL else beaten + 1
	_begin_level(next_level)


## Add one scare pip (a ghost spooked the corgi). Filling the meter is DEATH:
## the run resets to level 1 with a brand-new generated mansion. Returns true if
## this scare was the fatal one.
func add_scare() -> bool:
	if not run_active:
		return false
	scare = mini(scare + 1, scare_max)
	scare_changed.emit(scare, scare_max)
	run_changed.emit()
	if scare >= scare_max:
		_die()
		return true
	return false


## DEATH: you were scared out. Roguelike rule — start completely over at level 1
## with a freshly generated mansion. Coins and per-run progress are lost; the
## permanent sucker upgrade (a meta reward) is kept.
func _die() -> void:
	var reached := level
	coins = 0
	died.emit(reached)
	_begin_level(1)


## Hard reset to a brand-new game (also wipes the permanent upgrade). Used by
## tests and a full "new game".
func reset() -> void:
	level = 0
	room_index = 0
	rooms_in_level = 0
	scare = 0
	run_active = false
	current_seed = 0
	coins = 0
	sucker_upgraded = false
	run_changed.emit()
