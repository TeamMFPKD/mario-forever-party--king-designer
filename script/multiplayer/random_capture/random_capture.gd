extends Node

const RandomCaptureManagerScript: GDScript = preload("res://script/multiplayer/random_capture/random_capture_manager.gd")

var viewport: Viewport
var capture_texture: Texture2D
var random_capture_manager: RandomCaptureManagerScript


func _ready() -> void:
	var game_mode_singleton: GameMode = GameModeSingleton
	if game_mode_singleton.game_mode != GameMode.GameModeType.PLAY:
		var fc: Callable = func() -> void:
			queue_free()
		fc.call_deferred()
		return
	viewport = get_viewport()
	random_capture_manager = get_tree().get_first_node_in_group("random_capture_manager")


func capture() -> void:
	var viewport_texture: ViewportTexture = viewport.get_texture()
	var image: Image = viewport_texture.get_image()
	if image == null:
		return
	var tmp_texture: ImageTexture = ImageTexture.create_from_image(image)
	if tmp_texture == null:
		return
	tmp_texture.set_size_override(Vector2i(160, 120))

	var levels: Array[String] = MPManager.random_levels
	var index: int = MPManager.current_level_count
	if index < 0 or index >= levels.size():
		return
	var current_level: String = levels[index]
	for profile: PlayerProfile in MPManager.players:
		if profile.level_file_name != current_level:
			continue
		random_capture_manager.set_captures(profile.id, tmp_texture)
