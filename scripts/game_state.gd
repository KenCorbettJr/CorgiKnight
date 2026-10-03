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
signal coins_changed(coins: int)
signal shop_requested(shopkeeper: Node)
## Captain Salty is ready to sail ("forest" or "home").
signal travel_requested(destination: String)
## Time to drop a heart pickup here (every few enemies you defeat).
signal heart_drop(where: Vector3)

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

## Every this many enemies defeated, one drops a heart.
@export var hearts_every := 3

## How many of each thing Mom asks for.
@export var jelly_goal := 5
@export var wood_goal := 5

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
## Where the corgi is right now: "home", "cave" or "forest".
var area := "home"
## Enemies defeated since the last heart dropped.
var _kills := 0
var _told_about_well := false

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
	area = "home"
	_kills = 0
	_told_about_well = false


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


## The quest text shown in the top-right corner.
func quest_text() -> String:
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
