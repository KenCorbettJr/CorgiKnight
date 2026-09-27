extends CanvasLayer
## The on-screen display: hearts, quest tracker, jelly counter, the
## "Press E" prompt, the dialogue box, pop-up banners, and screen fades.

@onready var hearts: Control = $Hearts
@onready var quest_label: Label = $QuestLabel
@onready var jelly_label: Label = $JellyLabel
@onready var prompt_label: Label = $Prompt
@onready var banner: Label = $Banner
@onready var fader: ColorRect = $Fader
@onready var dialogue_box: PanelContainer = $DialogueBox
@onready var speaker_label: Label = $DialogueBox/Margin/VBox/Speaker
@onready var text_label: Label = $DialogueBox/Margin/VBox/Text
@onready var next_hint: Label = $DialogueBox/Margin/VBox/NextHint
@onready var controls_hint: Label = $Controls

var _health := 5
var _max_health := 5
var _lines: Array = []
var _line_index := 0
var _on_done: Callable
var _typing: Tween
var _banner_tween: Tween


func _ready() -> void:
	hearts.draw.connect(_draw_hearts)
	banner.visible = false
	dialogue_box.visible = false
	prompt_label.visible = false
	jelly_label.visible = false
	fader.visible = true
	fader.color.a = 1.0

	Game.stage_changed.connect(_on_stage_changed)
	Game.jelly_changed.connect(_on_jelly_changed)
	Game.item_received.connect(func(item_name: String) -> void: show_banner("You got the %s!" % item_name))
	Game.message.connect(show_banner)
	Game.dialogue_requested.connect(_on_dialogue_requested)
	_on_stage_changed(Game.stage)


# ---------------------------------------------------------------- Hearts

func set_health(current: int, maximum: int) -> void:
	_health = current
	_max_health = maximum
	hearts.queue_redraw()


func _draw_hearts() -> void:
	for i in _max_health:
		var center := Vector2(24 + i * 42, 24)
		var full := i < _health
		_draw_heart(center, 1.15, Color(0.15, 0.08, 0.08))  # dark outline
		_draw_heart(center, 1.0, Color(0.95, 0.25, 0.35) if full else Color(0.35, 0.3, 0.32))


func _draw_heart(center: Vector2, size: float, color: Color) -> void:
	var r := 8.0 * size
	hearts.draw_circle(center + Vector2(-7, -2) * size, r, color)
	hearts.draw_circle(center + Vector2(7, -2) * size, r, color)
	hearts.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-14.5, 1) * size,
		center + Vector2(14.5, 1) * size,
		center + Vector2(0, 17) * size,
	]), color)


# ---------------------------------------------------------------- Quest

func _on_stage_changed(_stage: int) -> void:
	var text: String = Game.quest_text()
	quest_label.text = ("Quest: " + text) if text != "" else ""
	jelly_label.visible = Game.stage == Game.Stage.COLLECT_JELLY or Game.stage == Game.Stage.RETURN_TO_MOM
	_on_jelly_changed(Game.jelly, Game.jelly_goal)


func _on_jelly_changed(count: int, goal: int) -> void:
	jelly_label.text = "Slime Jelly: %d / %d" % [mini(count, goal), goal]


## Shows "[E] Talk to Mom" style prompts. Pass "" to hide it.
func set_prompt(text: String) -> void:
	prompt_label.text = "[E]  " + text
	prompt_label.visible = text != "" and not dialogue_box.visible


# ---------------------------------------------------------------- Banners & fades

func show_banner(text: String, seconds := 2.5) -> void:
	banner.text = text
	banner.visible = true
	banner.modulate.a = 0.0
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.4)
	_banner_tween.tween_interval(seconds)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.6)
	_banner_tween.tween_callback(func() -> void: banner.visible = false)


func fade_in(seconds: float) -> void:
	fader.visible = true
	var tween := create_tween()
	tween.tween_property(fader, "color:a", 0.0, seconds)
	tween.tween_callback(func() -> void: fader.visible = false)
	await tween.finished


# ---------------------------------------------------------------- Dialogue

func _on_dialogue_requested(speaker: String, lines: Array, on_done: Callable) -> void:
	Game.controls_locked = true
	_lines = lines
	_line_index = 0
	_on_done = on_done
	speaker_label.text = speaker
	dialogue_box.visible = true
	controls_hint.visible = false
	prompt_label.visible = false
	_show_line()


func _show_line() -> void:
	text_label.text = str(_lines[_line_index])
	text_label.visible_ratio = 0.0
	next_hint.visible = false
	if _typing:
		_typing.kill()
	# Typewriter effect: letters appear one at a time.
	_typing = create_tween()
	_typing.tween_property(text_label, "visible_ratio", 1.0, text_label.text.length() * 0.025)
	_typing.tween_callback(func() -> void: next_hint.visible = true)


func _unhandled_input(event: InputEvent) -> void:
	if not dialogue_box.visible:
		return
	# A click that's just grabbing the mouse again shouldn't skip dialogue.
	if event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var advance := event.is_action_pressed("interact") or event.is_action_pressed("jump") \
		or event.is_action_pressed("attack")
	if not advance:
		return
	get_viewport().set_input_as_handled()
	if text_label.visible_ratio < 1.0:
		# Still typing: show the whole line right away.
		_typing.kill()
		text_label.visible_ratio = 1.0
		next_hint.visible = true
		return
	_line_index += 1
	if _line_index < _lines.size():
		_show_line()
	else:
		_close_dialogue()


func _close_dialogue() -> void:
	dialogue_box.visible = false
	controls_hint.visible = true
	var on_done := _on_done
	_on_done = Callable()
	# A tiny pause so the button press that closed the box doesn't also make
	# the corgi jump, swing, or start talking again.
	await get_tree().create_timer(0.2).timeout
	Game.controls_locked = false
	if on_done.is_valid():
		on_done.call()
