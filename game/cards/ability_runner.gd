class_name AbilityRunner
extends Node
## Holds the hero's equipped cards and casts them. This is the ONLY code that
## knows how to "do" a card: it reads the card's fields and runs its effect
## blocks. Cards themselves are pure data.
##
## Every physics tick the hero calls tick(), which:
##   1. refills energy and each slot's charges
##   2. looks at the intent (which card buttons are pressed / held)
##   3. casts the cards whose trigger matches, if the slot has a charge, there
##      is enough energy, and the hero is free to act
##
## Proc chains: a cast carries a depth. Effects that cast another card add 1.
## Past `max_proc_depth` the chain stops with a warning, and no more than
## `max_casts_per_frame` casts happen per tick, so a runaway chain can't hang
## the game.

signal card_cast(card: AbilityCard, slot: int, depth: int)

const SLOT_COUNT := 4
const SLOT_NAMES := ["Primary", "Ability 1", "Ability 2", "Ability 3"]
const SLOT_KEYS := ["LMB", "R", "G", "V"]
const MAX_LOG := 6

@export var loadout: CardLoadout
@export var max_energy := 100.0
## Energy per second.
@export var energy_regen := 20.0
@export_range(0, 16) var max_proc_depth := 4
@export_range(1, 512) var max_casts_per_frame := 64
## While the hero is in one of these states, cards can't be cast (you committed
## to the leap windup, you're stunned, mantling, or holding up your guard).
@export var blocked_states: Array[StringName] = [&"Hitstun", &"DashStartup", &"Mantle", &"Block"]

var hero: Hero
var cards: Array[AbilityCard] = []
var pools: Array = []              # ChargePool per slot, or null when the card has no cooldown
var fire_wait: Array[float] = []   # HOLD cards: time until the next automatic shot
var energy := 0.0
var log_lines: Array[String] = []  # recent casts, newest first (debug overlay)

var _casts_this_frame := 0
var _complained := {}              # "card path + message" -> true, so each problem is logged once


func setup(h: Hero) -> void:
	hero = h
	energy = max_energy
	add_to_group(&"ability_runners")
	cards.resize(SLOT_COUNT)
	pools.resize(SLOT_COUNT)
	fire_wait.resize(SLOT_COUNT)
	if loadout != null:
		set_cards(loadout.cards)


func set_cards(list: Array) -> void:
	for i in SLOT_COUNT:
		equip(i, list[i] if i < list.size() else null)


func equip(slot: int, card: AbilityCard) -> void:
	cards[slot] = card
	fire_wait[slot] = 0.0
	pools[slot] = null
	if card == null:
		return
	if card.cooldown > 0.0:
		pools[slot] = ChargePool.new(card.charges, card.cooldown, 0.0)
	for p in card.validate():
		_complain(card, p)


## Re-reads every equipped card (after a hot reload changed their fields).
func refresh() -> void:
	_complained.clear()
	set_cards(cards.duplicate())


func tick(dt: float) -> void:
	_casts_this_frame = 0
	energy = minf(max_energy, energy + energy_regen * dt)
	for i in SLOT_COUNT:
		if pools[i] != null:
			(pools[i] as ChargePool).tick(dt)
		fire_wait[i] = maxf(0.0, fire_wait[i] - dt)
	var intent := hero.intent
	for i in SLOT_COUNT:
		var card := cards[i]
		if card == null:
			continue
		match card.trigger:
			AbilityCard.Trigger.PRESS:
				if intent.card_pressed[i]:
					try_cast(i)
			AbilityCard.Trigger.HOLD:
				if intent.card_held[i] and fire_wait[i] <= 0.0:
					if try_cast(i):
						fire_wait[i] = card.fire_interval
			_:
				if intent.card_pressed[i]:
					_complain(card, "trigger %s is not implemented until M2b" % AbilityCard.Trigger.keys()[card.trigger])


func can_act() -> bool:
	return not hero.defense.dead and not blocked_states.has(hero.states.current_name)


## The player (or a bot) wants slot `slot`. Pays the costs and casts.
func try_cast(slot: int) -> bool:
	var card := cards[slot]
	if card == null or not can_act():
		return false
	var pool := pools[slot] as ChargePool
	if pool != null and not pool.has_charge():
		return false
	if energy < card.energy_cost:
		return false
	if pool != null:
		pool.spend()
	energy -= card.energy_cost
	cast(card, _player_context(card), slot)
	return true


## Cast `card` with a prepared context. Player casts come through try_cast;
## proc chains (M2b) call this directly with a deeper context.
func cast(card: AbilityCard, ctx: CastContext, slot := -1) -> void:
	if card == null:
		push_error("AbilityRunner: tried to cast an empty card")
		return
	if ctx.depth > max_proc_depth:
		push_warning("Proc chain stopped: %s would be depth %d (max_proc_depth %d)" % [card.label(), ctx.depth, max_proc_depth])
		return
	if _casts_this_frame >= max_casts_per_frame:
		push_warning("Proc chain stopped: more than %d casts this frame (last: %s)" % [max_casts_per_frame, card.label()])
		return
	_casts_this_frame += 1
	ctx.card = card
	ctx.runner = self
	ctx.caster = hero
	_log("%7.2fs  %s%s%s" % [Time.get_ticks_msec() / 1000.0, "  ".repeat(ctx.depth), card.display_name,
			"  (%s)" % SLOT_NAMES[slot] if slot >= 0 else "  depth %d" % ctx.depth])
	card_cast.emit(card, slot, ctx.depth)
	run_list(card.on_cast, ctx, &"on_cast")


## Runs one of a card's effect lists, in order. Empty entries are reported once.
func run_list(list: Array[CardEffect], ctx: CastContext, list_name: StringName) -> void:
	for i in list.size():
		var e := list[i]
		if e == null:
			_complain(ctx.card, "%s[%d] is empty: pick an effect block or remove the entry" % [list_name, i])
			continue
		e.apply(ctx)


## Effects report each damaged target here; it runs ON HIT and ON KILL.
func report_hit(ctx: CastContext, target: Node3D, result: int, _amount: float) -> void:
	if ctx.is_reaction:
		return   # damage dealt BY on_hit/on_kill doesn't re-trigger them
	if result != HitData.Result.HIT and result != HitData.Result.BLOCKED and result != HitData.Result.GUARD_BREAK:
		return
	var c := ctx.copy()
	c.target = target
	c.position = CardEffect.center_of(target)
	c.is_reaction = true
	run_list(ctx.card.on_hit, c, &"on_hit")
	if target.has_method(&"is_dead") and target.is_dead():
		run_list(ctx.card.on_kill, c, &"on_kill")


## Charges ready in a slot (for the HUD): returns [ready, max, refill progress 0..1].
func slot_charges(slot: int) -> Array:
	var card := cards[slot]
	if card == null:
		return [0, 0, 0.0]
	var pool := pools[slot] as ChargePool
	if pool == null:
		return [1, 1, 1.0]
	return [pool.available(), pool.max_charges, pool.charges - floorf(pool.charges)]


func _player_context(card: AbilityCard) -> CastContext:
	var ctx := CastContext.new()
	var i := hero.intent
	match card.origin:
		AbilityCard.Origin.HAND:
			ctx.position = hero.hand_position()
			var to_aim := i.aim_point - ctx.position
			# Aim from the hand at whatever is under the crosshair, so shots land
			# where you point even though the camera is over your shoulder.
			ctx.direction = to_aim.normalized() if to_aim.length() > 1.5 else i.aim_dir
		AbilityCard.Origin.FEET:
			ctx.position = hero.global_position + Vector3.UP * 0.1
			ctx.direction = i.aim_dir
		AbilityCard.Origin.AIM_POINT:
			ctx.position = i.aim_point
			ctx.direction = i.aim_dir
	return ctx


func _log(line: String) -> void:
	log_lines.push_front(line)
	if log_lines.size() > MAX_LOG:
		log_lines.resize(MAX_LOG)


func _complain(card: AbilityCard, msg: String) -> void:
	var key := "%s|%s" % [card.resource_path, msg]
	if _complained.has(key):
		return
	_complained[key] = true
	push_error("Card %s: %s" % [card.label(), msg])
