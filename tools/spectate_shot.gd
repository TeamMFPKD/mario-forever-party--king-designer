extends Node

const OUTPUT_PATH: String = "res://tools/spectate.png"


func _ready() -> void:
	var level_path: String = _find_level()
	if level_path.is_empty():
		push_error("spectate_shot: no .lvl found in user://")
		get_tree().quit()
		return

	MPManager.player.id = 0
	MPManager.player.name = "viewer"
	MPManager.player.is_spectator = true
	MPManager.flow.phase = RoomPhase.Phase.PLAY
	var levels: Array[String] = [level_path]
	MPManager.flow.random_levels = levels
	MPManager.current_level_count = 0
	GameModeSingleton.game_mode = GameMode.GameModeType.PLAY

	var target: PlayerProfile = PlayerProfile.new()
	target.id = 2
	target.name = "target"
	target.current_level = 0
	MPManager.registry.add(target)
	MPManager.spectate_target_id = target.id

	var packed: PackedScene = load("res://room/spectate_room.tscn") as PackedScene
	var room: Node = packed.instantiate()
	add_child(room)
	await get_tree().create_timer(3.0).timeout
	var image: Image = get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(OUTPUT_PATH)
	get_tree().quit()


func _find_level() -> String:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return ""
	var newest: String = ""
	var newest_time: int = 0
	for name: String in dir.get_files():
		if not name.ends_with(".lvl"):
			continue
		var path: String = "user://" + name
		var size: int = FileAccess.get_file_as_bytes(path).size()
		if size < 128:
			continue
		var modified: int = int(FileAccess.get_modified_time(path))
		if modified >= newest_time:
			newest_time = modified
			newest = path
	return newest
