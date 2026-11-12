extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 把四套百人团 UI 方案各截一张图，供对比查看。

const OUTPUTS: Array[String] = [
	"res://tools/design_a_paper.png",
	"res://tools/design_b_stage.png",
	"res://tools/design_c_neon.png",
	"res://tools/design_d_poster.png",
]


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var packed: PackedScene = load("res://tools/adventure_design_preview.tscn") as PackedScene
	if packed == null:
		get_tree().quit()
		return
	var preview: Node = packed.instantiate()
	add_child(preview)
	await get_tree().process_frame
	await get_tree().process_frame
	for index: int in range(OUTPUTS.size()):
		preview.call("show_scheme", index)
		for frame: int in range(8):
			await get_tree().process_frame
		await get_tree().create_timer(0.2).timeout
		var image: Image = get_viewport().get_texture().get_image()
		if image != null:
			image.save_png(OUTPUTS[index])
	get_tree().quit()
