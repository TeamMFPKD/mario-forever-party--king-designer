extends Node

## 无尽团卡面配色变种：以 C（粉彩彩虹）/ D（低饱和彩虹）为基准，
## 对每个色值做 HSV 上的亮度、饱和度微调，逐套套到真实舞台的无尽团存档卡上截图。
## 窗口化运行（不要 --headless），否则取不到画面。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const TEMP_STORE: String = "user://endless_variant_stage.ini"

## C 组基准色（粉彩彩虹）
const BASE_C: Array[Color] = [
	Color("#FF9AA2"), Color("#FFDAC1"), Color("#B5EAD7"), Color("#A2D2FF"),
]
## D 组基准色（低饱和彩虹）
const BASE_D: Array[Color] = [
	Color("#E89AA0"), Color("#E8D69A"), Color("#9ADFA8"), Color("#9AC2E8"),
]

## 变种表：[输出后缀, 基准组, 饱和度倍率, 明度倍率]
## 命名里 s 是饱和度、v 是明度，数字为倍率乘 100。
const VARIANTS: Array = [
	["c1_base", "c", 1.00, 1.00],
	["c2_sat125", "c", 1.25, 1.00],
	["c3_sat155_val95", "c", 1.55, 0.95],
	["c4_sat120_val88", "c", 1.20, 0.88],
	["c5_sat110_val106", "c", 1.10, 1.06],
	["d1_base", "d", 1.00, 1.00],
	["d2_sat135", "d", 1.35, 1.00],
	["d3_sat175_val96", "d", 1.75, 0.96],
	["d4_sat130_val86", "d", 1.30, 0.86],
	["d5_sat085_val108", "d", 0.85, 1.08],
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
	var material: ShaderMaterial = paint.material as ShaderMaterial
	if material == null:
		_cleanup()
		get_tree().quit()
		return

	for item: Array in VARIANTS:
		var tag: String = str(item[0])
		var base: Array[Color] = BASE_C if str(item[1]) == "c" else BASE_D
		var sat: float = float(item[2])
		var val: float = float(item[3])
		var colors: Array[Color] = _tune(base, sat, val)
		material.set_shader_parameter("color_a", colors[0])
		material.set_shader_parameter("color_b", colors[1])
		material.set_shader_parameter("color_c", colors[2])
		material.set_shader_parameter("color_d", colors[3])
		await get_tree().create_timer(0.4).timeout
		var image: Image = get_viewport().get_texture().get_image()
		if image != null:
			image.save_png("res://tools/endless_variant_%s.png" % tag)

	_cleanup()
	get_tree().quit()


## 对四个色值统一乘饱和度与明度倍率，结果钳在合法范围内。
func _tune(base: Array[Color], sat_mul: float, val_mul: float) -> Array[Color]:
	var result: Array[Color] = []
	for color: Color in base:
		result.append(Color.from_hsv(
			color.h,
			clampf(color.s * sat_mul, 0.0, 1.0),
			clampf(color.v * val_mul, 0.0, 1.0)
		))
	return result


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
	for file_name: String in ["endless_variant_stage.ini", "endless_variant_stage.ini.tmp"]:
		if FileAccess.file_exists("user://" + file_name):
			dir.remove(file_name)
