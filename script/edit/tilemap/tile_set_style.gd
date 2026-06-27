extends Node

@export var theme_to_tile_preview : Dictionary[LevelManager.LevelThemeEnum, Texture2D]

var tile_set_preview : Sprite2D
var level_manager : LevelManager

func _ready() -> void:
	tile_set_preview = get_parent() as Sprite2D
	level_manager = get_tree().get_first_node_in_group("level_manager") as LevelManager
	level_manager.level_theme_changed.connect(_on_theme_changed)

func _on_theme_changed(theme : LevelManager.LevelThemeEnum) -> void:
	tile_set_preview.texture.atlas = theme_to_tile_preview[theme]
	
