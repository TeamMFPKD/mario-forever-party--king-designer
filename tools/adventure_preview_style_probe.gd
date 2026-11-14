extends Node

## 验证关卡示意图样式：编号是白色实心字（无减法材质）、椭圆之间的连线有黑色描边。
## 需要窗口化运行（读像素），结果写 tools/adventure_preview_style_probe_result.txt。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const TEMP_STORE: String = "user://adventure_preview_style_probe.ini"
const RESULT_PATH: String = "res://tools/adventure_preview_style_probe_result.txt"
const LOAD_TIMEOUT_SEC: float = 60.0
const GRID_PATH: String = "Layout/Box/PreviewPanel/PreviewCenter/PreviewGrid"
const SLOTS_PATH: String = "Layout/Box/SaveSlots"


func _ready() -> void:
	var lines: Array[String] = []
	var store: AdventureStore = AdventureStore.new(TEMP_STORE)
	store.load()
	store.set_run(_seed_run(12), 1)
	Adventure.store = store
	Adventure.current_run = {}

	var packed: PackedScene = load("res://room/adventure_stage.tscn") as PackedScene
	var stage: Node = packed.instantiate()
	add_child(stage)
	await _wait_pool_idle(stage)

	var slots: Node = stage.get_node_or_null(SLOTS_PATH)
	if slots == null:
		_write(["slots_found=false"])
		return
	var resume_button: Button = slots.call("button_at", 0) as Button
	if resume_button == null:
		_write(["resume_button_found=false"])
		return
	resume_button.emit_signal("pressed")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw

	var grid: Control = stage.get_node_or_null(GRID_PATH) as Control
	if grid == null:
		_write(["grid_found=false"])
		return
	lines.append("grid_count=%d" % grid.get_child_count())
	lines.append("grid_size=%s" % str(grid.size))

	var cell0: Node2D = grid.get_child(0) as Node2D
	var cell1: Node2D = grid.get_child(1) as Node2D
	lines.append("cell0_children=%d" % cell0.get_child_count())
	var label: Label = null
	for child: Node in cell0.get_children():
		var candidate: Label = child as Label
		if candidate != null:
			label = candidate
	lines.append("number_label=%s" % str(label != null))
	if label != null:
		lines.append("number_text=%s" % label.text)
		lines.append("font_color=%s" % label.get_theme_color("font_color").to_html(false))
		lines.append("outline_color=%s" % label.get_theme_color("font_outline_color").to_html(false))
		lines.append("outline_size=%d" % label.get_theme_constant("outline_size"))
		lines.append("font_size=%d" % label.get_theme_font_size("font_size"))
		var second_label: Label = grid.get_child(1).get_node_or_null("Number") as Label
		lines.append("number_2_text=%s" % (second_label.text if second_label != null else "missing"))
		lines.append("has_material=%s" % str(label.material != null))

	# 像素剖面：两颗椭圆中间那条水平线，中心应为彩色线、上下 2px 为黑描边。
	var image: Image = get_viewport().get_texture().get_image()
	var image_scale: float = float(image.get_width()) / float(get_viewport().get_visible_rect().size.x)
	var mid: Vector2 = (cell0.global_position + cell1.global_position) * 0.5
	var profile: Array[String] = []
	for offset: int in range(-5, 6):
		var probe: Vector2 = Vector2(mid.x, mid.y + float(offset)) * image_scale
		var pixel: Color = image.get_pixelv(Vector2i(probe.round()))
		profile.append("%d:%s" % [offset, pixel.to_html(false)])
	lines.append("line_profile=%s" % "|".join(profile))
	var dark_count: int = 0
	for offset: int in range(-5, 6):
		if absi(offset) < 2:
			continue
		var probe: Vector2 = Vector2(mid.x, mid.y + float(offset)) * image_scale
		var pixel: Color = image.get_pixelv(Vector2i(probe.round()))
		if pixel.r < 0.15 and pixel.g < 0.15 and pixel.b < 0.15:
			dark_count += 1
	lines.append("line_outline_dark=%d" % dark_count)

	# 数字内部：椭圆中心附近应出现接近纯白的像素（白色实心字）。
	var center: Vector2 = cell0.global_position * image_scale
	var white_count: int = 0
	for dx: int in range(-10, 11):
		for dy: int in range(-12, 13):
			var pixel: Color = image.get_pixelv(
				Vector2i(Vector2(center.x + float(dx), center.y + float(dy)).round())
			)
			if pixel.r > 0.95 and pixel.g > 0.95 and pixel.b > 0.95:
				white_count += 1
	lines.append("number_white_pixels=%d" % white_count)
	lines.append("style_ok=%s" % str(white_count > 20 and dark_count >= 3))

	_write(lines)
	_cleanup()
	get_tree().quit()


func _seed_run(total: int) -> Dictionary:
	var keys: Array[String] = []
	for index: int in range(total):
		keys.append("preview_style_%d.lvl" % index)
	return {
		"active": true,
		"level_keys": keys,
		"index": 1,
		"mode": "finite",
		"tier": 2,
		"total_levels": total,
		"cleared_count": 1,
		"lives_left": 16,
		"deaths": 0,
		"skipped_soft": 0,
		"skipped_hard": 0,
	}


func _wait_pool_idle(stage: Node) -> void:
	var waited: float = 0.0
	while waited < LOAD_TIMEOUT_SEC:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if not bool(stage.get("_loading")):
			return


func _write(lines: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()


func _cleanup() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	for file_name: String in ["adventure_preview_style_probe.ini", "adventure_preview_style_probe.ini.tmp"]:
		if FileAccess.file_exists("user://" + file_name):
			dir.remove(file_name)
