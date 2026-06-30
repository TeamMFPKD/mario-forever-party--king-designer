extends Node

class_name GameMode

signal mode_set_to_edit
signal mode_set_to_test
signal mode_set_to_play

enum GameModeType {
	EDIT,
	TEST,
	PLAY,
	HISTORY_EDIT,
	HISTORY_PLAY,
}

@export var game_mode: GameModeType = GameModeType.EDIT:
	set(value):
		match value:
			GameModeType.EDIT:
				emit_signal("mode_set_to_edit")
			GameModeType.TEST:
				emit_signal("mode_set_to_test")
			GameModeType.PLAY:
				emit_signal("mode_set_to_play")
		game_mode = value
@export var edit_scene_uid: String

func go_to_edit() -> void:
	await get_tree().create_timer(0.5, true, true).timeout
	game_mode = GameModeType.EDIT
	get_tree().paused = false
	var fc = func():
		get_tree().change_scene_to_file(edit_scene_uid)
	fc.call_deferred()
