extends Node
## Sets up all of CorgiKnight's controls when the game starts.
##
## Keyboard + mouse and game controllers (Xbox / PlayStation / Switch Pro) both work.
## You can also manage controls by hand in Project > Project Settings > Input Map.


func _enter_tree() -> void:
	# Keyboard
	_add_keys("move_forward", [KEY_W, KEY_UP])
	_add_keys("move_back", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("jump", [KEY_SPACE])
	_add_keys("attack", [KEY_J, KEY_ENTER])
	_add_keys("sprint", [KEY_SHIFT])
	_add_keys("interact", [KEY_E])

	# Mouse
	_add_mouse_button("attack", MOUSE_BUTTON_LEFT)

	# Controller: left stick moves, right stick looks around
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add_joy_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_button("jump", JOY_BUTTON_A)
	_add_joy_button("attack", JOY_BUTTON_X)
	_add_joy_button("sprint", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button("interact", JOY_BUTTON_Y)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _add_keys(action: String, keys: Array) -> void:
	_ensure_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _add_mouse_button(action: String, button: MouseButton) -> void:
	_ensure_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func _add_joy_axis(action: String, axis: JoyAxis, direction: float) -> void:
	_ensure_action(action)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)


func _add_joy_button(action: String, button: JoyButton) -> void:
	_ensure_action(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
