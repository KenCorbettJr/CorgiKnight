extends StaticBody3D
## The corgi's Mom. She gives you the wooden sword and your first quest.
##
## Walk up to her and press E to talk. What she says depends on how far
## along the story you are (see Game.Stage in game_state.gd).

const WOODEN_SWORD := preload("res://scenes/equipment/wooden_sword.tscn")

@export var npc_name := "Mom"
## Shown on screen as "[E] Talk to Mom" when you're close.
@export var prompt_text := "Talk to Mom"

@onready var model: Node3D = $Model
@onready var hips: Node3D = $Model/Hips
@onready var tail: Node3D = $Model/Hips/Tail
@onready var arm_r: Node3D = $Model/Hips/ArmR

var _time := 0.0
var _talking := false
var _player: Node3D


func _ready() -> void:
	add_to_group("interactable")


func _process(delta: float) -> void:
	_time += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D

	# Gentle breathing and a happy tail.
	hips.position.y = 0.3 + sin(_time * 2.0) * 0.012
	tail.rotation.y = sin(_time * 8.0) * 0.5

	# Turn to look at the corgi when it's nearby.
	if _player and global_position.distance_to(_player.global_position) < 6.0:
		var to_player := _player.global_position - global_position
		var yaw := atan2(-to_player.x, -to_player.z) - global_rotation.y
		model.rotation.y = lerp_angle(model.rotation.y, yaw, clampf(5.0 * delta, 0.0, 1.0))

	# Talk with her paws.
	var arm_target := 1.0 + sin(_time * 6.0) * 0.35 if _talking else 0.15
	arm_r.rotation.x = lerpf(arm_r.rotation.x, arm_target, clampf(8.0 * delta, 0.0, 1.0))


## Called by the game right after the corgi wakes up.
func greet() -> void:
	_talking = true
	Game.say(npc_name, [
		"Good morning, sleepyhead! You slept right through breakfast.",
		"Come here, sweetie. I have something for you.",
	], _done_talking)


## Called by the corgi when you press E next to Mom.
func interact(player: Node) -> void:
	_talking = true
	var stage: int = Game.stage
	if stage == Game.Stage.WAKE_UP or stage == Game.Stage.TALK_TO_MOM:
		Game.say(npc_name, [
			"Look at you. You're getting to be such a big pup...",
			"I think you're ready for this. It was my very first sword!",
		], _give_sword.bind(player))
	elif stage == Game.Stage.COLLECT_JELLY:
		Game.say(npc_name, [
			"How's it going, sweetie? You have %d of %d Slime Jelly so far." % [Game.jelly, Game.jelly_goal],
			"The slimes hop all over the island. There's a big purple one up on the old stone lookout!",
		], _done_talking)
	elif stage == Game.Stage.RETURN_TO_MOM:
		Game.say(npc_name, [
			"%d Slime Jelly! Look at you, my brave little knight!" % Game.jelly,
			"I'll make your favorite for dinner tonight... slime jelly toast!",
		], _finish_quest)
	else:
		var chats := [
			"Go explore, sweetie! Just be home before dark.",
			"Did you remember to wipe your paws?",
			"My little CorgiKnight. I'm so proud of you!",
		]
		Game.say(npc_name, [chats.pick_random()], _done_talking)


func _give_sword(player: Node) -> void:
	var item: EquipmentItem = player.call("equip", WOODEN_SWORD)
	if item:
		Game.item_received.emit(item.display_name)
	Game.set_stage(Game.Stage.COLLECT_JELLY)
	Game.say(npc_name, [
		"The slimes have been bouncing around the island again.",
		"Go out and bonk them, and bring me back %d Slime Jelly." % Game.jelly_goal,
		"Click (or press J) to swing your sword. And be careful out there!",
	], _done_talking)


func _finish_quest() -> void:
	_done_talking()
	Game.set_stage(Game.Stage.DONE)
	Game.message.emit("Quest complete!")


func _done_talking() -> void:
	_talking = false
