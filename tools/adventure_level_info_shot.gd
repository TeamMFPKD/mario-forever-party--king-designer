extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 左侧关卡信息面板的独立预览：造一份假的团数据，把面板放到真实的左侧位置截图。

const OUTPUT: String = "res://tools/adventure_level_info.png"
const TEMP_STORE: String = "user://adventure_info_shot.ini"
const FAKE_KEY: String = "mfmp_2026-11-12_12-00-00_tester_ab12c"


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_fake_run()

	var background: ColorRect = ColorRect.new()
	background.color = Color(0.207843, 0.156863, 0.341176, 1)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var panel_packed: PackedScene = load("res://object/ui/adventure_level_info.tscn") as PackedScene
	if panel_packed != null:
		var panel: Control = panel_packed.instantiate() as Control
		add_child(panel)

	await get_tree().create_timer(0.4).timeout
	var image: Image = get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(OUTPUT)
	_cleanup()
	get_tree().quit()


func _fake_run() -> void:
	var store: AdventureStore = AdventureStore.new(TEMP_STORE)
	store.load()
	Adventure.store = store
	store.record_pass(FAKE_KEY)
	store.record_pass(FAKE_KEY)
	store.record_pass(FAKE_KEY)
	store.record_skip(FAKE_KEY, true)
	store.record_death(FAKE_KEY)

	var keys: Array = []
	var index: int = 0
	while index < 50:
		keys.append(FAKE_KEY if index == 13 else "placeholder_%d" % index)
		index += 1
	Adventure.current_run = {
		"active": true,
		"mode": "finite",
		"index": 13,
		"total_levels": 50,
		"lives_left": 18,
		"cleared_count": 13,
		"tier": 2,
		"active_tier": 2,
		"level_keys": keys,
	}


func _cleanup() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	for file_name: String in ["adventure_info_shot.ini", "adventure_info_shot.ini.tmp"]:
		if FileAccess.file_exists("user://" + file_name):
			dir.remove(file_name)
