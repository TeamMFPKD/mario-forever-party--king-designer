extends Node

const LIKED_COURSE_FOLDER_NAME = "liked courses"

func set_photo(lvl_file_name: String) -> void:
	var texture_rect := get_parent() as TextureRect
	if not texture_rect:
		push_error("CaptureTextureSetter: parent is not a TextureRect")
		return
	_load_and_display(texture_rect, lvl_file_name)


func _load_and_display(texture_rect: TextureRect, lvl_file_name: String) -> void:
	var base_name := lvl_file_name.get_file().get_basename()
	var photo_path := "user://" + LIKED_COURSE_FOLDER_NAME + "/" + base_name + ".png"

	if not FileAccess.file_exists(photo_path):
		push_warning("CaptureTextureSetter: screenshot not found: %s" % photo_path)
		return

	var image := Image.new()
	if image.load(photo_path) != OK:
		push_error("CaptureTextureSetter: failed to load image: %s" % photo_path)
		return

	image.resize(320, 240, Image.INTERPOLATE_LANCZOS)
	texture_rect.texture = ImageTexture.create_from_image(image)
