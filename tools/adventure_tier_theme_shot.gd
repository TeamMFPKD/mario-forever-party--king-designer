extends Node

## 四档难度主题色截图：在同一个舞台上依次切档，各截一张。
## 必须窗口化运行（不要 --headless），否则取不到画面。

const STAGE_SCENE: String = "res://room/adventure_stage.tscn"
const OUTPUT_PATH: String = "res://tools/adventure_tier_%d.png"
const POOL_LOAD_SEC: float = 5.0
const SWITCH_SEC: float = 0.4


func _ready() -> void:
	var packed: PackedScene = load(STAGE_SCENE) as PackedScene
	if packed == null:
		get_tree().quit()
		return
	var stage: Node = packed.instantiate()
	add_child(stage)
	# 等关卡池扫完，让难度按钮显示真实关数。
	await get_tree().create_timer(POOL_LOAD_SEC).timeout
	for tier: int in range(1, 5):
		stage.call("_select_tier", tier)
		await get_tree().create_timer(SWITCH_SEC).timeout
		var image: Image = get_viewport().get_texture().get_image()
		if image != null:
			image.save_png(OUTPUT_PATH % tier)
	get_tree().quit()
