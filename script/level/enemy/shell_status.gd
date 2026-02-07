extends Node

class_name ShellStatus

@export var path_to_shell : NodePath = ".."
@export var path_to_shell_movement : NodePath = "../BasicMovement"
@export var path_to_interaction_with_player : NodePath = "../EnemyInteraction/InteractionWithPlayer"
@export var path_to_animated_sprite : NodePath = "../AnimatedSprite2D"
@export var is_moving : bool = false:
	set(value):
		if value:
			interaction_with_player_node.stomp_offset = -4.0
			interaction_with_player_node.interactable = false
			interaction_with_player_node.return_stomp_speed_y = true
			ani.play("default")
			if shell_movement.speed_x == 0.0:
				shell_movement.speed_x = 0.0 - shell_move_speed_x
			set_interaction_delay()
		else:
			interaction_with_player_node.stomp_offset = 64.0
			interaction_with_player_node.interactable = false
			interaction_with_player_node.return_stomp_speed_y = false
			shell_movement.speed_x = 0.0
			ani.frame = 0
			ani.stop()
			set_interaction_delay()
		is_moving = value
@export var shell_move_speed_x : float = 200.0
@export var interaction_delay_time : float = 0.3

var shell : CharacterBody2D
var shell_movement : BasicMovement
var interaction_with_player_node : InteractionWithPlayer
var ani : AnimatedSprite2D

func _ready() -> void:
	shell = get_node(path_to_shell)
	shell_movement = get_node(path_to_shell_movement)
	interaction_with_player_node = get_node(path_to_interaction_with_player)
	ani = get_node(path_to_animated_sprite)
	set_interaction_delay()

func _on_stomped(hit_position : Vector2) -> void:
	if is_moving:
		shell_movement.speed_x = 0.0
	else:
		shell_movement.speed_x = shell_move_speed_x if shell.position.x > hit_position.x else -shell_move_speed_x
	is_moving = not is_moving

func set_interaction_delay() -> void:
	await get_tree().create_timer(interaction_delay_time, false, true).timeout
	if is_moving:
		interaction_with_player_node.hurt_type = InteractionWithPlayer.HurtType.HURT
	else:
		interaction_with_player_node.hurt_type = InteractionWithPlayer.HurtType.NOTHING
	interaction_with_player_node.interactable = true
