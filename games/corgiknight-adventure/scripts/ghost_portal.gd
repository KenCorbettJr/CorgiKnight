extends Node3D
## The glowing portal the ghosts pour out of. It keeps spawning cute ghosts
## (up to a cap) so there's always energy to earn — until the Requiem Bell is
## rung and the portal is destroyed.

const GHOST_PATH := "res://scenes/ghost.tscn"

## Most ghosts allowed alive at once (so the island never gets swamped).
@export var max_ghosts := 6
## Seconds between spawns while below the cap.
@export var spawn_interval := 2.5
## How far out from the portal ghosts appear.
@export var spawn_radius := 3.5

@onready var swirl: Node3D = $Swirl
@onready var light: OmniLight3D = $Light

var _ghost_scene: PackedScene
var _spawn_timer := 0.0
var _time := 0.0
var _destroyed := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if ResourceLoader.exists(GHOST_PATH):
		_ghost_scene = load(GHOST_PATH)
	else:
		push_warning("GhostPortal: no ghost scene found (expected %s)." % GHOST_PATH)
	# If the portal was already beaten this run, start out quiet and dim.
	if Game.portal_gone:
		_go_quiet(true)


func _process(delta: float) -> void:
	_time += delta
	# Lazy swirl and a flickering glow.
	swirl.rotation.y += delta * 1.5
	if not _destroyed:
		light.light_energy = 2.4 + sin(_time * 5.0) * 0.5
		_spawn_timer -= delta
		if _spawn_timer <= 0.0 and _can_spawn():
			_spawn_timer = spawn_interval
			_spawn_ghost()


## Only spawn while playing on the haunted island and below the cap.
func _can_spawn() -> bool:
	if _ghost_scene == null or Game.area != "haunted":
		return false
	if Game.haunted_quest == Game.HauntedQuest.DONE:
		return false
	return get_tree().get_nodes_in_group("ghosts").size() < max_ghosts


func _spawn_ghost() -> void:
	var ghost := _ghost_scene.instantiate() as Node3D
	if ghost == null:
		return
	var angle := _rng.randf() * TAU
	var dist := _rng.randf_range(1.5, spawn_radius)
	var spot := global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	spot.y = 0.1
	# Add to the island (our parent) so ghosts aren't children of the portal.
	get_parent().add_child(ghost)
	ghost.global_position = spot
	Effects.poof(get_parent(), spot + Vector3.UP * 0.6, Color(0.6, 0.9, 0.7), 0.7, 6)


## Called when the Requiem Bell is rung: stop spawning and fizzle out, then
## shoo away any ghosts still floating about.
func destroy() -> void:
	if _destroyed:
		return
	_destroyed = true
	Effects.shockwave(get_parent(), global_position, Color(0.8, 1.0, 0.9, 0.8), 8.0)
	Effects.poof(get_parent(), global_position + Vector3.UP, Color(1.0, 0.9, 0.6), 2.0, 24)
	# The portal collapses in on itself.
	var tween := create_tween()
	tween.tween_property(swirl, "scale", Vector3.ZERO, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(light, "light_energy", 0.0, 0.8)
	# Shoo the remaining ghosts: they drift up and vanish.
	_shoo_ghosts()


func _shoo_ghosts() -> void:
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		var node := ghost as Node3D
		if node == null:
			continue
		node.remove_from_group("ghosts")
		if node.is_in_group("enemies"):
			node.remove_from_group("enemies")
		if node.is_in_group("interactable"):
			node.remove_from_group("interactable")
		var tween := node.create_tween()
		tween.tween_property(node, "global_position", node.global_position + Vector3.UP * 6.0, 1.2) \
			.set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(node, "scale", Vector3.ZERO, 1.2)
		tween.tween_callback(node.queue_free)


## Make the portal start out already-beaten (dim, silent) on later visits.
func _go_quiet(instant: bool) -> void:
	_destroyed = true
	if instant:
		swirl.scale = Vector3.ZERO
		light.light_energy = 0.0
