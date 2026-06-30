extends Button

enum LifeLimitEnum {
	DOWN,
	UP,
}
@export var life_limit = LifeLimitEnum.DOWN

@export var limit_down: int = 1
@export var limit_up: int = 3

var level_manager: LevelManager

func _ready() -> void:
	level_manager = get_tree().get_first_node_in_group("level_manager")
	level_manager.lives_changed.connect(_on_lives_changed)

func _on_lives_changed() -> void:
	var lives = level_manager.lives
	match life_limit:
		LifeLimitEnum.DOWN:
			if lives == limit_down:
				disabled = true
			else:
				disabled = false
		LifeLimitEnum.UP:
			if lives == limit_up:
				disabled = true
			else:
				disabled = false