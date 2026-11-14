extends Node

const LIKED_COURSE_FOLDER_NAME: String = "liked courses"

## 工作线程只写这个上下文，绝不在线程里回调节点方法。
## 否则房间关闭、卡片被释放后，线程里的 call_deferred 会报
## “Cannot call method 'call_deferred' on a previously freed instance.”
class PhotoLoadContext:
	extends RefCounted
	var mutex: Mutex = Mutex.new()
	var image: Image = null
	var done: bool = false

var _context: PhotoLoadContext = null

func set_photo(lvl_file_name: String) -> void:
	var parent: Node = get_parent()
	if not parent is TextureRect:
		push_error("CaptureTextureSetter: parent is not a TextureRect")
		return

	var base_name: String = lvl_file_name.get_file().get_basename()
	var photo_path: String = "user://" + LIKED_COURSE_FOLDER_NAME + "/" + base_name + ".png"

	# Web 导出没有 WorkerThreadPool 线程支持，直接在主线程加载封面
	if OS.has_feature("web"):
		_load_sync(photo_path)
		return

	var context: PhotoLoadContext = PhotoLoadContext.new()
	_context = context
	set_process(true)

	WorkerThreadPool.add_task(func() -> void:
		if not FileAccess.file_exists(photo_path):
			push_warning("CaptureTextureSetter: screenshot not found: %s" % photo_path)
			context.mutex.lock()
			context.done = true
			context.mutex.unlock()
			return

		var image: Image = Image.new()
		if image.load(photo_path) != OK:
			push_error("CaptureTextureSetter: failed to load image: %s" % photo_path)
			context.mutex.lock()
			context.done = true
			context.mutex.unlock()
			return

		image.resize(320, 240, Image.INTERPOLATE_LANCZOS)
		context.mutex.lock()
		context.image = image
		context.done = true
		context.mutex.unlock()
	)

func _process(_delta: float) -> void:
	if _context == null:
		set_process(false)
		return

	var done: bool = false
	var image: Image = null
	_context.mutex.lock()
	done = _context.done
	if done:
		image = _context.image
	_context.mutex.unlock()

	if not done:
		return

	set_process(false)
	_context = null
	if image == null:
		return
	_apply_texture(image)

func _load_sync(photo_path: String) -> void:
	if not FileAccess.file_exists(photo_path):
		return
	var image: Image = Image.new()
	if image.load(photo_path) != OK:
		return
	image.resize(320, 240, Image.INTERPOLATE_LANCZOS)
	_apply_texture(image)

func _apply_texture(image: Image) -> void:
	var parent: Node = get_parent()
	if parent is TextureRect and is_instance_valid(parent):
		var texture_rect: TextureRect = parent
		texture_rect.texture = ImageTexture.create_from_image(image)
		# 封面是异步读盘后一次性贴上去的，不淡入就会在某一帧硬弹出来。
		QuickFadeIn.play(texture_rect)
