extends Node3D
## A glowing magic artifact the Corgiwizard hid away (the Slime Stone in
## the well cave, the Golden Acorn in the forest shrine...).
## Taking it wakes up something BIG...

@export var item_name := "Slime Stone"
@export var prompt_text := "Take the Slime Stone"
## The function on the main scene that runs what happens next.
@export var on_taken := "take_artifact"

@onready var visual: Node3D = $Visual
@onready var glow: OmniLight3D = $Glow

var _time := 0.0
var _taken := false


func _ready() -> void:
	add_to_group("interactable")


func _process(delta: float) -> void:
	_time += delta
	visual.rotation.y += delta * 1.2
	visual.position.y = sin(_time * 2.0) * 0.1
	if not _taken:
		glow.light_energy = 2.0 + sin(_time * 4.0) * 0.6


## Called when the corgi presses E next to it.
func interact(_player: Node) -> void:
	if _taken:
		return
	_taken = true
	remove_from_group("interactable")
	if not Game.treasures.has(item_name):
		Game.treasures.append(item_name)
	Game.item_received.emit(item_name)
	# It flares up bright... then vanishes into the corgi's paws.
	var tween := create_tween()
	tween.tween_property(glow, "light_energy", 8.0, 0.6)
	tween.parallel().tween_property(visual, "scale", Vector3.ONE * 1.6, 0.6)
	tween.tween_property(visual, "scale", Vector3.ZERO, 0.3)
	tween.tween_property(glow, "light_energy", 0.0, 0.3)
	get_tree().current_scene.call(on_taken)
