class_name AbilityCard
extends Resource
## One ability, described entirely as data. No card has its own code: the
## hero's AbilityRunner reads these fields and runs the effect blocks listed
## below. To make a new card, duplicate a .tres in game/cards/library/, change
## the fields in the Inspector, and press F4 in-game to reload.
##
## A card's life:
##   trigger fires -> ON CAST effects run (usually "Spawn body" throws the body)
##   the body flies and reports moments -> ON CONTACT / ON HIT / ON KILL / ON EXPIRE
##   each moment runs its own list of effect blocks, in order.

enum Trigger {
	PRESS,           ## fires once when its button goes down
	HOLD,            ## fires every `fire_interval` while held (automatic weapons)
	RELEASE,         ## (M2b) hold to charge, fires on release
	MOVEMENT_EVENT,  ## (M2b) fires by itself when the hero emits `movement_event`
	PROC_ONLY,       ## (M2b) never fires on its own; other cards cast it
}

## Where the cast starts.
enum Origin {
	HAND,       ## from the hero's hand, aimed at whatever is under the crosshair
	FEET,       ## at the hero's feet, aimed along the camera
	AIM_POINT,  ## right where the crosshair is pointing
}

@export var display_name := "New Card"
@export_multiline var description := ""
## Tints the body, its trail and its explosions so you can tell whose effect did what.
@export var color := Color(0.4, 0.8, 1.0)

@export_group("Trigger")
@export var trigger: Trigger = Trigger.PRESS
## HOLD only: seconds between shots while the button is held.
@export var fire_interval := 0.2
## MOVEMENT_EVENT only: which movement event fires this card.
@export var movement_event: MoveEvent.Type = MoveEvent.Type.DASH_LAUNCH

@export_group("Cost")
## Seconds to get one charge back. 0 = no cooldown.
@export var cooldown := 1.0
## How many casts you can stack up before waiting on the cooldown.
@export_range(1, 10) var charges := 1
## Energy spent per cast (the hero's energy pool refills over time).
@export var energy_cost := 0.0

@export_group("Aim")
@export var origin: Origin = Origin.HAND

@export_group("Body")
## What "Spawn body" throws. Leave empty for cards that just do something
## where you stand (teleport, a shockwave...).
@export var body: CardBodyDef

@export_group("Effects")
## Run the moment the card is cast.
@export var on_cast: Array[CardEffect] = []
## Run each time the body touches something (world or target).
@export var on_contact: Array[CardEffect] = []
## Run for each target this card damages.
@export var on_hit: Array[CardEffect] = []
## Run for each target this card kills.
@export var on_kill: Array[CardEffect] = []
## Run when the body's life ends (out of bounces, fuse done, lifetime over).
@export var on_expire: Array[CardEffect] = []


## A readable name for logs: the display name plus the file it came from.
func label() -> String:
	return "'%s' (%s)" % [display_name, resource_path if resource_path != "" else "unsaved"]


## Checks the card for mistakes and returns one message per problem, so a
## broken card says exactly what is wrong instead of silently doing nothing.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var lists := {"on_cast": on_cast, "on_contact": on_contact, "on_hit": on_hit, "on_kill": on_kill, "on_expire": on_expire}
	var has_spawn := false
	for list_name in lists:
		var list: Array = lists[list_name]
		for i in list.size():
			var e: CardEffect = list[i]
			if e == null:
				problems.append("%s[%d] is empty: pick an effect block or remove the entry" % [list_name, i])
				continue
			if e is SpawnBodyEffect:
				has_spawn = true
			for p in e.validate(self):
				problems.append("%s[%d] %s: %s" % [list_name, i, e.block_name(), p])
	if body != null and not has_spawn:
		problems.append("has a body but no 'Spawn body' effect, so the body is never thrown")
	if (not on_contact.is_empty() or not on_expire.is_empty()) and body == null:
		problems.append("has on_contact/on_expire effects but no body, so they can never run")
	if trigger == Trigger.HOLD and fire_interval <= 0.0:
		problems.append("HOLD trigger needs fire_interval > 0")
	return problems
