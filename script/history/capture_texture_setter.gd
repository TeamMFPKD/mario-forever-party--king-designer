extends Node

const LIKED_COURSE_FOLDER_NAME = "liked courses"

func set_photo(lvl_file_name: String) -> void:
	var texture_rect := get_parent() as TextureRect
	if not texture_rect:
		push_error("CaptureTextureSetter: parent is not a TextureRect")
		return

	var base_name := lvl_file_name.get_file().get_basename()
	var photo_path := "user://" + LIKED_COURSE_FOLDER_NAME + "/" + base_name + ".png"

	WorkerThreadPool.add_task(func():
		if not FileAccess.file_exists(photo_path):
			push_warning("CaptureTextureSetter: screenshot not found: %s" % photo_path)
			return

		var image := Image.new()
		if image.load(photo_path) != OK:
			push_error("CaptureTextureSetter: failed to load image: %s" % photo_path)
			return

		image.resize(320, 240, Image.INTERPOLATE_LANCZOS)
		call_deferred("_apply_texture", image)
	)

func _apply_texture(image: Image) -> void:
	var texture_rect := get_parent() as TextureRect
	if texture_rect:
		texture_rect.texture = ImageTexture.create_from_image(image)