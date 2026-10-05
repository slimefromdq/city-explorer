extends Node
## Input actions are registered in code so every binding lives in one readable
## place (and can later be driven by a settings screen).

func _ready() -> void:
	_keys(&"move_forward", [KEY_W])
	_keys(&"move_back", [KEY_S])
	_keys(&"move_left", [KEY_A])
	_keys(&"move_right", [KEY_D])
	_keys(&"jump", [KEY_SPACE])
	_keys(&"sprint", [KEY_SHIFT])
	_keys(&"crouch", [KEY_CTRL, KEY_C])
	_keys(&"controller_debug", [KEY_F3])
	_keys(&"dash", [KEY_E])
	_keys(&"dodge", [KEY_Q])
	_keys(&"block", [KEY_F])
	_mouse(&"block", MOUSE_BUTTON_RIGHT)
	_mouse(&"m1", MOUSE_BUTTON_LEFT)
	_keys(&"ability_1", [KEY_1])
	_keys(&"ability_2", [KEY_2])
	_keys(&"ability_3", [KEY_3])
	_keys(&"ability_4", [KEY_4])
	_keys(&"reload", [KEY_R])
	_keys(&"map", [KEY_M])
	# --- Meridia Hero Sandbox (res://game) ---
	_keys(&"crouch", [KEY_C, KEY_CTRL])
	_keys(&"roll", [KEY_Q, KEY_ALT])
	_keys(&"dbg_overlay", [KEY_F3])
	_mouse(&"card_primary", MOUSE_BUTTON_LEFT)
	_keys(&"card_1", [KEY_R, KEY_1])
	_keys(&"card_2", [KEY_G, KEY_2])
	_keys(&"card_3", [KEY_V, KEY_3])
	_keys(&"card_reload", [KEY_F4])
	_keys(&"loadout_next", [KEY_TAB])
	# The hero blocks on right mouse only; F is interact (Lucy's pick, M3).
	# (The old prototype keeps its own "block" action on F + right mouse.)
	_mouse(&"hero_block", MOUSE_BUTTON_RIGHT)
	_keys(&"interact", [KEY_F])
	_keys(&"ui_wipe_save", [KEY_F10])
	# --- test-bench tools ---
	_keys(&"dbg_help", [KEY_F1])
	_keys(&"dbg_teleport", [KEY_F2])
	_keys(&"dbg_reset", [KEY_F5])
	_keys(&"dbg_respawn_bots", [KEY_F6])
	_keys(&"dbg_bot_mode", [KEY_F7])
	_keys(&"dbg_streak", [KEY_F8])
	_keys(&"dbg_rain", [KEY_F9])


func _keys(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func _mouse(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)
