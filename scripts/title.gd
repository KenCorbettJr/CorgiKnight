extends Node3D
## The title screen: the CorgiKnight holds its sword up high while the
## camera drifts around. Click Start (or press Enter) to begin!

const SWORD := preload("res://scenes/equipment/basic_sword.tscn")
const CAPE := preload("res://scenes/equipment/red_cape.tscn")
const GAME_SCENE := "res://scenes/main.tscn"

@onready var hero: Node3D = $Hero
@onready var hips: Node3D = $Hero/Hips
@onready var tail: Node3D = $Hero/Hips/Tail
@onready var arm_r: Node3D = $Hero/Hips/ArmR
@onready var arm_l: Node3D = $Hero/Hips/ArmL
@onready var camera: Camera3D = $Camera3D
@onready var start_button: Button = $UI/Menu/Start
@onready var quit_button: Button = $UI/Menu/Quit
@onready var logo: Label = $UI/Logo
@onready var fader: ColorRect = $UI/Fader

var _time := 0.0
var _starting := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Dress up our hero: sword raised to the sky, cape flowing.
	var sword := SWORD.instantiate() as Node3D
	$Hero/Hips/ArmR/HandRSocket.add_child(sword)
	sword.rotation.x = -2.07  # point the blade straight up
	var cape := CAPE.instantiate()
	$Hero/Hips/BackSocket.add_child(cape)
	arm_r.rotation = Vector3(PI, 0.0, 0.25)
	arm_l.rotation = Vector3(0.0, 0.0, -0.5)

	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	start_button.grab_focus()

	# Fade in from black and pop the logo in.
	fader.color.a = 1.0
	logo.pivot_offset = logo.size / 2.0
	logo.scale = Vector2(0.6, 0.6)
	var tween := create_tween()
	tween.tween_property(fader, "color:a", 0.0, 1.0)
	tween.parallel().tween_property(logo, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	# Proud breathing, happy tail, a little sword wiggle.
	hips.position.y = 0.3 + sin(_time * 2.0) * 0.015
	tail.rotation.y = sin(_time * 9.0) * 0.6
	arm_r.rotation.z = 0.25 + sin(_time * 1.5) * 0.05
	# Camera slowly drifts side to side.
	camera.position = Vector3(sin(_time * 0.25) * 1.2, 1.35 + sin(_time * 0.4) * 0.1, 4.0)
	camera.look_at(Vector3(0, 1.0, 0))
	# The logo gently bobs.
	logo.position.y = 40.0 + sin(_time * 1.6) * 6.0


func _on_start_pressed() -> void:
	if _starting:
		return
	_starting = true
	start_button.disabled = true
	quit_button.disabled = true
	var tween := create_tween()
	tween.tween_property(fader, "color:a", 1.0, 0.6)
	await tween.finished
	get_tree().change_scene_to_file(GAME_SCENE)
