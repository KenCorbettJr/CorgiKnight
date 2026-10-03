extends Node3D
## The rope hanging down from the well. Press E to climb back up.

@export var prompt_text := "Climb up the rope"


func _ready() -> void:
	add_to_group("interactable")


func interact(_player: Node) -> void:
	get_tree().current_scene.call("exit_cave")
