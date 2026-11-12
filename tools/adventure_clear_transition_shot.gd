extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 抓三张转场图：划入中（看锯齿）、跳跃前停留、跳跃后停留。

const OUTPUT_SLIDE: String = "res://tools/adventure_clear_transition_slide_in.png"
const OUTPUT_BEFORE: String = "res://tools/adventure_clear_transition_align_before.png"
const OUTPUT_AFTER: String = "res://tools/adventure_clear_transition_align_after.png"


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var packed: PackedScene = load("res://tools/adventure_clear_transition_preview.tscn") as PackedScene
	if packed == null:
		get_tree().quit()
		return
	var preview: Node = packed.instantiate()
	add_child(preview)
	await get_tree().create_timer(0.52).timeout
	_save(OUTPUT_SLIDE)
	await get_tree().create_timer(0.28).timeout
	_save(OUTPUT_BEFORE)
	await get_tree().create_timer(0.65).timeout
	_save(OUTPUT_AFTER)
	get_tree().quit()


func _save(path: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(path)
