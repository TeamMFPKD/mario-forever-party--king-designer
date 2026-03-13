extends Node

var viewport
var level_path_node : Node

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
	var image = viewport_texture.get_image()
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
