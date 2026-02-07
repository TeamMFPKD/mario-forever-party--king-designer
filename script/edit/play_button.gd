extends Button

@export var room_scene_uid : String
@export var target_mode : GameModeSingleton.GameModeType = GameModeSingleton.GameModeType.TEST

var game_mode : GameMode

func _ready() -> void:
	game_mode = GameModeSingleton
	pressed.connect(_on_button_pressed)

func _on_button_pressed():
	var fc = func():
		game_mode.game_mode = target_mode
		get_tree().change_scene_to_file(room_scene_uid)
	fc.call_deferred()
