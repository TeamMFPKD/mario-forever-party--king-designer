extends Node

class_name GameMode

enum GameModeType {
	EDIT,
	PLAY,
}

@export var game_mode : GameModeType = GameModeType.EDIT
