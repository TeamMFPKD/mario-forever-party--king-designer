extends Node

enum TileSetNames {
	CASTLE,
	CASTLE_B,
	CAVE,
	DUSK,
	NIGHT,
	OVERWORLD,
	SAND,
	SNOW,
	SNOW_B,
	VOLCANO,
}

@export var level_data_node : LevelManager

func _physics_process(delta: float) -> void:
	if (Input.is_key_pressed(KEY_1)):
		level_data_node.level_theme = LevelManager.LevelThemeEnum.CASTLE
	elif (Input.is_key_pressed(KEY_2)):
		level_data_node.level_theme = LevelManager.LevelThemeEnum.CASTLE_B
	elif (Input.is_key_pressed(KEY_3)):
		level_data_node.level_theme = LevelManager.LevelThemeEnum.CAVE
	elif (Input.is_key_pressed(KEY_4)):
		level_data_node.level_theme = LevelManager.LevelThemeEnum.DUSK
	elif (Input.is_key_pressed(KEY_5)):
		level_data_node.level_theme = LevelManager.LevelThemeEnum.NIGHT
	elif (Input.is_key_pressed(KEY_6)):
		level_data_node.level_theme = LevelManager.LevelThemeEnum.OVERWORLD
	elif (Input.is_key_pressed(KEY_7)):
		level_data_node.level_theme = LevelManager.LevelThemeEnum.SAND
	elif (Input.is_key_pressed(KEY_8)):
		level_data_node.level_theme = LevelManager.LevelThemeEnum.SNOW
	elif (Input.is_key_pressed(KEY_9)):
		level_data_node.level_theme = LevelManager.LevelThemeEnum.SNOW_B
	elif (Input.is_key_pressed(KEY_0)):
		level_data_node.level_theme = LevelManager.LevelThemeEnum.VOLCANO
		

func _button_1_pressed():
	print("Button 1 Pressed")

func _button_2_pressed():
	print("Button 2 Pressed")
	