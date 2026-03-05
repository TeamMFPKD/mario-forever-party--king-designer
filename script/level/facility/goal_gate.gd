extends Area2D

signal goal_reached
signal next_level

@export var bar : Sprite2D
@export var smoke_scene : PackedScene

var smoke : Node2D

var is_passed : bool = false

var play_next_level_node : Node

var jump_to_scene_history_edit_node : Node

func _ready() -> void:
	if GameModeSingleton.game_mode == GameModeSingleton.GameModeType.TEST:
		goal_reached.connect(GameModeSingleton.go_to_edit)
	
	jump_to_scene_history_edit_node = get_tree().get_first_node_in_group("jump_to_scene_history_edit")
	if jump_to_scene_history_edit_node:
		print("[%s] 返回历史记录查看模式" % Time.get_time_string_from_system())
		var fc = func() -> void:
			var game_mode = GameModeSingleton
			game_mode.game_mode = game_mode.GameModeType.HISTORY_EDIT
		next_level.connect(fc)
		next_level.connect(jump_to_scene_history_edit_node.jump_to_scene)
	
	play_next_level_node = get_tree().get_first_node_in_group("play_next_level_manager")
	if play_next_level_node:
		next_level.connect(play_next_level_node.next_level_pass)
	else:
		push_warning("play_next_level_manager is not assigned in GoalGate")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and !is_passed and not body.has_meta("level_passed"):
		# 防止同时触发两个终点导致卡死
		body.set_meta("level_passed", true)

		is_passed = true

		smoke = smoke_scene.instantiate() as Node2D
		smoke.position.x = position.x - 4
		smoke.position.y = position.y + bar.position.y
		add_sibling(smoke)

		bar.queue_free()

		get_tree().paused = true

		print("[%s] goal reached" % Time.get_time_string_from_system())
		emit_signal("goal_reached")

		if is_instance_valid(self) and is_inside_tree():
			await get_tree().create_timer(1.0).timeout
		
		get_tree().paused = false
		emit_signal("next_level")