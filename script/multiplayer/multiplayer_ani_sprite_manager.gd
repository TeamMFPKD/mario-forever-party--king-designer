extends Node2D

@export var mp_ani_shadow_scene : PackedScene

var multiplayer_manager : MultiplayerManager
var anis : Array
var local_ani : AnimatedSprite2D

var player_suit : PlayerSuit
var player_hurt_and_die : PlayerHurtAndDie

var no_player_print_limit : int

func _ready() -> void:
	if GameModeSingleton.game_mode != GameModeSingleton.GameModeType.PLAY:
		return
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	multiplayer_manager.mp_ani_manager = self
	var multiplayer_count = multiplayer_manager.players.size() - 1
	for i in range(multiplayer_count):
		var ani = mp_ani_shadow_scene.instantiate() as AnimatedSprite2D
		ani.position = Vector2(-999999, -999999)
		anis.append(ani)
		add_child(ani)

func _physics_process(_delta: float) -> void:
	if GameModeSingleton.game_mode != GameModeSingleton.GameModeType.PLAY:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		if no_player_print_limit < 10:
			no_player_print_limit += 1
			print("No player node found")
			return
	if not local_ani:
		local_ani = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
		print("No AnimatedSprite2D node found")
		return
	if not player_suit:
		player_suit = player.get_meta("player_suit") as PlayerSuit
		print("No player suit found")
		return
	if not player_hurt_and_die:
		player_hurt_and_die = player.get_meta("player_hurt_and_die") as PlayerHurtAndDie
		print("No player hurt and die found")
		return
	multiplayer_manager.send_ani_sprite_data.rpc(
		multiplayer_manager.player.id, multiplayer_manager.player.name,multiplayer_manager.current_level_count, 
		local_ani.global_position, player_suit.suit, player_suit.power, local_ani.animation, local_ani.frame, local_ani.flip_h,
		player_hurt_and_die.is_dead
		)
	#print("Player ", multiplayer_manager.player.name, " send ani sprite data 终了")
