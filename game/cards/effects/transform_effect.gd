class_name TransformEffect
extends CardEffect
## Effect block 8: turn the thrown body into another card's body, mid-flight.
## From then on it uses the new card's body (shape, properties) AND that card's
## ON CONTACT / ON HIT / ON EXPIRE lists, like a card handing over to another.
## Put it in ON EXPIRE to transform instead of dying ("after the last bounce
## it becomes a sticky bomb"), or in ON CONTACT to transform on the first touch.
## Counts as one proc-chain link (depth + 1).

@export var into: AbilityCard


func apply(ctx: CastContext) -> void:
	if into == null or into.body == null:
		push_error("Card %s: 'Transform' needs a card with a Body to turn into" % ctx.card.label())
		return
	var b := ctx.body as CardBody
	if b == null or not is_instance_valid(b):
		push_error("Card %s: 'Transform' only works on a thrown body (ON CONTACT / ON EXPIRE of a card with a Body)" % ctx.card.label())
		return
	if ctx.runner != null and ctx.depth + 1 > ctx.runner.max_proc_depth:
		push_warning("Transform stopped: %s would be depth %d (max_proc_depth %d)" % [into.label(), ctx.depth + 1, ctx.runner.max_proc_depth])
		return
	b.transform_into(into)


func validate(_card: AbilityCard) -> PackedStringArray:
	var p := PackedStringArray()
	if into == null:
		p.append("no card to transform into")
	elif into.body == null:
		p.append("%s has no Body to become" % into.display_name)
	if _card.body == null:
		p.append("this card has no body to transform")
	return p
