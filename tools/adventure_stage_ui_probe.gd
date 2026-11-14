extends Node

## 舞台 UI 交互探针：一排固定 5 格（存档1 / 存档2 / 新存档 / 空 / 空），
## 无选中 / 选中新存档 / 选中存档位 / 重复点选 / 点格不切场景。
## 无头运行，结果写 tools/adventure_stage_ui_probe_result.txt。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const TEMP_STORE: String = "user://adventure_stage_ui_probe.ini"
const RESULT_PATH: String = "res://tools/adventure_stage_ui_probe_result.txt"
const POOL_LOAD_SEC: float = 4.0


func _ready() -> void:
	var store: AdventureStore = AdventureStore.new(TEMP_STORE)
	store.load()
	# 存档1 = 普通档（验证背景换色），存档2 = 随机档（验证存档卡银白描边）。
	_seed(store, 1, 1, 2)
	_seed(store, 2, 4, 0)
	Adventure.store = store

	var packed: PackedScene = load("res://room/adventure_stage.tscn") as PackedScene
	if packed == null:
		_write(["stage_loaded=false"])
		return
	var stage: Node = packed.instantiate()
	add_child(stage)
	await get_tree().create_timer(POOL_LOAD_SEC).timeout

	var lines: Array[String] = ["stage_loaded=true"]
	var start: Button = stage.get_node_or_null("Layout/Box/BottomBar/StartButton") as Button
	var pool: Button = stage.get_node_or_null(
		"Layout/Box/PreviewPanel/ParamsPanel/ParamsMargin/ParamsBox/PoolRow/PoolAll"
	) as Button
	var slots: Node = stage.get_node_or_null("Layout/Box/SaveSlots")
	var params: PanelContainer = stage.get_node_or_null(
		"Layout/Box/PreviewPanel/ParamsPanel"
	) as PanelContainer
	var center: CenterContainer = stage.get_node_or_null(
		"Layout/Box/PreviewPanel/PreviewCenter"
	) as CenterContainer
	var grid: Control = stage.get_node_or_null(
		"Layout/Box/PreviewPanel/PreviewCenter/PreviewGrid"
	) as Control
	var bg_rect: ColorRect = stage.get_node_or_null("Background") as ColorRect
	var bg_art: Node2D = stage.get_node_or_null("BackgroundArt") as Node2D
	var tier_column: Node = stage.get_node_or_null(
		"Layout/Box/PreviewPanel/ParamsPanel/ParamsMargin/ParamsBox/TierColumn"
	)
	if (
		start == null
		or pool == null
		or slots == null
		or params == null
		or center == null
		or grid == null
		or bg_rect == null
		or bg_art == null
		or tier_column == null
	):
		_write(lines + ["nodes_found=false"])
		return
	lines.append("nodes_found=true")

	# 1. 一排只有 5 格：存档1 / 存档2 / 新存档 / 空 / 空，没有第 6 张按钮。
	var titles: Array[String] = slots.call("card_titles")
	lines.append("slot_count=%d" % titles.size())
	lines.append("cards=%s" % "|".join(titles))
	lines.append("no_sixth_card=%s" % str(slots.find_child("Slot6", true, false) == null))
	lines.append("new_slot_on_first_free=%s" % str(store.first_free_slot() == 3))
	var empty_index: int = titles.find("空")
	var empty_button: Button = slots.call("button_at", empty_index) as Button
	lines.append("empty_slot_disabled=%s" % str(empty_button != null and empty_button.disabled))
	# 存档卡按团档位着色：存档1 普通（绿系描边），存档2 随机（银白描边）。
	lines.append("run1_card_border=%s" % _border_html(slots.call("button_at", 0) as Button))
	lines.append("run2_card_border=%s" % _border_html(slots.call("button_at", 1) as Button))

	# 2. 进入舞台：无选中，开始与参数都禁用，且不预选任何项。
	lines.append("no_select_start_disabled=%s" % str(start.disabled))
	lines.append("no_select_params_disabled=%s" % str(pool.disabled))
	lines.append("no_select_selection=%d" % int(slots.call("get_selection")))
	lines.append("no_select_scene_kept=%s" % str(get_tree().current_scene == self))
	# 侧边栏默认收起，示意图按设置路线居中，马里奥站在第 1 格。
	lines.append("no_select_params_hidden=%s" % str(not params.visible))
	lines.append("no_select_preview_left=%d" % int(center.offset_left))
	lines.append("no_select_preview_count=%d" % grid.get_child_count())
	lines.append("no_select_mario_index=%d" % _mario_index(grid))
	lines.append("no_select_bg=%s" % bg_rect.color.to_html(false))
	lines.append("no_select_bg_art=%s" % _visible_bg_art(bg_art))
	# 「随机」按钮银白描边，四档按钮仍是主题深色描边。
	var random_button: Button = tier_column.get_node_or_null("Tier5") as Button
	var tier1_button: Button = tier_column.get_node_or_null("Tier1") as Button
	lines.append("random_border=%s" % _border_html(random_button))
	lines.append("tier1_border=%s" % _border_html(tier1_button))

	# 3. 选中「新存档」：只改状态，不切场景；开始与参数启用。
	var new_button: Button = slots.call("button_at", titles.find("新存档")) as Button
	if new_button == null:
		_write(lines + ["new_slot_button=false"])
		return
	new_button.emit_signal("pressed")
	await get_tree().process_frame
	lines.append("new_start_enabled=%s" % str(not start.disabled))
	lines.append("new_params_enabled=%s" % str(not pool.disabled))
	lines.append("new_selection=%d" % int(slots.call("get_selection")))
	lines.append("new_scene_kept=%s" % str(get_tree().current_scene == self))
	# 侧边栏展开动画跑完：可见，但示意图位置不动（覆盖式侧栏，不推挤）。
	await get_tree().create_timer(0.4).timeout
	lines.append("new_params_visible=%s" % str(params.visible))
	lines.append("new_preview_left=%d" % int(center.offset_left))

	# 4. 再次点击已选中项：不取消选中。
	new_button.emit_signal("pressed")
	await get_tree().process_frame
	lines.append("repeat_click_kept=%s" % str(int(slots.call("get_selection")) == 0))
	lines.append("repeat_click_start_enabled=%s" % str(not start.disabled))

	# 5. 选中「存档1」：参数重新禁用，开始按钮仍可用（续团）。
	var resume_button: Button = slots.call("button_at", 0) as Button
	if resume_button != null:
		resume_button.emit_signal("pressed")
		await get_tree().process_frame
	lines.append("resume_selection=%d" % int(slots.call("get_selection")))
	lines.append("resume_params_disabled=%s" % str(pool.disabled))
	lines.append("resume_start_enabled=%s" % str(not start.disabled))
	# 切到已有存档：侧边栏收起并隐藏，示意图位置不变；
	# 路线换成该团 10 关，马里奥落在 index=1 的第二格上。
	await get_tree().create_timer(0.4).timeout
	lines.append("resume_params_hidden=%s" % str(not params.visible))
	lines.append("resume_preview_left=%d" % int(center.offset_left))
	lines.append("resume_preview_count=%d" % grid.get_child_count())
	lines.append("resume_mario_index=%d" % _mario_index(grid))
	# 选中存档后主题色切到该团档位（存档1 = 普通 = 3F8C5A，整屏渐变换成 Normal）。
	lines.append("resume_bg=%s" % bg_rect.color.to_html(false))
	lines.append("resume_bg_art=%s" % _visible_bg_art(bg_art))

	# 6. 补满 5 个团：仍然只有 5 格，没有「新存档」入口。
	for slot: int in range(3, 6):
		_seed(store, slot, 1, 3)
	stage.call("_refresh_save_slots")
	var full_titles: Array[String] = slots.call("card_titles")
	lines.append("full_slot_count=%d" % full_titles.size())
	lines.append("full_cards=%s" % "|".join(full_titles))
	lines.append("full_no_new_slot=%s" % str(full_titles.find("新存档") == -1))
	lines.append("full_resume_start_enabled=%s" % str(not start.disabled))

	# 7. 无尽团的存档卡：卡面换成滚动的多色渐变（Paint），样式表只剩档位色描边。
	_seed_mode(store, 3, 1, 2, "endless")
	stage.call("_refresh_save_slots")
	await get_tree().process_frame
	var endless_button: Button = slots.call("button_at", 2) as Button
	var endless_paint: Control = endless_button.get_node_or_null("Paint") as Control
	lines.append("endless_paint_present=%s" % str(endless_paint != null))
	lines.append("endless_paint_active=%s" % str(endless_paint != null and endless_paint.visible))
	var finite_paint: Control = (slots.call("button_at", 0) as Button).get_node_or_null("Paint") as Control
	lines.append("finite_paint_off=%s" % str(finite_paint == null or not finite_paint.visible))
	# 样式表透明底（彩色由 Paint 出），描边仍是该团档位的颜色。
	var endless_style: StyleBoxFlat = endless_button.get_theme_stylebox("normal") as StyleBoxFlat
	lines.append("endless_style_alpha=%d" % int(round(endless_style.bg_color.a * 100.0)))
	lines.append("endless_style_border=%s" % endless_style.border_color.to_html(false))
	var endless_title: Label = endless_button.get_node_or_null("Content/Title") as Label
	lines.append("endless_title_dark=%s" % str(_title_color_html(endless_title) == "1a1a1f"))
	lines.append("endless_title_outline=%d" % int(endless_title.get_theme_constant("outline_size")))
	# 选中无尽卡：描边加粗，卡面不换成纯色（Paint 仍然开着）。
	endless_button.emit_signal("pressed")
	await get_tree().process_frame
	var selected_style: StyleBoxFlat = endless_button.get_theme_stylebox("normal") as StyleBoxFlat
	lines.append("endless_selected_border=%d" % int(selected_style.border_width_left))
	lines.append("endless_selected_paint=%s" % str(endless_paint != null and endless_paint.visible))
	# 卡面尺寸写进了 shader（换分辨率时色块不缩水），且五张卡各用各的材质。
	lines.append("endless_paint_width=%d" % int(endless_paint.call("painted_size").x))
	var shared_material: bool = false
	if finite_paint != null and endless_paint != null:
		shared_material = (
			(finite_paint as ColorRect).material == (endless_paint as ColorRect).material
		)
	lines.append("endless_material_isolated=%s" % str(not shared_material))
	# 切回定量团：彩色卡面关掉、标题撤回样式表默认色。
	_seed_mode(store, 3, 1, 2, "finite")
	stage.call("_refresh_save_slots")
	await get_tree().process_frame
	lines.append("back_to_finite_paint_off=%s" % str(not endless_paint.visible))
	lines.append("back_to_finite_title=%s" % _title_color_html(endless_title))
	# 改名回归（2026-11-14）：玩家文案统一为「随心挑战」/「开始挑战」，
	# 这几个字符串一旦回退成开发代号就说明某份 tscn 被覆盖回去了。
	var stage_title: Label = stage.get_node_or_null("Layout/Box/TitleBar/Title") as Label
	lines.append("stage_title=%s" % (stage_title.text if stage_title != null else "none"))
	lines.append("start_button_text=%s" % start.text)

	_write(lines)
	_cleanup()
	get_tree().quit()


## 标题实际生效的字色（十六进制）。Label 没有 color 属性，只能走主题查询。
func _title_color_html(title: Label) -> String:
	if title == null:
		return "none"
	return title.get_theme_color("font_color").to_html(false)


## 当前可见的难度背景 Sprite 名字（Easy/Normal/...），没有则 none。
func _visible_bg_art(art: Node2D) -> String:
	if art == null:
		return "none"
	for child: Node in art.get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite != null and sprite.visible:
			return str(sprite.name)
	return "none"


## 按钮常态描边色（十六进制），找不到时返回 none。
func _border_html(button: Button) -> String:
	if button == null:
		return "none"
	var style: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
	return style.border_color.to_html(false) if style != null else "none"


## 马里奥挂在第几格上；-1 表示没找到（每格最多一个）。
func _mario_index(grid: Control) -> int:
	for index: int in range(grid.get_child_count()):
		var cell: Node = grid.get_child(index)
		for child: Node in cell.get_children():
			if child is AnimatedSprite2D:
				return index
	return -1


func _seed_mode(store: AdventureStore, slot: int, index: int, tier: int, mode: String) -> void:
	_seed(store, slot, index, tier, mode)


## 无尽团没有总关数（total_levels = -1），其余字段一样。
func _seed(store: AdventureStore, slot: int, index: int, tier: int, mode: String = "finite") -> void:
	store.set_run({
		"active": true,
		"level_keys": ["demo_a", "demo_b", "demo_c", "demo_d", "demo_e"],
		"index": index,
		"mode": mode,
		"tier": tier,
		"total_levels": -1 if mode == "endless" else 10,
		"cleared_count": index,
		"lives_left": 16,
		"deaths": 1,
		"skipped_soft": 0,
		"skipped_hard": 0,
	}, slot)


func _write(lines: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()


func _cleanup() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	for file_name: String in ["adventure_stage_ui_probe.ini", "adventure_stage_ui_probe.ini.tmp"]:
		if FileAccess.file_exists("user://" + file_name):
			dir.remove(file_name)
