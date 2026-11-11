extends Node

## 观看前端演示场景。
##
## 直接运行本场景（F6）即可看到：
## - 紫色背景 + 游戏边框 + 观看 HUD；
## - PLAY 阶段自动生成两张演示关卡，并让四个假幽灵在两关里走动；
## - 1/2/3 切换 PLAY / EDIT / TRANSFER，查看等待界面；
## - ← / → 切换目标；目标在另一关时会自动加载另一张地图。

const DEMO_LEVEL_0: String = "user://spectate_demo.lvl"
const DEMO_LEVEL_1: String = "user://spectate_demo_2.lvl"
const DEMO_TARGET_ID: int = 2

var _room: Node = null
var _help_label: Label = null


func _ready() -> void:
	await _build_demo_level()
	_setup_demo_room()
	var packed: PackedScene = load("res://room/spectate_room.tscn") as PackedScene
	_room = packed.instantiate()
	add_child(_room)
	_add_help_label()
	await get_tree().create_timer(0.6).timeout
	var initial_phase: String = MpTest.get_value("--demo-phase", "play")
	if initial_phase == "edit":
		_set_phase(RoomPhase.Phase.EDIT)
	elif initial_phase == "transfer":
		_set_phase(RoomPhase.Phase.TRANSFER)
	_animate_demo_ghost()
	if MpTest.has("--demo-switch-level"):
		await get_tree().create_timer(1.0).timeout
		await _send_right()
		await get_tree().process_frame
		await _send_right()
	elif MpTest.has("--demo-switch"):
		await get_tree().create_timer(1.0).timeout
		await _send_right()
	if MpTest.has("--demo-shot"):
		await get_tree().create_timer(3.0).timeout
		var image: Image = get_viewport().get_texture().get_image()
		if image != null:
			var shot_path: String = "res://tools/spectate_demo.png"
			if MPManager.phase == RoomPhase.Phase.EDIT:
				shot_path = "res://tools/spectate_demo_edit.png"
			elif MPManager.phase == RoomPhase.Phase.TRANSFER:
				shot_path = "res://tools/spectate_demo_transfer.png"
			elif MPManager.current_level_count == 1:
				shot_path = "res://tools/spectate_demo_level2.png"
			image.save_png(shot_path)
			Log.i("SpectateDemo", "screenshot saved: %s" % shot_path)
		get_tree().quit()


func _send_right() -> void:
	var press: InputEventKey = InputEventKey.new()
	press.physical_keycode = KEY_RIGHT
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release: InputEventKey = InputEventKey.new()
	release.physical_keycode = KEY_RIGHT
	release.pressed = false
	Input.parse_input_event(release)


func _build_demo_level() -> void:
	var level_0: Array[Vector2i] = []
	for x: int in range(0, 20):
		level_0.append(Vector2i(x, 14))
	for x: int in range(4, 9):
		level_0.append(Vector2i(x, 10))
	for x: int in range(12, 17):
		level_0.append(Vector2i(x, 7))

	var level_1: Array[Vector2i] = []
	for x: int in range(0, 20):
		level_1.append(Vector2i(x, 14))
	for x: int in range(2, 7):
		level_1.append(Vector2i(x, 11))
	for x: int in range(9, 14):
		level_1.append(Vector2i(x, 8))
	for x: int in range(15, 19):
		level_1.append(Vector2i(x, 5))

	await _write_demo_level(DEMO_LEVEL_0, level_0, "level-0")
	await _write_demo_level(DEMO_LEVEL_1, level_1, "level-1")


func _write_demo_level(path: String, cells: Array[Vector2i], label: String) -> void:
	var tile_set: TileSet = load("res://sprite/tileset_resource/tileset_castle.tres") as TileSet
	if tile_set == null:
		push_error("spectate_demo: tileset_castle.tres not found")
		return

	var tile_map: TileMapLayer = TileMapLayer.new()
	tile_map.name = "DemoTileMap_" + label
	tile_map.tile_set = tile_set
	add_child(tile_map)
	await get_tree().process_frame

	var source_id: int = tile_set.get_source_id(0)
	if source_id < 0:
		push_error("spectate_demo: tileset has no source")
		tile_map.queue_free()
		return

	for cell: Vector2i in cells:
		tile_map.set_cell(cell, source_id, Vector2i(0, 0), 0)
	await get_tree().process_frame

	var tile_bytes: PackedByteArray = tile_map.tile_map_data
	var tile_array: Array = []
	for byte: int in tile_bytes:
		tile_array.append(byte)

	var level: Dictionary = {
		"version": 2,
		"time_used": -1,
		"level_theme": 0,
		"level_size": [0, 0, 640, 480],
		"tilemap_data": tile_array,
		"object_data": [],
		"pipe_line_data": [],
		"pass_count": 0,
		"death_count": 0,
		"lives": 2,
	}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("spectate_demo: cannot write demo level %s" % path)
		tile_map.queue_free()
		return
	file.store_string(JSON.stringify(level, ""))
	file.close()
	tile_map.queue_free()
	Log.i("SpectateDemo", "demo level written: %s (%d tile bytes)" % [
		path, tile_array.size(),
	])


func _setup_demo_room() -> void:
	MPManager.player.id = 0
	MPManager.player.name = "观众"
	MPManager.player.is_spectator = true
	MPManager.flow.phase = RoomPhase.Phase.PLAY
	var levels: Array[String] = [DEMO_LEVEL_0, DEMO_LEVEL_1]
	MPManager.flow.random_levels = levels
	MPManager.current_level_count = 0
	GameModeSingleton.game_mode = GameMode.GameModeType.PLAY

	# 前两名在关卡 0，后两名在关卡 1；左右切换会跨关卡加载。
	_add_demo_player(DEMO_TARGET_ID, "演示玩家", 0)
	_add_demo_player(DEMO_TARGET_ID + 1, "演示玩家2", 0)
	_add_demo_player(DEMO_TARGET_ID + 2, "演示玩家3", 1)
	_add_demo_player(DEMO_TARGET_ID + 3, "演示玩家4", 1)
	MPManager.spectate_target_id = DEMO_TARGET_ID


func _add_demo_player(id: int, name: String, level_index: int) -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	profile.id = id
	profile.name = name
	profile.current_level = level_index
	profile.connected = true
	MPManager.registry.add(profile)


func _add_help_label() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_help_label = Label.new()
	_help_label.text = "演示控制\n1 游玩\n2 编辑\n3 传输\n← / → 切换玩家\nEsc 退出"
	_help_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_help_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_help_label.add_theme_constant_override("outline_size", 5)
	_help_label.add_theme_font_size_override("font_size", 20)
	_help_label.position = Vector2(1636, 40)
	layer.add_child(_help_label)


func _animate_demo_ghost() -> void:
	var elapsed: float = 0.0
	while is_instance_valid(_room):
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		@warning_ignore("unsafe_cast")
		var manager: MpAniSpriteManager = _room.call("get_ghost_manager") as MpAniSpriteManager
		if manager == null:
			continue
		var current_level: int = MPManager.current_level_count
		for profile: PlayerProfile in MPManager.players:
			if profile.is_spectator or profile.current_level != current_level:
				continue
			var slot: int = profile.id - DEMO_TARGET_ID
			var direction: float = 1.0 if slot % 2 == 0 else -1.0
			var base_x: float = 64.0 + float(slot) * 96.0
			var x: float = base_x + fmod(elapsed * (72.0 + float(slot) * 12.0), 220.0) * direction
			x = clampf(x, 40.0, 600.0)
			var y: float = 384.0 + sin(elapsed * 2.4 + float(slot)) * 16.0
			manager.apply_remote_state(
				profile.id,
				Vector2(x, y),
				PlayerSuit.SuitType.SMALL,
				PlayerSuit.PowerupType.FIREBALL,
				&"walk",
				int(elapsed * 10.0 + float(slot)) % 4,
				direction < 0.0,
				false,
				Vector2.ONE,
				0.0
			)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1:
			_set_phase(RoomPhase.Phase.PLAY)
		KEY_2:
			_set_phase(RoomPhase.Phase.EDIT)
		KEY_3:
			_set_phase(RoomPhase.Phase.TRANSFER)
		KEY_ESCAPE:
			get_tree().quit()
		_:
			return
	get_viewport().set_input_as_handled()


func _set_phase(target_phase: int) -> void:
	MPManager.flow.phase = target_phase
	MPManager.flow.phase_changed.emit(target_phase, {})
