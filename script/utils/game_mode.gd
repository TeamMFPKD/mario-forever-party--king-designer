extends Node

class_name GameMode

enum GameModeType {
	EDIT,
	TEST,
	PLAY,
}

@export var game_mode : GameModeType = GameModeType.EDIT
@export var edit_scene_uid : String

func go_to_edit() -> void:
	await get_tree().create_timer(0.5, true, true).timeout
	game_mode = GameModeType.EDIT
	get_tree().paused = false
	var fc = func():
		get_tree().change_scene_to_file(edit_scene_uid)
	fc.call_deferred()
