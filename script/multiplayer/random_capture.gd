extends Node

var viewport
var capture_texture
var random_capture_manager
var multiplayer_manager : MultiplayerManager

func _ready():
	if GameModeSingleton.game_mode != GameModeSingleton.GameModeType.PLAY:
		var fc = func():
			queue_free()
		fc.call_deferred()
		return
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	viewport = get_viewport()
	random_capture_manager = get_tree().get_first_node_in_group("random_capture_manager")
	
# Capture test
func _physics_process(_delta: float) -> void:
	if not Input.is_key_pressed(KEY_0):
		return
	capture()

func capture() -> void:
	var viewport_texture = viewport.get_texture()
	var image = viewport_texture.get_image()
	var tmp_texture = ImageTexture.create_from_image(image)
	tmp_texture.set_size_override(Vector2i(160, 120))
	# can be set to TextureRect node for preview
	#texture = tmp_texture
	for player in multiplayer_manager.players:
		if not player["level_file_name"] == multiplayer_manager.random_levels[multiplayer_manager.current_level_count]:
			continue
		var current_level_player_id = player["id"]
		random_capture_manager.set_captures(current_level_player_id, tmp_texture)
