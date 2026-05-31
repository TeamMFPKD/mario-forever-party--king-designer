extends Node

@export var inner_hbox: HBoxContainer

@export var not_obtained_texture: Texture2D
@export var obtained_texture: Texture2D

func _ready():
	await get_tree().process_frame
	_setup_coin_display()

func _setup_coin_display():
	var pink_coins = get_tree().get_nodes_in_group("pink_coin")
	var coin_count = pink_coins.size()
	#print("PinkCoinManager: 找到粉币数量: ", coin_count)
	get_parent().visible = coin_count > 0

	if not inner_hbox:
		push_error("PinkCoinManager: inner_hbox is not assigned!")
		return

	for child in inner_hbox.get_children():
		child.queue_free()

	for i in range(coin_count):
		var tex_rect = TextureRect.new()
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tex_rect.custom_minimum_size = Vector2(16, 24)
		tex_rect.texture = not_obtained_texture
		inner_hbox.add_child(tex_rect)
		#print("PinkCoinManager: 生成第 ", i + 1, " 个粉币图标")
