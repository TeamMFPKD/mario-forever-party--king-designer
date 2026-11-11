extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 把五套标题画面按钮方案各截一张图，供对比查看。
## 运行（窗口，不能加 --headless）：
##   Godot --path . res://tools/title_design_shot.tscn

const OUTPUTS: Array[String] = [
	"res://tools/title_design_a_arcade.png",
	"res://tools/title_design_b_rail.png",
	"res://tools/title_design_c_hero.png",
	"res://tools/title_design_d_ring.png",
	"res://tools/title_design_e_grid.png",
	"res://tools/title_design_f_pipe.png",
]


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await get_tree().process_frame
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var packed: PackedScene = load("res://tools/title_design_preview.tscn") as PackedScene
	if packed == null:
		get_tree().quit()
		return
	var preview: Node = packed.instantiate()
	add_child(preview)
	for frame: int in range(4):
		await get_tree().process_frame
	preview.call("set_badge_visible", false)
	for index: int in range(OUTPUTS.size()):
		preview.call("show_scheme", index)
		for frame: int in range(8):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await get_tree().create_timer(0.2).timeout
		var image: Image = get_viewport().get_texture().get_image()
		if image != null:
			image.save_png(OUTPUTS[index])
	# 水管方案额外补一张「五口全开」的道具展示图
	preview.call("show_scheme", OUTPUTS.size() - 1)
	for frame: int in range(6):
		await get_tree().process_frame
	preview.call("debug_show_items")
	for frame: int in range(6):
		await get_tree().process_frame
	var hover_image: Image = get_viewport().get_texture().get_image()
	if hover_image != null:
		hover_image.save_png("res://tools/title_design_f_pipe_items.png")
	get_tree().quit()
