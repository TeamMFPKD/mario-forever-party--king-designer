extends Node

const LIKED_COURSE_FOLDER_NAME: String = "liked courses"

func set_photo(lvl_file_name: String) -> void:
	var parent: Node = get_parent()
	if not parent is TextureRect:
		push_error("CaptureTextureSetter: parent is not a TextureRect")
		return
	var texture_rect: TextureRect = parent

	var base_name: String = lvl_file_name.get_file().get_basename()
	var photo_path: String = "user://" + LIKED_COURSE_FOLDER_NAME + "/" + base_name + ".png"

	WorkerThreadPool.add_task(func() -> void:
		if not FileAccess.file_exists(photo_path):
			push_warning("CaptureTextureSetter: screenshot not found: %s" % photo_path)
			return

		var image: Image = Image.new()
		if image.load(photo_path) != OK:
			push_error("CaptureTextureSetter: failed to load image: %s" % photo_path)
			return

		image.resize(320, 240, Image.INTERPOLATE_LANCZOS)
		call_deferred("_apply_texture", image)
	)

func _apply_texture(image: Image) -> void:
	var parent: Node = get_parent()
	if parent is TextureRect:
		var texture_rect: TextureRect = parent
		texture_rect.texture = ImageTexture.create_from_image(image)
