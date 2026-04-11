extends Node2D

@export var animation_player : AnimationPlayer
@onready var life_1 = $Life1
@onready var life_2 = $Life2
@onready var life_3 = $Life3

var level_manager : LevelManager
var is_cooldown : bool = false
var lives : int = 2:
	set(value):
		if not is_cooldown:
			lives = value
			return
		if lives < value:
			animation_player.play("life_up")
		elif lives > value:
			animation_player.play("life_down")
		lives = value

func _ready() -> void:
	var fc = func():
		level_manager = get_tree().get_first_node_in_group("level_manager")
		lives = level_manager.lives
		_update_life_display()
	fc.call_deferred()

func _update_life_display() -> void:
	life_1.visible = (lives == 1)
	life_2.visible = (lives == 2)
	life_3.visible = (lives == 3)

func _on_life_up() -> void:
	level_manager.lives += 1
	lives = level_manager.lives
	_update_life_display()

func _on_life_down() -> void:
	level_manager.lives -= 1
	lives = level_manager.lives
	_update_life_display()

func _on_ani_cooldown_finished() -> void:
	is_cooldown = true
