extends PlayerDependent

class_name PinkCoinManager

signal play_paper_fold_ani

@export var inner_hbox: HBoxContainer

@export var not_obtained_texture: Texture2D
@export var obtained_texture: Texture2D

@export var key_scene: PackedScene
@export var pink_coin_get_sound: PinkCoinGetSound

var pink_coins_cnt: int = 0
var obtained_cnt: int = 0

func _ready() -> void:
	await get_tree().process_frame
	var pink_coins: Array[Node] = get_tree().get_nodes_in_group("pink_coin")
	pink_coins_cnt = pink_coins.size()
	#print("PinkCoinManager: 找到粉币数量: ", pink_coins_cnt)
	var parent_layer: CanvasLayer = get_parent() as CanvasLayer
	parent_layer.visible = pink_coins_cnt > 0
	_setup_coin_display()

func _setup_coin_display() -> void:
	if not inner_hbox:
		push_error("PinkCoinManager: inner_hbox is not assigned!")
		return

	for child: Node in inner_hbox.get_children():
		child.queue_free()

	for i: int in range(pink_coins_cnt):
		var tex_rect: TextureRect = TextureRect.new()
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tex_rect.custom_minimum_size = Vector2(10, 24)
		tex_rect.texture = obtained_texture if i < obtained_cnt else not_obtained_texture
		inner_hbox.add_child(tex_rect)
		#print("PinkCoinManager: 生成第 ", i + 1, " 个粉币图标")

func pink_coin_obtained() -> void:
	obtained_cnt += 1
	if pink_coin_get_sound:
		pink_coin_get_sound.play_get(obtained_cnt - 1, pink_coins_cnt)
	_setup_coin_display()
	if obtained_cnt == pink_coins_cnt:
		_create_key()
		await get_tree().create_timer(0.5, false, true).timeout
		play_paper_fold_ani.emit()

func _create_key() -> void:
	var key_instance: Node2D = key_scene.instantiate() as Node2D
	var key_movement: KeyMovement = key_instance.get_node("KeyMovement") as KeyMovement
	# 钥匙是世界里的物件，不能挂在 HUD 的 CanvasLayer 下（本组件就挂在里面）：
	# 挂进去会 1) 按屏幕坐标绘制，镜头滚动后位置全错；2) 被粉币 HUD 的翻页缩小/隐藏动画一起带走，
	# 表现为钥匙生成后留在原地、随后消失。所以改挂到 CanvasLayer 的父节点（关卡的世界节点）。
	var hud_layer: Node = get_parent()
	var world_parent: Node = hud_layer.get_parent() if hud_layer != null else null
	if world_parent == null:
		world_parent = hud_layer
	if world_parent != null:
		world_parent.add_child(key_instance)
	else:
		add_child(key_instance)
	var player: Node2D = get_player_body()
	if player:
		key_instance.global_position = player.global_position
	key_movement.state = KeyMovement.KeyState.GOT