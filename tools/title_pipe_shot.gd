extends Node

@warning_ignore_start("unsafe_cast")

## 截改造后的标题画面（水管入口版），并额外截一张小窗口尺寸验证多分辨率适配。
## 运行（窗口，不能加 --headless）：
##   Godot --path . res://tools/title_pipe_shot.tscn

const OUTPUT: String = "res://tools/title_pipe.png"
const OUTPUT_SMALL: String = "res://tools/title_pipe_small.png"


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await get_tree().process_frame
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var packed: PackedScene = load("res://room/title.tscn") as PackedScene
	if packed == null:
		get_tree().quit()
		return
	var instance: Node = packed.instantiate()
	get_tree().root.add_child(instance)
	for frame: int in range(12):
		await get_tree().process_frame
	await get_tree().create_timer(2.5).timeout
	await _save(OUTPUT)

	DisplayServer.window_set_size(Vector2i(1120, 640))
	await get_tree().create_timer(1.2).timeout
	await _save(OUTPUT_SMALL)
	get_tree().quit()


func _save(path: String) -> void:
	# 鼠标停在画面上会触发 hover，把道具顶出来，截图前先挪到角落
	Input.warp_mouse(Vector2(4, 4))
	await get_tree().process_frame
	await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(path)
