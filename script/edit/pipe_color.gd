extends Node

@export var sprite: Sprite2D
static var level_manager: LevelManager

func _ready() -> void:
	level_manager = get_tree().get_first_node_in_group("level_manager") as LevelManager
	level_manager.level_theme_changed.connect(update_pipe_color)
	update_pipe_color(level_manager.level_theme)

func update_pipe_color(level_theme: LevelManager.LevelThemeEnum) -> void:
	match level_theme:
		LevelManager.LevelThemeEnum.CASTLE:
			sprite.frame = 5
		LevelManager.LevelThemeEnum.CASTLE_B:
			sprite.frame = 6
		LevelManager.LevelThemeEnum.CAVE:
			sprite.frame = 1
		LevelManager.LevelThemeEnum.DUSK:
			sprite.frame = 2
		LevelManager.LevelThemeEnum.NIGHT:
			sprite.frame = 1
		LevelManager.LevelThemeEnum.OVERWORLD:
			sprite.frame = 0
		LevelManager.LevelThemeEnum.SAND:
			sprite.frame = 3
		LevelManager.LevelThemeEnum.SNOW:
			sprite.frame = 4
		LevelManager.LevelThemeEnum.SNOW_B:
			sprite.frame = 4
		LevelManager.LevelThemeEnum.VOLCANO:
			sprite.frame = 5
