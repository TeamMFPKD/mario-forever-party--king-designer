extends Node

@warning_ignore_start("unsafe_call_argument", "unsafe_cast")

## 百人团手机暂停键探针：把平台伪装成 Android，验证
## 1) MobilePauseLayer/MobilePauseButton 存在且可见；
## 2) 按下按钮能打开暂停菜单并冻结场景；
## 3) 菜单「继续」能恢复运行。
## 结果写 res://tools/adventure_mobile_pause_probe_result.txt。

const RESULT_PATH: String = "res://tools/adventure_mobile_pause_probe_result.txt"
const TEMP_STORE: String = "user://adventure_mobile_pause_probe.ini"


func _ready() -> void:
	var lines: Array[String] = []
	# 默认按桌面跑；加 --probe-mobile 才伪装 Android（手机端已单独验证过）。
	var expect_mobile: bool = MpTest.has("--probe-mobile")
	if expect_mobile:
		PlatformUtils.set_debug_platform("Android")
	lines.append("expect_mobile=%s" % str(expect_mobile))
	lines.append("platform_name=%s" % PlatformUtils.get_platform_name())
	lines.append("is_mobile=%s" % str(PlatformUtils.is_mobile_platform()))
	lines.append("is_desktop=%s" % str(PlatformUtils.is_desktop_platform()))
	lines.append("emulate_touch_from_mouse=%s" % str(Input.is_emulating_touch_from_mouse()))
	lines.append("emulate_mouse_from_touch=%s" % str(Input.is_emulating_mouse_from_touch()))

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
	lines.append("layer_found=%s" % str(layer != null))
	var button: Button = null
	if layer != null:
		button = layer.get_node_or_null("MobilePauseButton") as Button
	lines.append("button_found=%s" % str(button != null))
	lines.append("button_visible=%s" % str(button != null and button.visible))
	lines.append("pause_layer_count=%d" % _count_nodes(play, "MobilePauseLayer"))

	var menu: CanvasLayer = play.find_child("AdventurePauseMenu", true, false) as CanvasLayer
	lines.append("menu_found=%s" % str(menu != null))

	if button != null:
		button.emit_signal("pressed")
		# 卡片翻转 0.24 + 0.30 秒，留余量。
		await get_tree().create_timer(1.2).timeout
	lines.append("paused_after_open=%s" % str(get_tree().paused))
	lines.append("menu_visible_after_open=%s" % str(menu != null and menu.visible))

	# 暂停面板尺寸必须与关卡视口外边框装饰一致。
	var border: Control = play.find_child("GameBorderTextureRect", true, false) as Control
	var panel: Control = null
	if menu != null:
		panel = menu.get_node_or_null("Root/CardHolder") as Control
	lines.append("border_found=%s" % str(border != null))
	lines.append("panel_found=%s" % str(panel != null))
	lines.append("panel_size=%s" % str(panel.size if panel != null else Vector2.ZERO))
	lines.append("border_size=%s" % str(border.size if border != null else Vector2.ZERO))
	lines.append("panel_size_matches_border=%s" % str(
		panel != null and border != null and panel.size.is_equal_approx(border.size)
	))

	var continue_ok: bool = false
	if menu != null:
		for child: Node in menu.find_children("*", "Button", true, false):
			var candidate: Button = child as Button
			if candidate != null and candidate.text == "继续":
				candidate.emit_signal("pressed")
				await get_tree().create_timer(0.9).timeout
				continue_ok = not get_tree().paused and not menu.visible
				break
	lines.append("continue_ok=%s" % str(continue_ok))
	lines.append("paused_after_close=%s" % str(get_tree().paused))

	PlatformUtils.clear_debug_platform()
	lines.append("is_mobile_after_clear=%s" % str(PlatformUtils.is_mobile_platform()))
	lines.append("emulate_touch_after_clear=%s" % str(Input.is_emulating_touch_from_mouse()))
	_finish(lines)


func _count_nodes(root: Node, node_name: String) -> int:
	var count: int = 0
	for child: Node in root.find_children(node_name, "", true, false):
		count += 1
	return count


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
	for file_name: String in ["adventure_mobile_pause_probe.ini", "adventure_mobile_pause_probe.ini.tmp"]:
		if FileAccess.file_exists("user://" + file_name):
			dir.remove(file_name)
