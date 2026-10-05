class_name OutfitPart
extends Resource
## A cosmetic outfit part for one slot (head, top or bottom), made only of
## primitive pieces. No gameplay effect. Saved by file name, so the save file
## only ever contains ids. Parts live in game/outfits/parts/*.tres.

enum Slot {HEAD, TOP, BOTTOM}

@export var slot := Slot.HEAD
@export var display_name := "Part"
@export var pieces: Array[OutfitPiece] = []
## Hide the hero's default visor (helmets cover it).
@export var hides_visor := false
