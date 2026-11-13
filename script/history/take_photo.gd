extends Node

signal photo_taken

@export var take_photo_ani_spd: float = 0.2

const LONG_PRESS_CANCEL_TIME: float = 1.0
const CAPTURE_SLIDE_DISTANCE: float = 48.0
const CAPTURE_SLIDE_TIME: float = 0.28

var viewport: Viewport
var level_path_node: Node
var image: Image

var _photo_hold_time: float = 0.0
var _photo_hold_active: bool = false
var _photo_hold_triggered: bool = false
var _photo_press_was_liked: bool = false
var _capture_rest_position: Vector2 = Vector2.ZERO
var _capture_rest_saved: bool = false
var _slide_tween: Tween
var _flying_sprite: Sprite2D
var _fly_tween: Tween


func _ready() -> void:
	viewport = get_viewport()


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		# 暂停期间不拍摄，也丢弃未完成的短按，避免恢复瞬间误拍。
		_photo_hold_active = false
		_photo_hold_time = 0.0
		return

	var pressed: bool = Input.is_action_pressed("photo")
	if Input.is_action_just_pressed("photo"):
		_photo_hold_time = 0.0
		_photo_hold_triggered = false
		_photo_press_was_liked = _is_current_level_liked()
		if not _photo_press_was_liked:
			# 没收藏过：按一下和长按都直接收藏。
			_photo_hold_active = false
			capture()
			return
		# 已收藏：先不拍，短按松开时拍摄；按住满 1 秒则取消收藏。
		_photo_hold_active = true

	if not _photo_hold_active:
		return
	if not pressed:
		_photo_hold_active = false
		_photo_hold_time = 0.0
		if _photo_press_was_liked and not _photo_hold_triggered:
			capture()
		return

	_photo_hold_time += delta
	if not _photo_hold_triggered and _photo_hold_time >= LONG_PRESS_CANCEL_TIME:
		_photo_hold_triggered = true
		_cancel_like()


func _is_current_level_liked() -> bool:
	var path: String = _resolve_level_path()
	if path.is_empty() or path == "invalid":
		return false
	var file_name: String = path.get_file()
	return not file_name.is_empty() and LikedCourses.is_liked(file_name)


func _resolve_level_path() -> String:
	level_path_node = get_tree().get_first_node_in_group("level_path_set")
	var path: String = ""
	if level_path_node != null:
		path = str(level_path_node.get_meta("level_path_name", ""))
	# 百人团场景没有 LevelPathSet 的 meta，直接取当前团关卡。
	if (path.is_empty() or path == "invalid") and GameMode.is_adventure() and Adventure.is_running():
		path = Adventure.current_level_path()
	return path


func capture() -> void:
	var path: String = _resolve_level_path()
	if path.is_empty() or path == "invalid":
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
	if viewport == null:
		viewport = get_viewport()
	if viewport == null:
		return
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


## 长按拍摄键：取消收藏，删掉封面，并让 capture 小图左划淡出。
func _cancel_like() -> void:
	var path: String = _resolve_level_path()
	if path.is_empty() or path == "invalid":
		return
	var file_name: String = path.get_file()
	if file_name.is_empty():
		return

	LikedCourses.remove(file_name)
	var target_png: String = LikedCourses.photo_path(file_name)
	if FileAccess.file_exists(target_png):
		var error: Error = DirAccess.remove_absolute(target_png)
		if error != OK:
			push_warning("[take_photo.gd] Failed to remove liked photo: %s" % error_string(error))

	# 大图飞入只是拍摄时的过程动画；取消收藏时先清掉它，
	# 真正做左划淡出的是左上角 capture 的小图。
	_free_flying_sprite()

	var texture_rect: Control = get_tree().get_first_node_in_group("capture_texture_rect")
	if texture_rect != null and texture_rect.get("texture") != null:
		_slide_out_capture(texture_rect)


func _create_capture_preview() -> void:
	var texture_rect: Control = get_tree().get_first_node_in_group("capture_texture_rect")
	if texture_rect == null or image == null:
		return

	var preview: Control = texture_rect.get_parent() as Control
	if preview != null:
		if _slide_tween != null and _slide_tween.is_valid():
			_slide_tween.kill()
			_slide_tween = null
		# 飞入动画到位之前不显示 capture UI。
		preview.visible = false
		preview.modulate = Color.WHITE

	if not _capture_rest_saved:
		_capture_rest_position = texture_rect.position
		_capture_rest_saved = true
	texture_rect.position = _capture_rest_position
	texture_rect.modulate = Color.WHITE

	# TextureRect 默认 EXPAND_KEEP_SIZE 会把最小尺寸撑到 640×480；
	# 这里强制按 capture 槽位的 200×150 显示，否则整张预览会被放大。
	texture_rect.set("expand_mode", TextureRect.EXPAND_IGNORE_SIZE)
	var preview_texture: ImageTexture = ImageTexture.create_from_image(image)
	preview_texture.set_size_override(Vector2i(texture_rect.size))
	texture_rect.set("texture", preview_texture)

	if not _spawn_fly_in(texture_rect):
		_show_capture_preview(texture_rect)


## 拍摄时的原始动画：整张截图旋转飞入 capture 小图，落点尺寸与 capture 完全一致。
## 返回 true 表示动画已启动；到位后才显示 capture UI。
func _spawn_fly_in(texture_rect: Control) -> bool:
	var game_room_node: Control = get_tree().get_first_node_in_group("game_room") as Control
	if game_room_node == null or image == null:
		return false
	_free_flying_sprite()

	var sprite: Sprite2D = Sprite2D.new()
	game_room_node.add_child(sprite)
	sprite.texture = ImageTexture.create_from_image(image)

	# 飞入起点必须锚定关卡视口（SubViewportContainer），
	# 不能用整个 GameRoomSize，否则动画一开始会盖住左右 HUD。
	var level_viewport: Control = null
	var viewport_parent: Node = get_parent()
	if viewport_parent is SubViewport:
		level_viewport = viewport_parent.get_parent() as Control
	if level_viewport == null:
		level_viewport = game_room_node.get_node_or_null("SubViewportContainer") as Control

	var start_rect: Rect2 = game_room_node.get_global_rect()
	if level_viewport != null:
		start_rect = level_viewport.get_global_rect()

	var start_pos: Vector2 = start_rect.position + start_rect.size / 2.0
	var target_rect: Rect2 = texture_rect.get_global_rect()
	var end_pos: Vector2 = target_rect.position + target_rect.size / 2.0
	var texture_size: Vector2i = image.get_size()
	var start_scale: Vector2 = Vector2(
		start_rect.size.x / texture_size.x,
		start_rect.size.y / texture_size.y
	)
	var end_scale: Vector2 = Vector2(
		target_rect.size.x / texture_size.x,
		target_rect.size.y / texture_size.y
	)

	sprite.global_position = start_pos
	sprite.scale = start_scale
	sprite.rotation = 0.0
	_flying_sprite = sprite

	_fly_tween = create_tween().set_parallel(true)
	_fly_tween.tween_property(sprite, "global_position", end_pos, take_photo_ani_spd)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	_fly_tween.tween_property(sprite, "scale", end_scale, take_photo_ani_spd)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	_fly_tween.tween_property(sprite, "rotation", deg_to_rad(-360.0), take_photo_ani_spd)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	_fly_tween.finished.connect(func() -> void:
		if is_instance_valid(sprite):
			sprite.queue_free()
		if _flying_sprite == sprite:
			_flying_sprite = null
		_fly_tween = null
		_show_capture_preview(texture_rect)
	)
	return true


func _show_capture_preview(texture_rect: Control) -> void:
	var preview: Control = texture_rect.get_parent() as Control
	if preview != null:
		preview.visible = true
		preview.modulate = Color.WHITE


func _free_flying_sprite() -> void:
	if _fly_tween != null and _fly_tween.is_valid():
		_fly_tween.kill()
	_fly_tween = null
	if is_instance_valid(_flying_sprite):
		_flying_sprite.queue_free()
	_flying_sprite = null


## 取消收藏时只动 capture 这张小图：左移 + 淡出，不碰整张大图。
func _slide_out_capture(texture_rect: Control) -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()

	_slide_tween = create_tween().set_parallel(true)
	_slide_tween.tween_property(
		texture_rect, "position:x",
		texture_rect.position.x - CAPTURE_SLIDE_DISTANCE,
		CAPTURE_SLIDE_TIME
	)
	_slide_tween.tween_property(texture_rect, "modulate:a", 0.0, CAPTURE_SLIDE_TIME)
	await _slide_tween.finished
	_slide_tween = null

	texture_rect.set("texture", null)
	texture_rect.position = _capture_rest_position
	texture_rect.modulate = Color.WHITE
	var preview: Control = texture_rect.get_parent() as Control
	if preview != null:
		preview.visible = false
