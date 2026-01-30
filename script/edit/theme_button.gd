extends Button

@export var target_theme : LevelManager.LevelThemeEnum

var level_manager : LevelManager

func _ready() -> void:
	level_manager = get_tree().get_first_node_in_group("level_manager") as LevelManager
	pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	if level_manager:
		level_manager.level_theme = target_theme
