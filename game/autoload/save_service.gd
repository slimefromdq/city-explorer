extends Node
## Writes GameState to a JSON file whenever it changes, and reads it back when
## the game starts. JSON (not a Godot resource file) because resource files can
## carry scripts, and save data should be safe to share.
## F10 twice (within 2 seconds) wipes the save and starts fresh.

const SAVE_PATH := "user://meridia_save.json"

## Tests point this somewhere else so they never touch the real save.
var path := SAVE_PATH
var _pending := false
var _wipe_armed_until := 0.0


func _ready() -> void:
	load_game()
	GameState.changed.connect(_queue_save)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_wipe_save"):
		var now := Time.get_ticks_msec() / 1000.0
		if now < _wipe_armed_until:
			_wipe_armed_until = 0.0
			wipe()
		else:
			_wipe_armed_until = now + 2.0
			Events.feed.emit("Press F10 again to wipe your save")


## Save at the end of this frame, once, however many things changed.
func _queue_save() -> void:
	if _pending:
		return
	_pending = true
	_save_deferred.call_deferred()


func _save_deferred() -> void:
	_pending = false
	save_game()


func save_game() -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveService: can't write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(GameState.to_dict(), "  "))
	f.close()
	return true


## Returns true if a save was found and loaded.
func load_game() -> bool:
	if not FileAccess.file_exists(path):
		GameState.reset_to_defaults()
		return false
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("SaveService: %s is not a valid save; starting fresh (the bad file is kept as .broken)" % path)
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".broken"))
		GameState.reset_to_defaults()
		return false
	GameState.from_dict(data as Dictionary)
	return true


func wipe() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GameState.reset_to_defaults()
	Events.feed.emit("Save wiped: fresh start")
	GameState.changed.emit()
