extends Node

## 结算页截图脚本：分别截 GAME OVER 与 GAME CLEAR 两版。
## 必须窗口化运行（不要 --headless），否则取不到画面。

const RESULT_SCENE: String = "res://room/adventure_result.tscn"
const OVER_OUTPUT: String = "res://tools/adventure_result_over.png"
const CLEAR_OUTPUT: String = "res://tools/adventure_result_clear.png"

## 等标题逐字掉完 + 数据卡片上划淡入播完
const SETTLE_SEC: float = 2.8


func _ready() -> void:
	await _shoot_over()
	await _shoot_clear()
	get_tree().quit()


func _shoot_over() -> void:
	Adventure.last_summary = {
		"result": "failed",
		"mode": "finite",
		"cleared_count": 6,
		"total_levels": 10,
		"lives_left": 0,
		"lives_total": 20,
		"tier": 3,
		"skipped_soft": 1,
		"skipped_hard": 0,
	}
	await _shoot(OVER_OUTPUT)


func _shoot_clear() -> void:
	Adventure.last_summary = {
		"result": "completed",
		"mode": "finite",
		"cleared_count": 10,
		"total_levels": 10,
		"lives_left": 7,
		"lives_total": 20,
		"tier": 2,
		"skipped_soft": 0,
		"skipped_hard": 1,
	}
	await _shoot(CLEAR_OUTPUT)


func _shoot(output_path: String) -> void:
	var packed: PackedScene = load(RESULT_SCENE) as PackedScene
	if packed == null:
		return
	var screen: Node = packed.instantiate()
	# 真实流程里结算页是冻结着关卡切进来的，这里复现同样的进法。
	get_tree().paused = true
	add_child(screen)
	await get_tree().create_timer(SETTLE_SEC).timeout
	var image: Image = get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(output_path)
	remove_child(screen)
	screen.queue_free()
	await get_tree().process_frame
