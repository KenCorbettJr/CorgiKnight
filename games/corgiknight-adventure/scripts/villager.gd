extends StaticBody3D
## A friendly corgi villager you can chat with.
##
## Pick a name, fur color, size and accessory in the Inspector, then type
## what they say in "Lines". Each time you talk to them they say the next
## line. Put a "|" in a line to split it into several speech bubbles.

@export var npc_name := "Villager"
## Shown as "[E] Talk to ___". Leave empty for "Talk to <name>".
@export var prompt_text := ""
@export var fur_color := Color(0.93, 0.56, 0.24)
@export_enum("None", "Straw Hat", "Glasses", "Bow Tie", "Apron", "Flower", "Sailor Hat") var accessory := 0
## 1.0 = grown-up corgi, 0.8 = little pup.
@export var size := 1.0
## What they say. They go through these in order, one per chat.
@export var lines: Array[String] = ["Hello there!"]
## What they say after you've got the Red Cape (leave empty to keep using Lines).
@export var cape_lines: Array[String] = []
## Where they run and hide when the Corgiwizard attacks (their front door).
## Leave at (0, 0, 0) to just duck down where they stand.
@export var hide_spot := Vector3.ZERO

@onready var model: Node3D = $Model
@onready var hips: Node3D = $Model/Hips
@onready var tail: Node3D = $Model/Hips/Tail
@onready var arm_r: Node3D = $Model/Hips/ArmR

var _time := 0.0
var _talking := false
var _line_index := 0
var _player: Node3D
var _home_position := Vector3.ZERO
var _hiding := false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("villagers")
	_home_position = position
	if prompt_text == "":
		prompt_text = "Talk to " + npc_name
	model.scale = Vector3.ONE * size
	_time = randf() * 10.0  # so villagers don't all breathe in sync
	_apply_fur_color()
	_add_accessory()


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

	# Talk with their paws.
	var arm_target := 1.0 + sin(_time * 6.0) * 0.35 if _talking else 0.15
	arm_r.rotation.x = lerpf(arm_r.rotation.x, arm_target, clampf(8.0 * delta, 0.0, 1.0))


## Called by the corgi when you press E nearby.
func interact(_player_node: Node) -> void:
	var pool := lines
	if Game.stage >= Game.Stage.DONE and not cape_lines.is_empty():
		pool = cape_lines
	if pool.is_empty():
		return
	_talking = true
	var line := pool[_line_index % pool.size()]
	_line_index += 1
	Game.say(npc_name, Array(line.split("|")), _done_talking)


func _done_talking() -> void:
	_talking = false


# ---------------------------------------------------------------- Hiding

## Run to the front door (or duck down) and disappear. Eek!
func run_home() -> void:
	if _hiding:
		return
	_hiding = true
	remove_from_group("interactable")
	_shout("Eek!")
	var tween := create_tween()
	if hide_spot == Vector3.ZERO:
		tween.tween_interval(0.5)
	else:
		var target := hide_spot
		target.y = position.y
		var trip := position.distance_to(target) / 5.0
		model.rotation.y = atan2(-(target.x - position.x), -(target.z - position.z)) - rotation.y
		tween.tween_property(self, "position", target, maxf(trip, 0.3))
		# Little panicked hops on the way.
		var hops := create_tween().set_loops(int(maxf(trip, 0.3) / 0.2) + 1)
		hops.tween_property(model, "position:y", 0.15, 0.1)
		hops.tween_property(model, "position:y", 0.0, 0.1)
	tween.tween_property(model, "scale", Vector3.ZERO, 0.2)
	tween.tween_callback(func() -> void: visible = false)
	$CollisionShape3D.set_deferred("disabled", true)


## Come back out now that it's safe.
func come_out() -> void:
	if not _hiding:
		return
	_hiding = false
	visible = true
	position = hide_spot if hide_spot != Vector3.ZERO else _home_position
	position.y = _home_position.y
	model.position = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3.ONE * size, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", _home_position, maxf(position.distance_to(_home_position) / 3.0, 0.1))
	tween.tween_callback(_finish_coming_out)
	_shout("Hooray!")


func _finish_coming_out() -> void:
	$CollisionShape3D.disabled = false
	add_to_group("interactable")


## A little speech bubble above their head.
func _shout(text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.8 * size, 0)
	add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y + 0.5, 1.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free)


# ---------------------------------------------------------------- Looks

## Swap the orange fur for this villager's fur color.
func _apply_fur_color() -> void:
	var fur: StandardMaterial3D = null
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		var mat := mi.material_override
		if mat and mat.resource_path.ends_with("corgi_orange.tres"):
			if fur == null:
				fur = mat.duplicate() as StandardMaterial3D
				fur.albedo_color = fur_color
			mi.material_override = fur


func _toon(color: Color, outline := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	if outline:
		mat.next_pass = load("res://materials/outline.tres")
	return mat


func _add_part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3,
		rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _add_accessory() -> void:
	var head: Node3D = $Model/Hips/Head/HeadSocket
	var chest: Node3D = $Model/Hips/ChestSocket
	match accessory:
		1:  # Straw Hat
			var straw := _toon(Color(0.95, 0.83, 0.45), true)
			var brim := CylinderMesh.new()
			brim.top_radius = 0.42
			brim.bottom_radius = 0.42
			brim.height = 0.03
			_add_part(head, brim, straw, Vector3(0, 0.03, 0))
			var crown := CylinderMesh.new()
			crown.top_radius = 0.19
			crown.bottom_radius = 0.23
			crown.height = 0.16
			_add_part(head, crown, straw, Vector3(0, 0.12, 0))
			var band := CylinderMesh.new()
			band.top_radius = 0.235
			band.bottom_radius = 0.235
			band.height = 0.04
			_add_part(head, band, _toon(Color(0.85, 0.25, 0.25)), Vector3(0, 0.07, 0))
		2:  # Glasses
			var black := _toon(Color(0.1, 0.08, 0.08))
			var ring := TorusMesh.new()
			ring.inner_radius = 0.045
			ring.outer_radius = 0.062
			for x in [-0.12, 0.12]:
				_add_part(head, ring, black, Vector3(x, -0.07, -0.285), Vector3(PI / 2.0, 0, 0))
			var bridge := BoxMesh.new()
			bridge.size = Vector3(0.07, 0.014, 0.014)
			_add_part(head, bridge, black, Vector3(0, -0.06, -0.3))
		3:  # Bow Tie
			var blue := _toon(Color(0.3, 0.5, 0.95), true)
			var loop := SphereMesh.new()
			loop.radius = 0.06
			loop.height = 0.12
			for x in [-0.07, 0.07]:
				_add_part(chest, loop, blue, Vector3(x, 0.12, -0.2), Vector3.ZERO, Vector3(1.3, 0.8, 0.5))
			var knot := SphereMesh.new()
			knot.radius = 0.035
			knot.height = 0.07
			_add_part(chest, knot, blue, Vector3(0, 0.12, -0.22))
		4:  # Apron
			var apron := BoxMesh.new()
			apron.size = Vector3(0.36, 0.38, 0.05)
			_add_part(chest, apron, _toon(Color(0.98, 0.95, 0.98)), Vector3(0, -0.12, -0.23), Vector3(-0.12, 0, 0))
		6:  # Sailor Hat
			var white := _toon(Color(0.97, 0.97, 1.0), true)
			var top := CylinderMesh.new()
			top.top_radius = 0.26
			top.bottom_radius = 0.24
			top.height = 0.12
			_add_part(head, top, white, Vector3(0, 0.1, 0))
			var band := CylinderMesh.new()
			band.top_radius = 0.245
			band.bottom_radius = 0.245
			band.height = 0.05
			_add_part(head, band, _toon(Color(0.2, 0.3, 0.7)), Vector3(0, 0.05, 0))
			var visor := CylinderMesh.new()
			visor.top_radius = 0.14
			visor.bottom_radius = 0.14
			visor.height = 0.02
			_add_part(head, visor, _toon(Color(0.1, 0.1, 0.2)), Vector3(0, 0.03, -0.22), Vector3.ZERO, Vector3(1.2, 1, 0.8))
		5:  # Flower
			var pink := _toon(Color(1.0, 0.55, 0.72), true)
			var petal := SphereMesh.new()
			petal.radius = 0.05
			petal.height = 0.1
			for i in 5:
				var angle := TAU * i / 5.0
				_add_part(head, petal, pink, Vector3(0.14 + cos(angle) * 0.06, 0.12 + sin(angle) * 0.06, -0.12))
			var middle := SphereMesh.new()
			middle.radius = 0.035
			middle.height = 0.07
			_add_part(head, middle, _toon(Color(1, 0.9, 0.3)), Vector3(0.14, 0.12, -0.14))
