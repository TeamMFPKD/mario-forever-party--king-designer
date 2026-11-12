extends Node

@warning_ignore_start("unsafe_call_argument", "unsafe_cast")

## 百人团手机暂停键截图脚本（窗口运行，不能加 --headless）。
## 平台伪装成 Android 后：
##   1) 截图 tools/adventure_mobile_pause.png（按钮 + 手机虚拟按键）；
##   2) 用 InputEventScreenTouch 点击按钮中心，验证触摸链路；
##   3) 截图 tools/adventure_mobile_pause_menu.png（翻转后的暂停卡片）。

const RESULT_PATH: String = "res://tools/adventure_mobile_pause_shot_result.txt"
const TEMP_STORE: String = "user://adventure_mobile_pause_shot.ini"


func _ready() -> void:
	var lines: Array[String] = []
	# 默认按桌面跑；加 --shot-mobile 才伪装 Android（手机端已单独验证过）。
	var mobile_mode: bool = MpTest.has("--shot-mobile")
	if mobile_mode and not PlatformUtils.is_mobile_platform():
		PlatformUtils.set_debug_platform("Android")
	var shot_suffix: String = "_mobile" if mobile_mode else ""
	lines.append("mobile_mode=%s" % str(mobile_mode))
	lines.append("platform_name=%s" % PlatformUtils.get_platform_name())

	var store: AdventureStore = AdventureStore.new(TEMP_STORE)
	store.load()
	Adventure.store = store
	var started: bool = Adventure.start_run({
		"pool_source": "all",
		"tier": 0,
		"mode": "finite",
		"run_length": 5,
		"prefer_low_sample": true,
	})
	lines.append("start=%s" % str(started))
	if not started:
		lines.append("error=%s" % Adventure.last_error)
		_finish(lines)
		return

	var packed: PackedScene = load(Adventure.PLAY_SCENE) as PackedScene
	if packed == null:
		lines.append("play_scene_load=false")
		_finish(lines)
		return

	var play: Node = packed.instantiate()
	add_child(play)
	await get_tree().create_timer(2.0).timeout

	var layer: CanvasLayer = play.get_node_or_null("MobilePauseLayer") as CanvasLayer
	var button: Button = null
	if layer != null:
		button = layer.get_node_or_null("MobilePauseButton") as Button
	lines.append("button_found=%s" % str(button != null))
	lines.append("button_visible=%s" % str(button != null and button.visible))

	await RenderingServer.frame_post_draw
	_save("res://tools/adventure_mobile_pause%s.png" % shot_suffix)

	var mouse_opened: bool = false
	var touch_opened: bool = false
	if button != null:
		var center: Vector2 = button.get_global_rect().get_center()
		var window_pos: Vector2 = get_viewport().get_final_transform() * center
		lines.append("button_center=%s" % str(center))
		lines.append("button_window_pos=%s" % str(window_pos))
		lines.append("emulate_touch_from_mouse=%s" % str(Input.is_emulating_touch_from_mouse()))
		# 优先用鼠标点击：伪装 Android 时会经 emulate_touch_from_mouse 转成触摸。
		var press_ms: int = Time.get_ticks_msec()
		_mouse(window_pos, true)
		await get_tree().process_frame
		_mouse(window_pos, false)
		# 翻转约 0.55s：抓两帧中间态，确认透视与倾斜生效。
		await get_tree().create_timer(0.30).timeout
		await RenderingServer.frame_post_draw
		_save("res://tools/adventure_mobile_pause_flip_a%s.png" % shot_suffix)
		lines.append("flip_a_ms=%d" % (Time.get_ticks_msec() - press_ms))
		var mid_mesh: MeshInstance2D = play.find_child("FlipMesh", true, false) as MeshInstance2D
		if mid_mesh != null:
			lines.append("flip_a_scale=%.3f" % mid_mesh.scale.x)
		await get_tree().create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		_save("res://tools/adventure_mobile_pause_flip_b%s.png" % shot_suffix)
		lines.append("flip_b_ms=%d" % (Time.get_ticks_msec() - press_ms))
		await get_tree().create_timer(0.7).timeout
		mouse_opened = get_tree().paused
		if not mouse_opened:
			# 再直接注入屏幕触摸。
			_touch(window_pos, true)
			await get_tree().process_frame
			_touch(window_pos, false)
			await get_tree().create_timer(1.2).timeout
			touch_opened = get_tree().paused
		if not mouse_opened and not touch_opened:
			# 边角情况：退回直接触发按钮，保证截图脚本仍能出图。
			button.emit_signal("pressed")
			await get_tree().create_timer(1.2).timeout
	lines.append("mouse_opened=%s" % str(mouse_opened))
	lines.append("touch_opened=%s" % str(touch_opened))
	lines.append("paused=%s" % str(get_tree().paused))
	var flip_mesh: MeshInstance2D = play.find_child("FlipMesh", true, false) as MeshInstance2D
	if flip_mesh != null:
		var flip_material: ShaderMaterial = flip_mesh.material as ShaderMaterial
		if flip_material != null:
			lines.append("flip_yaw=%s" % str(flip_material.get_shader_parameter("yaw")))
			lines.append("flip_pitch=%s" % str(flip_material.get_shader_parameter("pitch")))
			lines.append("flip_roll=%s" % str(flip_material.get_shader_parameter("roll")))
			lines.append("flip_perspective=%s" % str(flip_material.get_shader_parameter("perspective")))
			lines.append("flip_card_tex_null=%s" % str(flip_material.get_shader_parameter("card_tex") == null))
	var menu: CanvasLayer = play.find_child("AdventurePauseMenu", true, false) as CanvasLayer
	lines.append("menu_visible=%s" % str(menu != null and menu.visible))

	await RenderingServer.frame_post_draw
	_save("res://tools/adventure_mobile_pause_menu%s.png" % shot_suffix)
	_finish(lines)


func _touch(position: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)


func _mouse(position: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	# 手动注入时必须带 button_mask，否则 Control 的按钮掩码判定不通过。
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)


func _save(path: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(path)


func _finish(lines: Array[String]) -> void:
	get_tree().paused = false
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	_cleanup()
	get_tree().quit()


func _cleanup() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	for file_name: String in ["adventure_mobile_pause_shot.ini", "adventure_mobile_pause_shot.ini.tmp"]:
		if FileAccess.file_exists("user://" + file_name):
			dir.remove(file_name)
