extends Node

class_name PinkCoinManager

@export var inner_hbox: HBoxContainer

@export var not_obtained_texture: Texture2D
@export var obtained_texture: Texture2D

@export var key_scene: PackedScene

var pink_coins_cnt: int = 0
var obtained_cnt: int = 0

func _ready():
	await get_tree().process_frame
	var pink_coins = get_tree().get_nodes_in_group("pink_coin")
	pink_coins_cnt = pink_coins.size()
	#print("PinkCoinManager: 找到粉币数量: ", pink_coins_cnt)
	get_parent().visible = pink_coins_cnt > 0
	_setup_coin_display()

func _setup_coin_display():
	if not inner_hbox:
		push_error("PinkCoinManager: inner_hbox is not assigned!")
		return

	for child in inner_hbox.get_children():
		child.queue_free()

	for i in range(pink_coins_cnt):
		var tex_rect = TextureRect.new()
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tex_rect.custom_minimum_size = Vector2(10, 24)
		tex_rect.texture = obtained_texture if i < obtained_cnt else not_obtained_texture
		inner_hbox.add_child(tex_rect)
		#print("PinkCoinManager: 生成第 ", i + 1, " 个粉币图标")

func pink_coin_obtained() -> void:
	obtained_cnt += 1
	_setup_coin_display()
	if obtained_cnt == pink_coins_cnt:
		#print("PinkCoinManager: 所有粉币都已获得!")
		_create_key()

func _create_key() -> void:
	var key_instance = key_scene.instantiate() as Node2D
	var key_movement = key_instance.get_node("KeyMovement") as KeyMovement
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player:
		key_instance.global_position = player.global_position
	add_sibling(key_instance)
	key_movement.state = KeyMovement.KeyState.GOT