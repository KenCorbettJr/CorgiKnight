extends Node
## The game's memory: which part of the story you're on, how much slime jelly
## you've collected, and whether the controls are paused for a conversation.
##
## This is an "autoload", so any script can use it by writing `Game.`
## (for example `Game.add_jelly(1)` or `Game.stage`).

signal stage_changed(stage: Stage)
signal jelly_changed(count: int, goal: int)
signal item_received(item_name: String)
signal message(text: String)
signal dialogue_requested(speaker: String, lines: Array, on_done: Callable)

enum Stage {
	WAKE_UP,        ## Sleeping in bed at the start
	TALK_TO_MOM,    ## Awake: go talk to Mom
	COLLECT_JELLY,  ## Got the wooden sword: bonk slimes for jelly
	RETURN_TO_MOM,  ## Got enough jelly: bring it home
	DONE,           ## Quest complete!
}

@export var jelly_goal := 5

var stage: Stage = Stage.WAKE_UP
var jelly := 0
## True while talking or during a cutscene. The corgi can't move then.
var controls_locked := false


func reset() -> void:
	stage = Stage.WAKE_UP
	jelly = 0
	controls_locked = false


func set_stage(new_stage: Stage) -> void:
	stage = new_stage
	stage_changed.emit(stage)


func add_jelly(amount: int) -> void:
	jelly += amount
	jelly_changed.emit(jelly, jelly_goal)
	if stage == Stage.COLLECT_JELLY and jelly >= jelly_goal:
		set_stage(Stage.RETURN_TO_MOM)
		message.emit("That's enough jelly! Take it home to Mom.")


## Show a conversation. `on_done` (optional) runs after the last line.
func say(speaker: String, lines: Array, on_done: Callable = Callable()) -> void:
	dialogue_requested.emit(speaker, lines, on_done)


## The quest text shown in the top-right corner.
func quest_text() -> String:
	match stage:
		Stage.WAKE_UP:
			return ""
		Stage.TALK_TO_MOM:
			return "Talk to Mom"
		Stage.COLLECT_JELLY:
			return "Bonk slimes and collect Slime Jelly"
		Stage.RETURN_TO_MOM:
			return "Bring the Slime Jelly home to Mom"
		Stage.DONE:
			return "Explore the island!"
	return ""
