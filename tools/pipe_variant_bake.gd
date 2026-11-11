extends Node

## 一次性把水管的五种配色烘成独立 PNG，供 ui/title/pipe_menu.tscn 在编辑器里直接引用。
## 运行：Godot --headless --path . res://tools/pipe_variant_bake.tscn

const SOURCE: String = "res://sprite/ui/pipe/warp_pipe.svg"
const MAIN: Color = Color("00aa63")
const NAMES: Array[String] = ["green", "yellow", "blue", "red", "white"]
const COLORS: Array[String] = [
	"#00aa63",
	"#f2b81c",
	"#2f7fe0",
	"#d6342a",
	"#f2f2f2",
]


func _ready() -> void:
	var texture: Texture2D = load(SOURCE) as Texture2D
	if texture == null:
		get_tree().quit()
		return
	var image: Image = texture.get_image()
	for index: int in range(NAMES.size()):
		var variant: Texture2D = PipeTint.variant(image, Color(COLORS[index]), MAIN)
		var output: Image = variant.get_image()
		output.save_png("res://sprite/ui/pipe/variant_%s.png" % NAMES[index])
		print("[bake] variant_%s.png %s" % [NAMES[index], output.get_size()])
	get_tree().quit()
