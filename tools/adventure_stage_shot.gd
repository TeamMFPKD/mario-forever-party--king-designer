extends Node

## 舞台截图：用临时存档造两个进行中的团，复现
## 「存档1 / 存档2 / 新存档 / 空 / 空」的一排 5 格，再截默认态与选中态。
## 必须窗口化运行（不要 --headless），否则取不到画面。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const OUTPUT_PATH: String = "res://tools/adventure_stage.png"
const LOADING_PATH: String = "res://tools/adventure_stage_loading.png"
const SELECTED_PATH: String = "res://tools/adventure_stage_selected.png"
const RESUME_PATH: String = "res://tools/adventure_stage_resume.png"
const TEMP_STORE: String = "user://adventure_stage_shot.ini"


func _ready() -> void:
	var store: AdventureStore = AdventureStore.new(TEMP_STORE)
	store.load()
	# 存档1 用 24 关（3 行）以便看到跨行曲线；存档2 是「随机」档，看存档卡银白描边。
	_seed(store, 1, 2, 1, 24)
	_seed(store, 2, 4, 0, 14)
	Adventure.store = store

	var packed: PackedScene = load("res://room/adventure_stage.tscn") as PackedScene
	if packed == null:
		get_tree().quit()
		return
	var stage: Node = packed.instantiate()
	add_child(stage)
	await get_tree().create_timer(0.3).timeout
	var loading_image: Image = get_viewport().get_texture().get_image()
	if loading_image != null:
		loading_image.save_png(LOADING_PATH)
	await get_tree().create_timer(7.0).timeout
	var image: Image = get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(OUTPUT_PATH)

	# 再截一张「选中新存档」：参数启用、开始按钮亮起。
	var slots: Node = stage.get_node_or_null("Layout/Box/SaveSlots")
	if slots != null:
		var titles: Array[String] = slots.call("card_titles")
		var new_index: int = titles.find("新存档")
		if new_index >= 0:
			var new_button: Button = slots.call("button_at", new_index) as Button
			if new_button != null:
				new_button.emit_signal("pressed")
				await get_tree().create_timer(0.5).timeout
				var selected_image: Image = get_viewport().get_texture().get_image()
				if selected_image != null:
					selected_image.save_png(SELECTED_PATH)

		# 再截一张「选中存档1」：侧边栏收起、关卡示意图换成该团路线、马里奥落在当前进度。
		var resume_button: Button = slots.call("button_at", 0) as Button
		if resume_button != null:
			resume_button.emit_signal("pressed")
			await get_tree().create_timer(0.5).timeout
			var resume_image: Image = get_viewport().get_texture().get_image()
			if resume_image != null:
				resume_image.save_png(RESUME_PATH)
	_cleanup()
	get_tree().quit()


func _seed(store: AdventureStore, slot: int, index: int, tier: int, total: int) -> void:
	store.set_run({
		"active": true,
		"level_keys": ["demo_a", "demo_b", "demo_c", "demo_d", "demo_e"],
		"index": index,
		"mode": "finite",
		"tier": tier,
		"total_levels": total,
		"cleared_count": index,
		"lives_left": 16,
		"deaths": 1,
		"skipped_soft": 0,
		"skipped_hard": 0,
	}, slot)


func _cleanup() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	for file_name: String in ["adventure_stage_shot.ini", "adventure_stage_shot.ini.tmp"]:
		if FileAccess.file_exists("user://" + file_name):
			dir.remove(file_name)
