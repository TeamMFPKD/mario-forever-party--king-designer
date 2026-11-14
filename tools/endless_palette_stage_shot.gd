extends Node

## 配色对比（在真实舞台上）：同一张无尽团存档卡，依次换四套配色各截一张。
## 窗口化运行（不要 --headless），否则取不到画面。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const TEMP_STORE: String = "user://endless_palette_stage.ini"

## 四套候选：名称 + 四个色值。顺序与输出文件后缀一致。
const PALETTES: Array = [
	["a", Color("#4A9EFF"), Color("#7B6CFF"), Color("#C86BFF"), Color("#FF7B8A")],
	["b", Color("#FF6FB5"), Color("#A97BFF"), Color("#5BC8FF"), Color("#6FE7B8")],
	["c", Color("#FF9AA2"), Color("#FFDAC1"), Color("#B5EAD7"), Color("#A2D2FF")],
	["d", Color("#E89AA0"), Color("#E8D69A"), Color("#9ADFA8"), Color("#9AC2E8")],
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
	var paint: ColorRect = button.get_node_or_null("Paint") as ColorRect
	if paint == null:
		_cleanup()
		get_tree().quit()
		return

	for item: Array in PALETTES:
		var tag: String = str(item[0])
		var material: ShaderMaterial = paint.material as ShaderMaterial
		material.set_shader_parameter("color_a", item[1])
		material.set_shader_parameter("color_b", item[2])
		material.set_shader_parameter("color_c", item[3])
		material.set_shader_parameter("color_d", item[4])
		await get_tree().create_timer(0.4).timeout
		var image: Image = get_viewport().get_texture().get_image()
		if image != null:
			image.save_png("res://tools/endless_palette_%s.png" % tag)
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
	for file_name: String in ["endless_palette_stage.ini", "endless_palette_stage.ini.tmp"]:
		if FileAccess.file_exists("user://" + file_name):
			dir.remove(file_name)
