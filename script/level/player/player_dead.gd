extends CharacterBody2D

signal player_dead

func _ready() -> void:
	if GameModeSingleton.game_mode == GameModeSingleton.GameModeType.TEST:
		player_dead.connect(GameModeSingleton.go_to_edit)
		print("player dead and should go to edit")
	
	emit_signal("player_dead")
