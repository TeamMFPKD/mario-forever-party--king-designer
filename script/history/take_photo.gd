extends Node

signal photo_taken

@export var take_photo_ani_spd: float = 0.2

var viewport: Viewport
var level_path_node: Node
var image: Image


func _ready() -> void:
	viewport = get_viewport()


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("photo"):
		capture()


func capture() -> void:
	# 获取关卡文件路径
	level_path_node = get_tree().get_first_node_in_group("level_path_set")
	if not level_path_node:
		push_error("[take_photo.gd] Level path node not found")
		return

	var path: String = level_path_node.get_meta("level_path_name", "invalid")
	if path == "invalid" or path.is_empty():
		push_error("[take_photo.gd] Invalid level path")
		return

	# 检查源文件是否存在
	if not FileAccess.file_exists(path):
		push_error("[take_photo.gd] Source level file does not exist: ", path)
		return

	if not LikedCourses.ensure_folder():
		return

	var file_name: String = path.get_file()
	var target_png: String = LikedCourses.photo_path(file_name)

	# 截图处理
	var viewport_texture: ViewportTexture = viewport.get_texture()
	image = viewport_texture.get_image()
	var tmp_texture: ImageTexture = ImageTexture.create_from_image(image)
	var sav_texture: ImageTexture = tmp_texture.duplicate()

	# 调整大小并保存图片
	var sav_image: Image = sav_texture.get_image()
	sav_image.resize(640, 480, Image.INTERPOLATE_NEAREST)
	var image_error: Error = sav_image.save_png(target_png)

	if image_error == OK:
		print("[take_photo.gd] Photo saved to: ", target_png)
	else:
		push_error("[take_photo.gd] Failed to save photo. Error code: ", image_error)

	# 只登记收藏索引，关卡本体继续留在 user:// 根目录，不再复制
	LikedCourses.add(file_name)

	_create_capture_preview()

	emit_signal("photo_taken")


func _create_capture_preview() -> void:
	var sprite: Sprite2D = Sprite2D.new()
	var game_room_node: Control = get_tree().get_first_node_in_group("game_room")
	if not game_room_node:
		push_error("Game room node not found")
		return
	game_room_node.add_child(sprite)
	sprite.texture = ImageTexture.create_from_image(image)
	var texture_rect: Control = get_tree().get_first_node_in_group("capture_texture_rect")
	if not texture_rect:
		push_error("Texture rect node not found")
		return

	# 计算起始和结束位置
	var start_pos: Vector2 = game_room_node.get_global_position() + game_room_node.get_size() / 2.0
	var end_pos: Vector2 = texture_rect.get_global_position() + texture_rect.get_size() / 2.0

	# 计算起始和结束缩放
	# 起始缩放：根据 game_room_node 的大小调整
	var game_room_size: Vector2 = game_room_node.get_size()
	var texture_size: Vector2i = image.get_size()

	# 让 sprite 在起始位置时适配 game_room_node 的大小
	var start_scale: Vector2 = Vector2(
		game_room_size.x / texture_size.x,
		game_room_size.y / texture_size.y
	)

	# 让 sprite 在结束位置时适配 texture_rect 的大小
	var end_scale: Vector2 = Vector2(
		texture_rect.get_size().x / texture_size.x,
		texture_rect.get_size().y / texture_size.y
	)

	# 设置初始状态
	sprite.global_position = start_pos
	sprite.scale = start_scale
	sprite.rotation = 0

	# 创建并配置 Tween
	var tween: Tween = create_tween()
	var ani_time: float = take_photo_ani_spd
	tween.set_parallel(true)  # 让所有属性同时变化

	# 位置插值（线性）
	tween.tween_property(sprite, "global_position", end_pos, ani_time)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_LINEAR)

	# 缩放插值（线性）
	tween.tween_property(sprite, "scale", end_scale, ani_time)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_LINEAR)

	# 旋转插值（从0到360度）
	tween.tween_property(sprite, "rotation", deg_to_rad(-360.0), ani_time)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_LINEAR)

	# 动画结束后处理
	tween.finished.connect(func() -> void:
		pass
		#print("[take_photo.gd] 动画完成")
		# 可以选择不移除，让 sprite 留在 texture_rect 上
		# 或者延迟移除：
		# await get_tree().create_timer(0.5).timeout
		# sprite.queue_free()
	)
