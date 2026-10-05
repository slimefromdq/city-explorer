class_name HeroIntent
extends RefCounted
## What the hero WANTS to do this physics frame. Nothing else.
##
## Whoever controls the hero (the keyboard today, a bot or a network client
## later) only ever writes into this note. The hero's state machine reads it and
## decides what is actually allowed. That split is what keeps input separate
## from game state.

var move := Vector2.ZERO          # x = right, y = forward, relative to aim_yaw
var aim_yaw := 0.0                # camera heading in radians (0 = looking down -Z)
var aim_dir := Vector3.FORWARD    # full 3D aim direction (camera forward)
var aim_point := Vector3.ZERO     # world point under the crosshair

# Held buttons: true for as long as the button is down.
var sprint := false
var crouch := false
var jump_held := false
var block := false
## Card slot buttons: 0 Primary, 1-3 Abilities. Held = button is down.
var card_held: Array[bool] = [false, false, false, false]

# Presses: true only on the frame the button went down. The hero clears them
# after every physics tick, so a press is seen exactly once.
var jump_pressed := false
var dash_pressed := false
var roll_pressed := false
var interact_pressed := false     # use the mirror / workbench / door you're facing
var card_pressed: Array[bool] = [false, false, false, false]


func clear_presses() -> void:
	jump_pressed = false
	dash_pressed = false
	roll_pressed = false
	interact_pressed = false
	for i in card_pressed.size():
		card_pressed[i] = false
