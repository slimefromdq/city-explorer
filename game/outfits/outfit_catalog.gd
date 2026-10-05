class_name OutfitCatalog
extends RefCounted
## Finds outfit parts and tints. Parts are the .tres files in PARTS_DIR, so
## adding a new hat is: duplicate a file, edit its pieces, done.

const PARTS_DIR := "res://game/outfits/parts/"
const SLOT_KEYS := ["head", "top", "bottom"]

## The colour tints offered at the wardrobe. "" = the hero's own accent colour.
const TINTS := ["", "e8e4da", "2b2d33", "d9483b", "f2a33a", "f4dd5a", "5fbf6a", "3fa7d6", "7a5cd6", "e57fb8"]


static func parts_for(slot: OutfitPart.Slot) -> Array[OutfitPart]:
	var out: Array[OutfitPart] = []
	var files := ResourceLoader.list_directory(PARTS_DIR)
	var names := PackedStringArray()
	for f in files:
		if f.ends_with(".tres"):
			names.append(f)
	names.sort()
	for f in names:
		var p := load(PARTS_DIR + f) as OutfitPart
		if p != null and p.slot == slot:
			out.append(p)
	return out


static func part_by_id(id: String) -> OutfitPart:
	if id == "":
		return null
	var path := PARTS_DIR + id + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("Outfit: part '%s' not found (%s); showing nothing in that slot" % [id, path])
		return null
	return load(path) as OutfitPart


static func id_of(part: OutfitPart) -> String:
	return part.resource_path.get_file().get_basename() if part != null else ""


## The tint colour for a saved outfit, or `fallback` when none is picked.
static func tint_of(outfit: Dictionary, fallback: Color) -> Color:
	var t := str(outfit.get("tint", ""))
	return Color.html(t) if t != "" and Color.html_is_valid(t) else fallback
