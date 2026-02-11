extends Area2D

signal goal_reached
signal next_level

@export var bar : Sprite2D
@export var smoke_scene : PackedScene

var smoke : Node2D

var is_passed : bool = false

var play_next_level_node : Node

func _ready() -> void:
	if GameModeSingleton.game_mode == GameModeSingleton.GameModeType.TEST:
		goal_reached.connect(GameModeSingleton.go_to_edit)
	
	play_next_level_node = get_tree().get_first_node_in_group("play_next_level_manager")
	next_level.connect(play_next_level_node.next_level_pass)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and !is_passed:
		is_passed = true

		smoke = smoke_scene.instantiate() as Node2D
		smoke.position.x = position.x - 4
		smoke.position.y = position.y + bar.position.y
		add_sibling(smoke)

		bar.queue_free()

		get_tree().paused = true

		print("goal reached")
		emit_signal("goal_reached")

		await get_tree().create_timer(1.0).timeout
		
		get_tree().paused = false
		emit_signal("next_level")
