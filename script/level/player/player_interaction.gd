extends Node

signal player_hurt
signal player_die

@export var player_movement : PlayerMovement
@export var player_suit : PlayerSuit
@export var player : CharacterBody2D
@export var cast : ShapeCast2D

var starman : bool

func _physics_process(delta: float) -> void:
	var results = ShapeCastQuery.shape_query(player, cast)
	
	# 踩踏
	hurt_and_stompable_detect(results)

	# 获得道具
	bonus_detect(results)

	# 无敌星撞击敌人
	starman_detect(results)

	# 顶砖检测
	block_hit_detect(results)
	
func hurt_and_stompable_detect(results : Array[Node2D]) -> void:
	for result in results:
		if not result.has_meta("interaction_with_player"):
			continue
		var interaction_with_player_node = result.get_meta("interaction_with_player") as InteractionWithPlayer
		if not interaction_with_player_node.interactable:
			continue
		# 在上方踩踏并且可以踩踏
		interaction_with_player_node.on_overlap(player)
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

func bonus_detect(results : Array[Node2D]) -> void:
	for result in results:
		if not result.has_meta("bonus_set"):
			continue
		var bonus_set_node = result.get_meta("bonus_set") as BonusSet
		bonus_set_node.on_bonus_get(player)
		if player_suit.suit == PlayerSuit.SuitType.SMALL and bonus_set_node.bonus_type == BonusSet.BonusType.MUSHROOM:
			player_suit.suit = PlayerSuit.SuitType.SUPER
		if bonus_set_node.bonus_type == BonusSet.BonusType.FIRE_FLOWER:
			player_suit.suit = PlayerSuit.SuitType.POWERED
			player_suit.power = PlayerSuit.PowerupType.FIREBALL
		if bonus_set_node.bonus_type == BonusSet.BonusType.BEETROOT:
			player_suit.suit = PlayerSuit.SuitType.POWERED
			player_suit.power = PlayerSuit.PowerupType.BEETROOT
		if bonus_set_node.bonus_type == BonusSet.BonusType.LUI:
			player_suit.suit = PlayerSuit.SuitType.POWERED
			player_suit.power = PlayerSuit.PowerupType.LUI
		if bonus_set_node.bonus_type == BonusSet.BonusType.STAR:
			player_suit.starman_start()

func starman_detect(results : Array[Node2D]) -> void:
	starman = is_starman()
	if not starman:
		return
	for result in results:
		if not result.has_meta("interaction_with_star"):
			continue
		var interaction_with_star_node = result.get_meta("interaction_with_star") as InteractionWithStar
		if not interaction_with_star_node.is_hittable:
			continue
		interaction_with_star_node.on_star_hit(player.position)
		
func is_starman() -> bool:
	return player_suit.is_starman

func block_hit_detect(results : Array[Node2D]) -> void:
	pass
	# TODO: