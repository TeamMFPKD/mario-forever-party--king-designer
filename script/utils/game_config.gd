extends Node

var config: ConfigFile

func _ready() -> void:
	config = ConfigFile.new()
	config.load("user://game_settings.cfg")

func save() -> void:
	config.save("user://game_settings.cfg")
