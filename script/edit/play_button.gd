extends Button

@export var play_room_scene_uid : String

var game_mode : GameMode

func _ready() -> void:
	game_mode = GameModeSingleton

func _on_button_pressed():
	var fc = func():
		game_mode.game_mode = GameModeSingleton.GameModeType.PLAY
		get_tree().change_scene_to_file(play_room_scene_uid)
	fc.call_deferred()
