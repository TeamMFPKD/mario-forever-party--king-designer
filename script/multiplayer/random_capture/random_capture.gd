extends Node

const RandomCaptureManagerScript: GDScript = preload("res://script/multiplayer/random_capture/random_capture_manager.gd")

var viewport: Viewport
var capture_texture: Texture2D
var multiplayer_manager: MultiplayerManager
var random_capture_manager: RandomCaptureManagerScript

func _ready() -> void:
	var game_mode_singleton: GameMode = GameModeSingleton
	if game_mode_singleton.game_mode != GameMode.GameModeType.PLAY:
		var fc: Callable = func() -> void:
			queue_free()
		fc.call_deferred()
		return
	multiplayer_manager = MPManager
	viewport = get_viewport()
	random_capture_manager = get_tree().get_first_node_in_group("random_capture_manager")
	
# Capture test
#func _physics_process(_delta: float) -> void:
#	if not Input.is_key_pressed(KEY_0):
#		return
#	capture()

func capture() -> void:
	var viewport_texture: ViewportTexture = viewport.get_texture()
	var image: Image = viewport_texture.get_image()
	var tmp_texture: ImageTexture = ImageTexture.create_from_image(image)
	tmp_texture.set_size_override(Vector2i(160, 120))
	# can be set to TextureRect node for preview
	#texture = tmp_texture
	for player: Dictionary in multiplayer_manager.players:
		if not player["level_file_name"] == multiplayer_manager.random_levels[multiplayer_manager.current_level_count]:
			continue
		var current_level_player_id: Variant = player["id"]
		random_capture_manager.set_captures(current_level_player_id, tmp_texture)