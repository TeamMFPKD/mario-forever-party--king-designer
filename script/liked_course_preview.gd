extends Control

@export var path_to_texture_rect : NodePath = "/CaptureTextureRect"

var texture_rect : TextureRect
var level_path_node : Node
var level_file_path : String

const LIKED_COURSE_FOLDER_NAME = "liked courses"

func _ready() -> void:
	# 获取 TextureRect 节点
	if path_to_texture_rect:
		texture_rect = get_node(path_to_texture_rect)

	# 获取关卡文件路径
	level_path_node = get_tree().get_first_node_in_group("level_path_set")
	if not level_path_node:
		print("Level path node not found")
		return
	level_file_path = level_path_node.get_meta("level_path_name", "invalid") as String
	if level_file_path == "invalid" or level_file_path.is_empty():
		print("Invalid level file path")
		return
	
	# 读取并显示截图
	load_screenshots()

func load_screenshots() -> void:
	# 检查文件夹是否存在
	var dir = DirAccess.open("user://")
	if not dir or not dir.dir_exists("liked courses"):
		print("Liked courses folder not found")
		return
	
	# 打开 liked courses 文件夹
	var target_folder = "user://" + LIKED_COURSE_FOLDER_NAME + "/"
	var liked_dir = DirAccess.open(target_folder)
	if not liked_dir:
		print("Cannot open liked courses folder")
		return
	
	# 构建目标路径
	var base_name = level_file_path.get_file().get_basename()
	var level_photo_path = target_folder + base_name + ".png"
	var screenshot_found = false
	# 检查图片文件是否存在
	if FileAccess.file_exists(level_photo_path):
		load_and_display_screenshot(level_photo_path)
		screenshot_found = true
	else:
		print("Screenshot not found: ", level_photo_path)
	
	if not screenshot_found:
		print("No screenshots found in liked courses folder")
		return

func load_and_display_screenshot(file_path: String) -> void:
	if not texture_rect:
		print("TextureRect not assigned")
		return
	
	# 加载图片
	var image = Image.new()
	var error = image.load(file_path)
	
	if error != OK:
		print("Failed to load screenshot: ", file_path)
		return
	
	# 可选：调整图片大小（如果不想依赖 TextureRect 的拉伸）
	# 但这步通常不需要，因为 TextureRect 的 stretch_mode 会处理
	# image.resize(TARGET_SIZE.x, TARGET_SIZE.y, Image.INTERPOLATE_LANCZOS)
	
	# 创建纹理并设置到 TextureRect
	var texture = ImageTexture.create_from_image(image)
	texture.set_size_override(texture_rect.size)
	texture_rect.texture = texture
	print("Screenshot loaded: ", file_path)
