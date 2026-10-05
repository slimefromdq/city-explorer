extends Node
## Moves the player between places (the apartment, the test arena now, the
## city in M4). `go(scene, spawn)` changes the scene and remembers which named
## spawn point to arrive at; the new scene asks `take_arrival()` in its _ready
## and puts the hero at that Marker3D. Nothing is carried in memory except the
## spawn name: who you are and what you carry comes from GameState.

const APARTMENT := "res://game/levels/apartment/apartment.tscn"
const ARENA := "res://game/levels/test_arena/test_arena.tscn"

## The spawn point the next scene should use ("" = its default spawn).
var arrival := ""
## Tests set this to (scene_path) -> void to load scenes themselves instead
## of replacing the whole running scene.
var changer: Callable


func go(scene_path: String, spawn_name := "") -> void:
	if not ResourceLoader.exists(scene_path):
		push_error("SceneRouter: no scene at %s" % scene_path)
		return
	arrival = spawn_name
	SaveService.save_game()
	if changer.is_valid():
		changer.call(scene_path)
	else:
		get_tree().change_scene_to_file.call_deferred(scene_path)


## Called by a scene in _ready: the spawn name to use, once (then it's cleared).
func take_arrival() -> String:
	var a := arrival
	arrival = ""
	return a
