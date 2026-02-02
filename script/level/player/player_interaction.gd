extends Node

signal player_hurt
signal player_die

@export var player_movement : PlayerMovement
@export var player : CharacterBody2D
@export var cast : ShapeCast2D

func _physics_process(delta: float) -> void:
	var results = ShapeCastQuery.shape_query(player, cast)
	
	# 踩踏
	hurt_and_stompable_detect(results)
	

func hurt_and_stompable_detect(results : Array[Node2D]) -> void:
	for result in results:
		if result.has_meta("interaction_with_player"):
			var interaction_with_player_node = result.get_meta("interaction_with_player") as InteractionWithPlayer
			# 在上方踩踏并且可以踩踏
			if player.position.y < result.position.y + interaction_with_player_node.stomp_offset \
			and interaction_with_player_node.stompable:
				# 踩踏成功
				player_movement.speed_y = interaction_with_player_node.on_stomped(player)
			else:
				# 踩踏失败
				match interaction_with_player_node.hurt_type:
					InteractionWithPlayer.HurtType.HURT:
						emit_signal("player_hurt")
					InteractionWithPlayer.HurtType.DIE:
						emit_signal("player_die")
					InteractionWithPlayer.HurtType.NOTHING:
						pass
