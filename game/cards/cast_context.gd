class_name CastContext
extends RefCounted
## Everything an effect block needs to know about "right now": who cast what,
## where it is happening, which way, and what (if anything) was touched.
## Each moment of a card's life (cast, contact, hit, expire) gets its own copy.

var caster: Node3D               # the hero who owns the card
var runner: AbilityRunner        # the caster's runner (runs effect lists, tracks chains)
var card: AbilityCard
## How many "Cast card" links deep this cast is. 0 = cast by the player.
var depth := 0
var position := Vector3.ZERO     # where this moment happens
var direction := Vector3.FORWARD # which way the cast/body is going
var normal := Vector3.UP         # surface normal at a contact
var target: Node3D               # what was touched or hit (null = the world / nothing)
var body: Node3D                 # the CardBody (null for beams and body-less cards)
## True while running ON HIT / ON KILL, so damage dealt by those lists doesn't
## trigger ON HIT again forever.
var is_reaction := false


func copy() -> CastContext:
	var c := CastContext.new()
	c.caster = caster
	c.runner = runner
	c.card = card
	c.depth = depth
	c.position = position
	c.direction = direction
	c.normal = normal
	c.target = target
	c.body = body
	c.is_reaction = is_reaction
	return c


## Heavy bodies push harder; every push goes through this.
func push_mult() -> float:
	if card != null and card.body != null and card.body.heavy:
		return card.body.heavy_mult
	return 1.0
