extends Node

var viewport
var level_path_node : Node
var image : Image

const LIKED_COURSE_FOLDER_NAME = "liked courses"

func _ready() -> void:
	viewport = get_viewport()

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("photo"):
		capture()

func capture() -> void:
	# 创建目录
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(LIKED_COURSE_FOLDER_NAME):
		var error = dir.make_dir(LIKED_COURSE_FOLDER_NAME)
		if error != OK:
			print("Failed to create directory: ", error)
			return
	
	# 获取关卡文件路径
	level_path_node = get_tree().get_first_node_in_group("level_path_set")
	if not level_path_node:
		print("Level path node not found")
		return
		
	var path = level_path_node.get_meta("level_path_name", "invalid") as String
	if path == "invalid" or path.is_empty():
		print("Invalid level path")
		return
	
	# 检查源文件是否存在
	if not FileAccess.file_exists(path):
		print("Source level file does not exist: ", path)
		return
	
	# 构建目标路径
	var base_name = path.get_file().get_basename()
	var target_folder = "user://" + LIKED_COURSE_FOLDER_NAME + "/"
	var target_png = target_folder + base_name + ".png"
	var target_lvl = target_folder + path.get_file()
	
	# 截图处理
	var viewport_texture = viewport.get_texture()
	image = viewport_texture.get_image()
	var tmp_texture = ImageTexture.create_from_image(image)
	var sav_texture = tmp_texture.duplicate()
	
	# 调整大小并保存图片
	var sav_image = sav_texture.get_image()
	sav_image.resize(640, 480, Image.INTERPOLATE_NEAREST)
	var image_error = sav_image.save_png(target_png)
	
	if image_error == OK:
		print("Photo saved to: ", target_png)
	else:
		print("Failed to save photo. Error code: ", image_error)
	
	# 复制关卡文件
	var copy_error = dir.copy(path, target_lvl)
	if copy_error == OK:
		print("Level file copied to: ", target_lvl)
		
		# 可选：验证复制是否成功
		if FileAccess.file_exists(target_lvl):
			print("Level file verified at destination")
	else:
		print("Failed to copy level file. Error code: ", copy_error)
		
		# 备用复制方法：使用 FileAccess 读写
		var source_file = FileAccess.open(path, FileAccess.READ)
		var dest_file = FileAccess.open(target_lvl, FileAccess.WRITE)
		if source_file and dest_file:
			var data = source_file.get_buffer(source_file.get_length())
			dest_file.store_buffer(data)
			print("Level file copied using FileAccess fallback")
		else:
			print("Fallback copy also failed")

	_create_capture_preview()

func _create_capture_preview() -> void:
	var sprite = Sprite2D.new()
	var game_room_node = get_tree().get_first_node_in_group("game_room") as Control
	if not game_room_node:
		push_error("Game room node not found")
		return
	game_room_node.add_child(sprite)
	sprite.texture = ImageTexture.create_from_image(image)
	var texture_rect = get_tree().get_first_node_in_group("capture_texture_rect") as Control
	if not texture_rect:
		push_error("Texture rect node not found")
		return
	
	# 计算起始和结束位置
	var start_pos = game_room_node.get_global_position() + game_room_node.get_size() / 2.0
	var end_pos = texture_rect.get_global_position() + texture_rect.get_size() / 2.0
	
	# 计算起始和结束缩放
	# 起始缩放：根据 game_room_node 的大小调整
	var game_room_size = game_room_node.get_size()
	var texture_size = image.get_size()
	
	# 让 sprite 在起始位置时适配 game_room_node 的大小
	var start_scale = Vector2(
		game_room_size.x / texture_size.x,
		game_room_size.y / texture_size.y
	)
	
	# 让 sprite 在结束位置时适配 texture_rect 的大小
	var end_scale = Vector2(
		texture_rect.get_size().x / texture_size.x,
		texture_rect.get_size().y / texture_size.y
	)
	
	# 设置初始状态
	sprite.global_position = start_pos
	sprite.scale = start_scale
	sprite.rotation = 0
	
	# 创建并配置 Tween
	var tween = create_tween()
	var ani_time = 0.5
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
	tween.tween_property(sprite, "rotation", deg_to_rad(360.0), ani_time)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_LINEAR)
	
	# 动画结束后处理
	tween.finished.connect(func():
		print("动画完成")
		# 可以选择不移除，让 sprite 留在 texture_rect 上
		# 或者延迟移除：
		# await get_tree().create_timer(0.5).timeout
		# sprite.queue_free()
	)
