class_name Gunslinger
extends RefCounted
## Archetype factory. A "kit" is just: a palette, a GunComponent and five
## Ability nodes (M1 + four moves). New archetypes copy this shape.

static func create(display_name: String, palette: Dictionary = {}) -> Fighter:
	var f := Fighter.new()
	f.display_name = display_name
	f.name = display_name
	f.model.set_palette(palette)
	var gun := GunComponent.new()
	gun.fighter = f
	f.gun = gun
	f.add_child(gun)
	f.model.holds_gun = true
	for a in [GunM1.new(), BurstShot.new(), SlideShot.new(), RicochetRound.new(), Snapshot.new()]:
		var ab := a as Ability
		ab.fighter = f
		f.add_child(ab)
		f.kit.append(ab)
	return f
