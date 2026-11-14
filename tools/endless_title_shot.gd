extends Node

## D5 配色下，无尽团卡面已经是很亮的奶白彩底，白字靠深色描边才读得清，
## 看起来像贴纸。这个工具把「白字+深描边」与「深字+无描边」各截一张做对比。
## 窗口化运行（不要 --headless）。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const TEMP_STORE: String = "user://endless_title_compare.ini"

## [后缀, 字色, 描边色, 描边粗细]
const VARIANTS: Array = [
	["white_outline", Color(1, 1, 1, 1), Color(0.08, 0.07, 0.1, 0.9), 6],
	["dark", Color(0.102, 0.102, 0.122, 1), Color(0, 0, 0, 0), 0],
	["white_soft", Color(1, 1, 1, 1), Color(0.16, 0.17, 0.22, 0.55), 4],
	["dark_soft", Color(0.145, 0.157, 0.2, 1), Color(1, 1, 1, 0.8), 3],
]


func _ready() -> void:
	var store: AdventureStore = AdventureStore.new(TEMP_STORE)
	store.load()
	_seed_endless(store, 3, 3, 2)
	Adventure.store = store

	var packed: PackedScene = load("res://room/adventure_stage.tscn") as PackedScene
	if packed == null:
		get_tree().quit()
		return
	var stage: Node = packed.instantiate()
	add_child(stage)
	await get_tree().create_timer(7.0).timeout

	var slots: Node = stage.get_node_or_null("Layout/Box/SaveSlots")
	if slots == null:
		_cleanup()
		get_tree().quit()
		return
	var button: Button = slots.call("button_at", 2) as Button
	var title: Label = button.get_node_or_null("Content/Title") as Label
	if title == null:
		_cleanup()
		get_tree().quit()
		return

	# 关掉选中态，只看未选中时的可读性
	if slots.has_method("select"):
		slots.call("select", 0)

	for item: Array in VARIANTS:
		var tag: String = str(item[0])
		var color: Color = item[1]
		var outline: Color = item[2]
		var size: int = int(item[3])
		title.add_theme_color_override("font_color", color)
		title.add_theme_color_override("font_outline_color", outline)
		title.add_theme_constant_override("outline_size", size)
		await get_tree().create_timer(0.4).timeout
		var image: Image = get_viewport().get_texture().get_image()
		if image != null:
			image.save_png("res://tools/endless_title_%s.png" % tag)

	_cleanup()
	get_tree().quit()


func _seed_endless(store: AdventureStore, slot: int, index: int, tier: int) -> void:
	store.set_run({
		"active": true,
		"level_keys": ["demo_a", "demo_b", "demo_c", "demo_d", "demo_e"],
		"index": index,
		"mode": "endless",
		"tier": tier,
		"total_levels": -1,
		"cleared_count": index,
		"lives_left": 23,
		"deaths": 1,
		"skipped_soft": 0,
		"skipped_hard": 0,
	}, slot)


func _cleanup() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	for file_name: String in ["endless_title_compare.ini", "endless_title_compare.ini.tmp"]:
		if FileAccess.file_exists("user://" + file_name):
			dir.remove(file_name)
