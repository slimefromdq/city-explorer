class_name MoveEvent
extends RefCounted
## The movement events every hero can emit. This list is the shared vocabulary
## between the movement code and card data: in M2 a card will pick one of these
## from a dropdown as its trigger ("fire when OnDashLaunch happens").
##
## Add new entries at the END only. Saved cards store the number, so inserting
## in the middle would silently change what existing cards listen to.

enum Type {
	DASH_START,      # M1b: the sigil leap was committed (startup begins)
	SIGIL_FORMED,    # M1b: the sigil finished drawing, launch is next
	DASH_LAUNCH,     # M1b: the hero leaves the sigil
	ROLL,            # M1c
	BLOCK_START,     # M1c
	PERFECT_BLOCK,   # M1c
	LAND,            # touched the ground after being airborne (data: impact_speed)
	JUMP,            # left the ground with a jump
	MANTLE,          # grabbed a ledge and started pulling up (data: height)
	WALL_KICK,       # kicked off a wall in the air (data: kicks_used)
}

const NAMES := [
	"OnDashStart", "OnSigilFormed", "OnDashLaunch", "OnRoll", "OnBlockStart",
	"OnPerfectBlock", "OnLand", "OnJump", "OnMantle", "OnWallKick",
]


static func name_of(type: int) -> String:
	return NAMES[type] if type >= 0 and type < NAMES.size() else "OnUnknown(%d)" % type
