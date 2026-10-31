extends Node
## The game's memory: which part of the story you're on, what you've
## collected (slime jelly, wood...), and whether the controls are paused for
## a conversation.
##
## This is an "autoload", so any script can use it by writing `Game.`
## (for example `Game.add_item("wood", 1)` or `Game.stage`).

signal stage_changed(stage: Stage)
signal item_count_changed(kind: String, count: int)
signal item_received(item_name: String)
signal message(text: String)
signal dialogue_requested(speaker: String, lines: Array, on_done: Callable)
## A little pop-up menu: a prompt and a list of {"text":..., "value":...}
## options. `on_choice` is called with the chosen option's value.
signal choice_requested(prompt: String, options: Array, on_choice: Callable)
signal coins_changed(coins: int)
signal shop_requested(shopkeeper: Node)
## Captain Salty is ready to sail ("forest", "home" or "haunted").
signal travel_requested(destination: String)
## Time to drop a heart pickup here (every few enemies you defeat).
signal heart_drop(where: Vector3)

## --- Haunted Island adventure ---
## The scare meter changed (how many pips are filled, out of the max).
signal scare_changed(filled: int, maximum: int)
## The ghost-energy / ghosts-caught counters changed.
signal ghost_energy_changed(energy: int, caught: int)
## The corgi got too scared! The haunted adventure needs to reset.
## (main.gd listens and puts the corgi back at the haunted dock.)
signal haunted_reset
## The Requiem Bell was rung with enough energy: destroy the portal!
## (the haunted island scene listens and plays the big finale.)
signal portal_destroyed

enum Stage {
	WAKE_UP,        ## Sleeping in bed at the start
	TALK_TO_MOM,    ## Awake: go talk to Mom
	COLLECT_JELLY,  ## Got the wooden sword: bonk slimes for jelly
	RETURN_TO_MOM,  ## Got enough jelly: bring it home
	CHOP_WOOD,      ## Got the axe: chop trees for firewood
	RETURN_WOOD,    ## Got enough wood: bring it home
	DONE,           ## Got the red cape. Now buy all the armor at the shop...
	BOSS_FIGHT,     ## The Corgiwizard summoned the King Slime!
	SET_SAIL,       ## King Slime defeated: the boat to the next island is free
	FOREST,         ## Exploring the Whispering Woods
	BOSS2_FIGHT,    ## The Corgiwizard summoned the Giant Cyclops!
	FOREST_DONE,    ## Giant Cyclops defeated
}

## The optional Haunted Island side-adventure. This is tracked SEPARATELY
## from the main story's Stage, so it never touches coins, gear or Stage.
enum HauntedQuest {
	NONE,        ## Haven't gone to the haunted island yet
	CATCH,       ## Quest 1: suck up a bunch of ghosts
	FIND_BELL,   ## Quest 2: find the Requiem Bell and ring it
	DONE,        ## Portal destroyed, the island is calm
}

## Every this many enemies defeated, one drops a heart.
@export var hearts_every := 3

## How many of each thing Mom asks for.
@export var jelly_goal := 5
@export var wood_goal := 5

## --- Haunted Island tuning (tweak in the Inspector!) ---
## How many ghosts you must suck up to finish quest 1.
@export var ghosts_goal := 8
## How much ghost energy the Requiem Bell needs before it can ring.
@export var bell_energy_cost := 10
## How many scares (touches) fill the whole scare meter.
@export var scare_max := 5
## Seconds of safety after a scare, so one ghost can't drain the meter at once.
@export var scare_grace := 2.0

## Nice names for the things you can collect.
const ITEM_NAMES := {"jelly": "Slime Jelly", "wood": "Wood", "tooth": "Cyclops Tooth"}
## How many coins the shops pay for each one.
const SELL_PRICES := {"jelly": 3, "wood": 2, "tooth": 10}
## The armor you need to own before the Corgiwizard shows up.
const ARMOR_PATHS: Array[String] = [
	"res://scenes/equipment/leather_cap.tscn",
	"res://scenes/equipment/wooden_shield.tscn",
	"res://scenes/equipment/speedy_boots.tscn",
	"res://scenes/equipment/iron_helmet.tscn",
]

var stage: Stage = Stage.WAKE_UP
## How many of each thing you've picked up, e.g. {"jelly": 3, "wood": 1}
var items := {}
## True while talking or in a menu. The corgi can't move then.
var controls_locked := false
## True during a movie-like story scene (like the Corgiwizard showing up).
## Scenes can overlap (dying during the boss scene), so this counts how many
## are running: setting it true adds one, setting it false removes one.
var in_cutscene: bool:
	get:
		return _cutscene_count > 0
	set(value):
		_cutscene_count = _cutscene_count + 1 if value else maxi(_cutscene_count - 1, 0)
var _cutscene_count := 0
## Money for the shop.
var coins := 0
## Scene paths of things bought at the shop (so you can't buy them twice).
var owned: Array[String] = []
## Found the Slime Stone in the cave under the village well?
var artifact_found := false
## Names of the magic treasures you've found (Slime Stone, Golden Acorn...),
## shown in the inventory.
var treasures: Array[String] = []
## Where the corgi is right now: "home", "cave", "forest" or "haunted".
var area := "home"
## Enemies defeated since the last heart dropped.
var _kills := 0
var _told_about_well := false

## --- Haunted Island adventure state ---
## Which haunted quest you're on (see HauntedQuest). This lives apart from the
## main story Stage, so it never touches coins, gear or Stage.
var haunted_quest: HauntedQuest = HauntedQuest.NONE
## Ghost energy you've banked by sucking ghosts up (spent to ring the bell).
var ghost_energy := 0
## How many ghosts you've caught (counts toward quest 1).
var ghosts_caught := 0
## Have you already destroyed the portal once? Then the island stays calm.
var portal_gone := false
## How full the scare meter is right now (0..scare_max).
var scare := 0
## Counts down the grace period after a scare (no more scares while above 0).
var _scare_grace_time := 0.0

## Shortcut so older code can still ask for Game.jelly.
var jelly: int:
	get:
		return count("jelly")


func reset() -> void:
	stage = Stage.WAKE_UP
	items = {}
	controls_locked = false
	_cutscene_count = 0
	coins = 0
	owned = []
	artifact_found = false
	treasures = []
	area = "home"
	_kills = 0
	_told_about_well = false
	# The haunted adventure starts fresh too (but it's forgotten on purpose
	# only here, at a brand-new game: portal_gone is remembered within a run).
	haunted_quest = HauntedQuest.NONE
	ghost_energy = 0
	ghosts_caught = 0
	portal_gone = false
	scare = 0
	_scare_grace_time = 0.0


## The grace timer ticks down every frame (used so one ghost touching you
## over and over can't fill the whole scare meter instantly).
func _process(delta: float) -> void:
	if _scare_grace_time > 0.0:
		_scare_grace_time = maxf(_scare_grace_time - delta, 0.0)


func set_stage(new_stage: Stage) -> void:
	stage = new_stage
	stage_changed.emit(stage)


func count(kind: String) -> int:
	return items.get(kind, 0)


func goal(kind: String) -> int:
	return wood_goal if kind == "wood" else jelly_goal


func add_item(kind: String, amount: int = 1) -> void:
	items[kind] = count(kind) + amount
	item_count_changed.emit(kind, count(kind))
	if stage == Stage.COLLECT_JELLY and kind == "jelly" and count("jelly") >= jelly_goal:
		set_stage(Stage.RETURN_TO_MOM)
		message.emit("That's enough jelly! Take it home to Mom.")
	elif stage == Stage.CHOP_WOOD and kind == "wood" and count("wood") >= wood_goal:
		set_stage(Stage.RETURN_WOOD)
		message.emit("That's plenty of wood! Take it home to Mom.")


func remove_item(kind: String, amount: int) -> void:
	items[kind] = maxi(count(kind) - amount, 0)
	item_count_changed.emit(kind, count(kind))


## How many you can sell without using up what Mom's quest needs.
func sellable(kind: String) -> int:
	var keep := goal(kind) if quest_item() == kind else 0
	return maxi(count(kind) - keep, 0)


## How many of the shop's armor pieces you own.
func armor_owned_count() -> int:
	var total := 0
	for path in ARMOR_PATHS:
		if owned.has(path):
			total += 1
	return total


func has_all_armor() -> bool:
	return armor_owned_count() >= ARMOR_PATHS.size()


## Call after buying something so the quest tracker updates.
func notify_owned() -> void:
	stage_changed.emit(stage)
	if stage == Stage.DONE and has_all_armor() and not _told_about_well:
		_told_about_well = true
		message.emit("You hear a strange humming from the village well...")


## The well cave opens once Mom's quests are done and you have all the armor.
func cave_open() -> bool:
	return stage == Stage.DONE and has_all_armor() and not artifact_found


## Call when any bad guy is defeated. Every few, a heart drops.
func enemy_defeated(where: Vector3) -> void:
	_kills += 1
	if _kills >= hearts_every:
		_kills = 0
		heart_drop.emit(where)


## Can the corgi move and act right now?
func can_play() -> bool:
	return not controls_locked and not in_cutscene


func add_coins(amount: int) -> void:
	coins = maxi(coins + amount, 0)
	coins_changed.emit(coins)


## Which collectable the current quest is about ("" if none).
func quest_item() -> String:
	if stage == Stage.COLLECT_JELLY or stage == Stage.RETURN_TO_MOM:
		return "jelly"
	if stage == Stage.CHOP_WOOD or stage == Stage.RETURN_WOOD:
		return "wood"
	return ""


## Show a conversation. `on_done` (optional) runs after the last line.
func say(speaker: String, lines: Array, on_done: Callable = Callable()) -> void:
	dialogue_requested.emit(speaker, lines, on_done)


## Pop up a little menu of choices. Each option is a Dictionary like
## {"text": "Sail home", "value": "home"}. `on_choice` gets the chosen value.
func choose(prompt: String, options: Array, on_choice: Callable) -> void:
	choice_requested.emit(prompt, options, on_choice)


## The quest text shown in the top-right corner.
func quest_text() -> String:
	# On the haunted island the side-adventure's quest takes over the tracker.
	if area == "haunted":
		match haunted_quest:
			HauntedQuest.CATCH:
				return "Suck up the ghosts! (%d/%d)" % [mini(ghosts_caught, ghosts_goal), ghosts_goal]
			HauntedQuest.FIND_BELL:
				return "Find the Requiem Bell and ring it"
			HauntedQuest.DONE:
				return "The portal is destroyed! The island is calm."
		return "Explore the haunted island..."
	match stage:
		Stage.TALK_TO_MOM:
			return "Talk to Mom"
		Stage.COLLECT_JELLY:
			return "Bonk slimes and collect Slime Jelly"
		Stage.RETURN_TO_MOM:
			return "Bring the Slime Jelly home to Mom"
		Stage.CHOP_WOOD:
			return "Chop down trees and collect Wood"
		Stage.RETURN_WOOD:
			return "Bring the Wood home to Mom"
		Stage.DONE:
			if not has_all_armor():
				return "Buy all the armor at Biscuit's Shop (%d/%d)" % [armor_owned_count(), ARMOR_PATHS.size()]
			if not artifact_found:
				return "Climb down the village well and explore the cave"
			return "Explore the island!"
		Stage.BOSS_FIGHT:
			return "Defeat the King Slime!"
		Stage.SET_SAIL:
			return "Find Captain Salty at the north dock"
		Stage.FOREST:
			if area == "forest":
				return "Find what the Corgiwizard hid in the Whispering Woods"
			return "Sail back to the Whispering Woods"
		Stage.BOSS2_FIGHT:
			return "Defeat the Giant Cyclops!"
		Stage.FOREST_DONE:
			return "Explore! (More islands coming soon)"
	return ""

# ---------------------------------------------------------------- Haunted Island

## True once the optional haunted adventure is available: the curse over the
## home island is broken (you've reached the forest), and you're not in the
## middle of the Giant Cyclops boss fight.
func haunted_available() -> bool:
	return stage >= Stage.FOREST and stage != Stage.BOSS2_FIGHT


## Start (or restart) the haunted adventure fresh at quest 1. Called when you
## first arrive, and again whenever the corgi gets scared off. This only ever
## touches the haunted state — coins, gear and the main Stage are untouched.
func start_haunted() -> void:
	haunted_quest = HauntedQuest.DONE if portal_gone else HauntedQuest.CATCH
	ghost_energy = 0
	ghosts_caught = 0
	scare = 0
	_scare_grace_time = 0.0
	scare_changed.emit(scare, scare_max)
	ghost_energy_changed.emit(ghost_energy, ghosts_caught)
	stage_changed.emit(stage)  # refresh the quest tracker text


## A ghost touched the corgi! Fill one pip of the scare meter (unless we're
## still in the grace window from the last scare). Ghosts never cost hearts.
## When the meter fills up, the whole haunted adventure resets.
func ghost_scare() -> void:
	# Only matters on the haunted island, and not once the island is calm.
	if area != "haunted" or haunted_quest == HauntedQuest.DONE:
		return
	if _scare_grace_time > 0.0:
		return  # still safe from the last scare
	if not can_play():
		return  # don't rack up scares during cutscenes / the reset itself
	scare = mini(scare + 1, scare_max)
	_scare_grace_time = scare_grace
	scare_changed.emit(scare, scare_max)
	if scare >= scare_max:
		_scare_out()


## Too scared! Wipe only the haunted progress and send the corgi back to the
## dock. main.gd listens for `haunted_reset` and handles the trip + message.
func _scare_out() -> void:
	message.emit("Too scared! You drop everything and run for the dock!")
	haunted_reset.emit()


## Called by a ghost when it gets sucked up: bank its energy AND count it
## toward quest 1. (This is the other half of the worker-B contract.)
func add_ghost_energy(amount: int = 1) -> void:
	if area != "haunted":
		return
	ghost_energy += amount
	ghosts_caught += 1
	ghost_energy_changed.emit(ghost_energy, ghosts_caught)
	# Quest 1 done? Send the corgi off to find the Requiem Bell.
	if haunted_quest == HauntedQuest.CATCH and ghosts_caught >= ghosts_goal:
		haunted_quest = HauntedQuest.FIND_BELL
		stage_changed.emit(stage)
		message.emit("That's plenty of ghosts! Now find the Requiem Bell in the mansion.")


## Is there enough banked energy to ring the Requiem Bell?
func can_ring_bell() -> bool:
	return ghost_energy >= bell_energy_cost


## How many more ghosts' worth of energy the bell still needs.
func bell_energy_missing() -> int:
	return maxi(bell_energy_cost - ghost_energy, 0)


## Ring the bell for real: spend the energy and destroy the portal. The
## haunted island scene listens for `portal_destroyed` to play the finale.
func ring_bell() -> void:
	ghost_energy = maxi(ghost_energy - bell_energy_cost, 0)
	haunted_quest = HauntedQuest.DONE
	portal_gone = true
	ghost_energy_changed.emit(ghost_energy, ghosts_caught)
	stage_changed.emit(stage)
	portal_destroyed.emit()
