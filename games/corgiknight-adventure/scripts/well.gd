extends StaticBody3D
## The village well. Once you're ready (all the armor from Biscuit's shop),
## it starts to glow and hum, and you can climb down into the cave below.

## Shown as "[E] ..." when you're next to the well.
var prompt_text: String:
	get:
		return "Climb down the well" if Game.cave_open() else "Look into the well"

@onready var glow: OmniLight3D = $Glow
@onready var rope: Node3D = $Rope

var _time := 0.0


func _ready() -> void:
	add_to_group("interactable")


func _process(delta: float) -> void:
	_time += delta
	var open: bool = Game.cave_open()
	glow.visible = open
	rope.visible = open
	if open:
		glow.light_energy = 2.0 + sin(_time * 3.0) * 0.8


func interact(_player: Node) -> void:
	if Game.cave_open():
		get_tree().current_scene.call("enter_cave")
	elif Game.artifact_found:
		Game.say("Well", ["The well is quiet now. The strange humming is gone."])
	elif Game.stage < Game.Stage.DONE:
		Game.say("Well", ["It's a deep, dark well. Brrr!|Too spooky to climb down... for now."])
	else:
		Game.say("Well", [
			"You hear a faint humming from deep, deep down...",
			"Better get all the armor from Biscuit's shop before climbing down there!",
		])
