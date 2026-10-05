extends CanvasLayer
## The on-screen display: hearts, quest tracker, jelly counter, the
## "Press E" prompt, the dialogue box, the shop, the inventory (press I),
## pop-up banners, and screen fades.

@onready var hearts: Control = $Hearts
@onready var quest_label: Label = $QuestLabel
@onready var collect_label: Label = $CollectLabel
@onready var prompt_label: Label = $Prompt
@onready var banner: Label = $Banner
@onready var fader: ColorRect = $Fader
@onready var dialogue_box: PanelContainer = $DialogueBox
@onready var speaker_label: Label = $DialogueBox/Margin/VBox/Speaker
@onready var text_label: Label = $DialogueBox/Margin/VBox/Text
@onready var next_hint: Label = $DialogueBox/Margin/VBox/NextHint
@onready var controls_hint: Label = $Controls
@onready var coins_label: Label = $CoinsLabel
@onready var boss_bar: Control = $BossBar
@onready var death_screen: Control = $DeathScreen
@onready var fade_text: Label = $FadeText
@onready var boss_name: Label = $BossBar/Name
@onready var boss_health: ProgressBar = $BossBar/Health
@onready var shop_overlay: Control = $ShopOverlay
@onready var shop_title: Label = $ShopOverlay/ShopPanel/Margin/VBox/Title
@onready var shop_coins: Label = $ShopOverlay/ShopPanel/Margin/VBox/Coins
@onready var shop_message: Label = $ShopOverlay/ShopPanel/Margin/VBox/Message
@onready var shop_options: VBoxContainer = $ShopOverlay/ShopPanel/Margin/VBox/Options
@onready var inventory_overlay: Control = $InventoryOverlay
@onready var inv_stats: Label = $InventoryOverlay/Panel/Margin/VBox/Stats
@onready var inv_gear: VBoxContainer = $InventoryOverlay/Panel/Margin/VBox/Columns/Gear/Scroll/List
@onready var inv_bag: VBoxContainer = $InventoryOverlay/Panel/Margin/VBox/Columns/Bag/List
@onready var inv_treasures: VBoxContainer = $InventoryOverlay/Panel/Margin/VBox/Columns/Bag/Treasures
@onready var inv_message: Label = $InventoryOverlay/Panel/Margin/VBox/Message

var _health := 5
var _max_health := 5
var _lines: Array = []
var _line_index := 0
var _on_done: Callable
var _typing: Tween
var _banner_tween: Tween
var _shop: Node
## Name, slot and description of each gear scene (so we only look them up once).
var _gear_info := {}

## Little colored dots next to things in your bag.
const ITEM_COLORS := {
	"jelly": Color(0.45, 0.85, 0.4),
	"wood": Color(0.6, 0.4, 0.22),
	"tooth": Color(0.95, 0.93, 0.85),
	"coins": Color(1, 0.8, 0.2),
	"treasure": Color(0.75, 0.45, 1),
}
## Nice names for equipment slots.
## (They're listed in this order in the inventory.)
const SLOT_NAMES := {
	"weapon": "Weapon", "head": "Head", "chest": "Body",
	"back": "Back", "shield": "Shield", "feet": "Feet",
}


func _ready() -> void:
	# Keep the HUD working while the game is paused (the inventory pauses it).
	process_mode = Node.PROCESS_MODE_ALWAYS
	hearts.draw.connect(_draw_hearts)
	banner.visible = false
	dialogue_box.visible = false
	prompt_label.visible = false
	collect_label.visible = false
	fader.visible = true
	fader.color.a = 1.0

	Game.stage_changed.connect(_on_stage_changed)
	Game.item_count_changed.connect(_on_item_count_changed)
	Game.item_received.connect(func(item_name: String) -> void: show_banner("You got the %s!" % item_name))
	Game.message.connect(show_banner)
	Game.dialogue_requested.connect(_on_dialogue_requested)
	Game.coins_changed.connect(_on_coins_changed)
	Game.shop_requested.connect(_on_shop_requested)
	shop_overlay.visible = false
	inventory_overlay.visible = false
	_on_coins_changed(Game.coins)
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
	_update_collect_label()


func _on_item_count_changed(_kind: String, _count: int) -> void:
	_update_collect_label()


## Shows "Slime Jelly: 2 / 5" (or Wood) for whatever the quest needs.
func _update_collect_label() -> void:
	var kind: String = Game.quest_item()
	collect_label.visible = kind != ""
	if kind != "":
		var goal: int = Game.goal(kind)
		collect_label.text = "%s: %d / %d" % [Game.ITEM_NAMES[kind], mini(Game.count(kind), goal), goal]


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


## Fade the screen to black. Use with `await`.
func fade_out(seconds: float) -> void:
	fader.visible = true
	var tween := create_tween()
	tween.tween_property(fader, "color:a", 1.0, seconds)
	await tween.finished


func fade_in(seconds: float) -> void:
	fader.visible = true
	var tween := create_tween()
	tween.tween_property(fader, "color:a", 0.0, seconds)
	tween.tween_callback(func() -> void: fader.visible = false)
	await tween.finished


# ---------------------------------------------------------------- Dialogue

func _on_dialogue_requested(speaker: String, lines: Array, on_done: Callable) -> void:
	Game.controls_locked = true
	# A "|" inside a line splits it into two speech bubbles.
	_lines = []
	for line in lines:
		for part in str(line).split("|"):
			_lines.append(part.strip_edges())
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
	if inventory_overlay.visible:
		if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close_inventory()
		return
	if event.is_action_pressed("inventory") and _can_open_inventory():
		get_viewport().set_input_as_handled()
		_open_inventory()
		return
	if shop_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close_shop()
		return
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


# ---------------------------------------------------------------- Shop

func _on_coins_changed(coins: int) -> void:
	coins_label.text = "Coins: %d" % coins
	shop_coins.text = "You have %d coins" % coins


func _on_shop_requested(shopkeeper: Node) -> void:
	_shop = shopkeeper
	Game.controls_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var title := str(shopkeeper.get("shop_name"))
	shop_title.text = title if title != "" else "%s's Shop" % str(shopkeeper.get("npc_name"))
	shop_message.text = "What can I get you?"
	shop_overlay.visible = true
	controls_hint.visible = false
	prompt_label.visible = false
	_build_shop_menu()


func _build_shop_menu() -> void:
	if _shop == null or not shop_overlay.visible:
		return
	for child in shop_options.get_children():
		shop_options.remove_child(child)
		child.queue_free()

	# Selling
	for kind in Game.ITEM_NAMES.keys():
		var amount: int = Game.sellable(kind)
		var earn: int = amount * Game.SELL_PRICES[kind]
		var text := "Sell %d %s  (+%d coins)" % [amount, Game.ITEM_NAMES[kind], earn]
		_add_shop_button(text, _on_sell_pressed.bind(kind), amount <= 0)

	# Buying
	for i in _shop.call("item_count"):
		var info: Dictionary = _shop.call("item_info", i)
		var text := "Buy %s  (%d coins)  -  %s" % [info["name"], info["price"], info["description"]]
		if info["worn"]:
			text = "%s  -  you're wearing it!" % info["name"]
		elif info["owned"]:
			text = "Wear your %s again  (free)" % info["name"]
		_add_shop_button(text, _on_buy_pressed.bind(i), info["worn"])

	_add_shop_button("Leave", _close_shop, false)

	# Put the keyboard / controller cursor on the first button you can press.
	for child in shop_options.get_children():
		var button := child as Button
		if button and not button.disabled:
			button.grab_focus.call_deferred()
			break


func _add_shop_button(text: String, action: Callable, disabled: bool) -> void:
	shop_options.add_child(_make_button(text, action, disabled))


## A cream-colored rounded button (used by the shop and the inventory).
func _make_button(text: String, action: Callable, disabled: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.25, 0.16, 0.12))
	button.add_theme_color_override("font_hover_color", Color(0.25, 0.16, 0.12))
	button.add_theme_color_override("font_focus_color", Color(0.25, 0.16, 0.12))
	button.add_theme_color_override("font_disabled_color", Color(0.25, 0.16, 0.12, 0.4))
	button.add_theme_stylebox_override("normal", _button_style(Color(1, 0.92, 0.78)))
	button.add_theme_stylebox_override("hover", _button_style(Color(1, 0.84, 0.55)))
	button.add_theme_stylebox_override("focus", _button_style(Color(1, 0.84, 0.55), true))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.95, 0.72, 0.4)))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.92, 0.88, 0.82)))
	button.pressed.connect(action)
	return button


func _button_style(color: Color, outlined := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	if outlined:
		style.set_border_width_all(3)
		style.border_color = Color(0.85, 0.42, 0.18)
	return style


func _on_sell_pressed(kind: String) -> void:
	shop_message.text = _shop.call("sell_all", kind)
	_build_shop_menu.call_deferred()


func _on_buy_pressed(index: int) -> void:
	shop_message.text = _shop.call("buy", index)
	_build_shop_menu.call_deferred()


func _close_shop() -> void:
	if not shop_overlay.visible:
		return
	shop_overlay.visible = false
	controls_hint.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _shop:
		_shop.call("close_shop")
	_shop = null
	await get_tree().create_timer(0.2).timeout
	Game.controls_locked = false


# ---------------------------------------------------------------- Inventory

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


## Only open the bag while you're free to play (not talking, shopping,
## in a cutscene, or lying on the ground after fainting).
func _can_open_inventory() -> bool:
	return Game.can_play() and not shop_overlay.visible and not dialogue_box.visible \
		and _player() != null


func _open_inventory() -> void:
	Game.controls_locked = true
	# Freeze the world so slimes and cyclopses wait while you look in your bag.
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	inv_message.text = ""
	inventory_overlay.visible = true
	controls_hint.visible = false
	prompt_label.visible = false
	_build_inventory()


func _close_inventory() -> void:
	if not inventory_overlay.visible:
		return
	inventory_overlay.visible = false
	controls_hint.visible = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Same tiny pause as the shop, so the closing key press doesn't do anything else.
	await get_tree().create_timer(0.2).timeout
	if not shop_overlay.visible and not dialogue_box.visible:
		Game.controls_locked = false


func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


## Name, slot and description of a gear scene, e.g. {"name": "Iron Helmet", ...}.
func _info_for(scene: PackedScene) -> Dictionary:
	var key := scene.resource_path
	if not _gear_info.has(key):
		var item := scene.instantiate() as EquipmentItem
		if item == null:
			return {"name": "???", "slot": "", "description": ""}
		_gear_info[key] = {"name": item.display_name, "slot": item.slot, "description": item.describe()}
		item.free()
	return _gear_info[key]


func _build_inventory() -> void:
	var player := _player()
	if player == null or not inventory_overlay.visible:
		return
	var equipped: Dictionary = player.get("equipped")

	# How strong is the corgi right now?
	var stats := "Hearts %d / %d   ·   Damage %d   ·   Defense %d" % [
		player.get("health"), player.get("max_health"),
		player.call("get_attack_damage"), player.call("get_defense")]
	var speed: float = player.get("_speed_multiplier")
	if speed > 1.0:
		stats += "   ·   Speed +%d%%" % roundi((speed - 1.0) * 100.0)
	inv_stats.text = stats

	# Weapons & gear: click one to hold / wear it.
	_clear(inv_gear)
	var held: Node = equipped.get("weapon")
	var all_gear: Array[PackedScene] = []
	all_gear.append_array(player.get("weapons"))
	all_gear.append_array(player.get("gear"))
	# Weapons first, then head to toe.
	var slot_order := SLOT_NAMES.keys()
	all_gear.sort_custom(func(a: PackedScene, b: PackedScene) -> bool:
		return slot_order.find(_info_for(a)["slot"]) < slot_order.find(_info_for(b)["slot"]))
	for scene in all_gear:
		var info := _info_for(scene)
		var worn_item: Node = equipped.get(info["slot"])
		var wearing: bool = worn_item != null and is_instance_valid(worn_item) \
			and worn_item.scene_file_path == scene.resource_path
		var text := "%s:  %s" % [SLOT_NAMES.get(info["slot"], "Gear"), info["name"]]
		if info["description"] != "":
			text += "  -  %s" % info["description"]
		if wearing:
			text += "   (%s)" % ("holding" if info["slot"] == "weapon" else "wearing")
		var button := _make_button(text, _on_gear_pressed.bind(scene), wearing)
		button.add_theme_font_size_override("font_size", 18)
		if wearing:
			# Things you have on get a green "equipped" look instead of looking greyed out.
			var style := _button_style(Color(0.82, 0.95, 0.75), true)
			style.border_color = Color(0.35, 0.65, 0.3)
			button.add_theme_stylebox_override("disabled", style)
			button.add_theme_color_override("font_disabled_color", Color(0.18, 0.35, 0.15))
		inv_gear.add_child(button)
	if all_gear.is_empty():
		inv_gear.add_child(_bag_row("Nothing yet. Go talk to Mom!", Color(0, 0, 0, 0)))
	elif held == null and not player.get("weapons").is_empty():
		inv_message.text = "Pick a weapon to hold!"

	# Bag: coins and everything you've collected.
	_clear(inv_bag)
	inv_bag.add_child(_bag_row("Coins  x%d" % Game.coins, ITEM_COLORS["coins"]))
	var any_items := false
	for kind in Game.ITEM_NAMES.keys():
		var amount: int = Game.count(kind)
		if amount <= 0:
			continue
		any_items = true
		var text := "%s  x%d" % [Game.ITEM_NAMES[kind], amount]
		if Game.quest_item() == kind:
			text += "   (Mom needs %d)" % Game.goal(kind)
		else:
			text += "   (sells for %d each)" % Game.SELL_PRICES[kind]
		inv_bag.add_child(_bag_row(text, ITEM_COLORS.get(kind, Color.WHITE)))
	if not any_items:
		inv_bag.add_child(_bag_row("Your bag is empty.", Color(0, 0, 0, 0)))

	# Magic treasures the Corgiwizard hid.
	_clear(inv_treasures)
	for treasure in Game.treasures:
		inv_treasures.add_child(_bag_row(treasure, ITEM_COLORS["treasure"]))
	inv_treasures.add_child(_bag_row("???  (more hidden somewhere...)", Color(0.6, 0.55, 0.6)))

	# Put the keyboard / controller cursor on the first button you can press.
	for child in inv_gear.get_children():
		var button := child as Button
		if button and not button.disabled:
			button.grab_focus.call_deferred()
			break


## One line in the bag: a little colored dot and some text.
func _bag_row(text: String, dot_color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(16, 16)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = dot_color
	style.set_corner_radius_all(8)
	if dot_color.a > 0.0:
		style.set_border_width_all(2)
		style.border_color = Color(0.25, 0.16, 0.12)
	dot.add_theme_stylebox_override("panel", style)
	row.add_child(dot)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.25, 0.16, 0.12))
	row.add_child(label)
	return row


func _on_gear_pressed(scene: PackedScene) -> void:
	var player := _player()
	if player == null:
		return
	var info := _info_for(scene)
	if info["slot"] == "weapon":
		player.call("give_weapon", scene)
		inv_message.text = "You're holding the %s." % info["name"]
	else:
		player.call("equip", scene)
		inv_message.text = "You put on the %s. Looking sharp!" % info["name"]
	_build_inventory.call_deferred()


# ---------------------------------------------------------------- Boss health bar

func show_boss_bar(title: String, max_health: int) -> void:
	boss_name.text = title
	boss_health.max_value = max_health
	boss_health.value = max_health
	boss_bar.visible = true
	boss_bar.modulate.a = 0.0
	create_tween().tween_property(boss_bar, "modulate:a", 1.0, 0.5)


func set_boss_health(current: int, _maximum: int) -> void:
	var tween := create_tween()
	tween.tween_property(boss_health, "value", float(current), 0.25)


func hide_boss_bar() -> void:
	var tween := create_tween()
	tween.tween_property(boss_bar, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void: boss_bar.visible = false)


# ---------------------------------------------------------------- Death screen

## Darken the screen and show "You died!". Use with `await`.
func show_death_screen() -> void:
	fader.visible = true
	death_screen.visible = true
	death_screen.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(fader, "color:a", 0.75, 0.8)
	tween.parallel().tween_property(death_screen, "modulate:a", 1.0, 0.8)
	tween.tween_interval(2.5)
	tween.tween_property(fader, "color:a", 1.0, 0.5)
	await tween.finished


## Hide "You died!" and fade back in. Use with `await`.
func hide_death_screen() -> void:
	var tween := create_tween()
	tween.tween_property(death_screen, "modulate:a", 0.0, 0.3)
	await tween.finished
	death_screen.visible = false
	await fade_in(1.0)


## Words shown on top of the black screen (like "Sailing..."). "" hides them.
func set_fade_text(text: String) -> void:
	fade_text.text = text
	fade_text.visible = text != ""
