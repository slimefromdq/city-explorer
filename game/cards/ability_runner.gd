class_name AbilityRunner
extends Node
## Holds the hero's equipped cards and casts them. This is the ONLY code that
## knows how to "do" a card: it reads the card's fields and runs its effect
## blocks. Cards themselves are pure data.
##
## Every physics tick the hero calls tick(), which:
##   1. refills energy and each slot's charges, and counts down timed modifiers
##   2. looks at the intent (which card buttons are pressed / held / released)
##   3. casts the cards whose trigger matches, if the slot has a charge, there
##      is enough energy, and the hero is free to act
## MOVEMENT_EVENT cards are cast from the hero's movement_event signal instead,
## and PASSIVE cards run their ON CAST once when equipped (their modifiers).
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
## The hero's passive (a PASSIVE card). Not in a slot; set by the hero definition.
@export var passive: AbilityCard
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
var charge_held: Array[float] = []  # RELEASE cards: seconds the button has been held (-1 = not charging)
## Active modifiers: {stat, amount, left (-1 = while its card is equipped), source}
var modifiers: Array[Dictionary] = []

var _casts_this_frame := 0
## When true no card can be cast at all (safe rooms like the apartment).
var locked := false
var _event_data := {}              # the movement event being handled right now (for aim direction)
var _complained := {}              # "card path + message" -> true, so each problem is logged once


func setup(h: Hero) -> void:
	hero = h
	energy = max_energy
	add_to_group(&"ability_runners")
	cards.resize(SLOT_COUNT)
	pools.resize(SLOT_COUNT)
	fire_wait.resize(SLOT_COUNT)
	charge_held.resize(SLOT_COUNT)
	charge_held.fill(-1.0)
	h.movement_event.connect(_on_movement_event)
	if loadout != null:
		set_cards(loadout.cards)


func set_cards(list: Array) -> void:
	for i in SLOT_COUNT:
		_put(i, list[i] if i < list.size() else null)
	_apply_passives()


func equip(slot: int, card: AbilityCard) -> void:
	_put(slot, card)
	_apply_passives()


func _put(slot: int, card: AbilityCard) -> void:
	cards[slot] = card
	fire_wait[slot] = 0.0
	charge_held[slot] = -1.0
	pools[slot] = null
	if card == null:
		return
	if card.cooldown > 0.0:
		pools[slot] = ChargePool.new(card.charges, card.cooldown, 0.0)
	for p in card.validate():
		_complain(card, p)
	if card.trigger == AbilityCard.Trigger.PROC_ONLY:
		_complain(card, "is PROC_ONLY, so it does nothing in a slot; another card has to cast it")


## Passive modifiers last exactly as long as their card is equipped, so they
## are rebuilt from scratch whenever the loadout changes.
func _apply_passives() -> void:
	modifiers = modifiers.filter(func(m: Dictionary) -> bool: return m.left >= 0.0)
	var all := cards.duplicate()
	if passive != null:
		all.append(passive)
	for card in all:
		if card != null and card.trigger == AbilityCard.Trigger.PASSIVE:
			var ctx := CastContext.new()
			ctx.card = card
			ctx.runner = self
			ctx.caster = hero
			ctx.position = hero.global_position
			run_list(card.on_cast, ctx, &"on_cast")


## Set the passive (null = none) and rebuild modifiers.
func set_passive(card: AbilityCard) -> void:
	passive = card
	if card != null:
		for p in card.validate():
			_complain(card, p)
		if card.trigger != AbilityCard.Trigger.PASSIVE:
			_complain(card, "is used as a hero passive but its trigger isn't PASSIVE")
	_apply_passives()


## Re-reads every equipped card (after a hot reload changed their fields).
func refresh() -> void:
	_complained.clear()
	set_cards(cards.duplicate())


func tick(dt: float) -> void:
	_casts_this_frame = 0
	energy = minf(max_energy, energy + energy_regen * stat_mult(ModifierEffect.Stat.ENERGY_REGEN) * dt)
	var recharge := stat_mult(ModifierEffect.Stat.COOLDOWN_SPEED)
	for i in SLOT_COUNT:
		if pools[i] != null:
			(pools[i] as ChargePool).tick(dt, recharge)
		fire_wait[i] = maxf(0.0, fire_wait[i] - dt)
	for m in modifiers:
		if m.left >= 0.0:
			m.left = maxf(0.0, m.left - dt)
	modifiers = modifiers.filter(func(m: Dictionary) -> bool: return m.left != 0.0)
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
						fire_wait[i] = card.fire_interval / stat_mult(ModifierEffect.Stat.FIRE_RATE)
			AbilityCard.Trigger.RELEASE:
				# Charge while held (only if a cast would be allowed), fire on release.
				if intent.card_held[i]:
					if charge_held[i] < 0.0 and intent.card_pressed[i] and _can_pay(i):
						charge_held[i] = 0.0
					if charge_held[i] >= 0.0:
						charge_held[i] += dt
				elif charge_held[i] >= 0.0:
					var k := clampf(charge_held[i] / card.charge_time, 0.0, 1.0)
					charge_held[i] = -1.0
					try_cast(i, lerpf(card.min_charge_power, 1.0, k))


func can_act() -> bool:
	return not locked and not hero.defense.dead and not blocked_states.has(hero.states.current_name)


## The player (or a bot) wants slot `slot`. Pays the costs and casts.
## `power` is the RELEASE charge multiplier; `from_event` skips the "free to
## act" check (the movement event itself proves the hero is acting).
func try_cast(slot: int, power := 1.0, from_event := false) -> bool:
	var card := cards[slot]
	if card == null or (not from_event and not can_act()) or hero.defense.dead or locked:
		return false
	if not _can_pay(slot):
		return false
	var pool := pools[slot] as ChargePool
	if pool != null:
		pool.spend()
	energy -= card.energy_cost
	var ctx := _player_context(card)
	ctx.power = power
	cast(card, ctx, slot)
	return true


func _can_pay(slot: int) -> bool:
	var card := cards[slot]
	var pool := pools[slot] as ChargePool
	return card != null and (pool == null or pool.has_charge()) and energy >= card.energy_cost


## How far a RELEASE card in `slot` is charged (0..1), or -1 when not charging.
func charge_of(slot: int) -> float:
	var card := cards[slot]
	if card == null or charge_held[slot] < 0.0:
		return -1.0
	return clampf(charge_held[slot] / card.charge_time, 0.0, 1.0)


func _on_movement_event(type: int, data: Dictionary) -> void:
	for i in SLOT_COUNT:
		var card := cards[i]
		if card == null or card.trigger != AbilityCard.Trigger.MOVEMENT_EVENT or card.movement_event != type:
			continue
		_event_data = data
		try_cast(i, 1.0, true)
		_event_data = {}


# ------------------------------------------------------------------ modifiers

func add_modifier(stat: int, amount: float, duration: float, source: AbilityCard, when: int = 0) -> void:
	if duration >= 0.0:
		# A timed buff from the same card refreshes instead of stacking forever.
		for m in modifiers:
			if m.source == source and m.stat == stat and m.left >= 0.0:
				m.left = maxf(m.left, duration)
				return
	modifiers.append({"stat": stat, "amount": amount, "left": duration, "source": source, "when": when})


## Product of (1 + amount) over every modifier for `stat` (1.0 = unchanged).
func stat_mult(stat: int) -> float:
	var k := 1.0
	for m in modifiers:
		if m.stat == stat and ModifierEffect.condition_met(m.when, hero):
			k *= maxf(0.05, 1.0 + m.amount)
	return k


## Sum of amounts for additive stats (EXTRA_BOUNCES).
func stat_add(stat: int) -> float:
	var total := 0.0
	for m in modifiers:
		if m.stat == stat and ModifierEffect.condition_met(m.when, hero):
			total += m.amount
	return total


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
		if _casts_this_frame == max_casts_per_frame:   # warn once per frame, not once per refused cast
			push_warning("Proc chain stopped: more than %d casts this frame (first refused: %s)" % [max_casts_per_frame, card.label()])
			_casts_this_frame += 1
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
		AbilityCard.Origin.AHEAD:
			var flat := Vector3(i.aim_dir.x, 0.0, i.aim_dir.z)
			flat = flat.normalized() if flat.length() > 0.01 else Basis(Vector3.UP, i.aim_yaw) * Vector3.FORWARD
			ctx.position = hero.global_position + Vector3.UP * 1.1 + flat * card.ahead_distance
			ctx.direction = flat
	# Cards fired by a movement event go the way that movement went (a leap,
	# a roll) when the event says so.
	if _event_data.has("direction"):
		var d: Vector3 = _event_data["direction"]
		if d.length() > 0.1:
			ctx.direction = d.normalized()
	return ctx


## Add a line to the recent-casts log (effects use this for transforms).
func note(line: String) -> void:
	_log("%7.2fs  %s" % [Time.get_ticks_msec() / 1000.0, line])


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
